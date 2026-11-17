"""iPhone source: talks to the Tethercam iOS app over the USB cable.

The cable link uses Apple's usbmux service (installed with iTunes on Windows,
`usbmuxd` on Linux) - the iPhone equivalent of `adb forward`.
Wire format from the app: repeat [4-byte big-endian length][JPEG bytes].
"""

import plistlib
import socket
import struct
import sys

import cv2
import numpy as np

PHONE_PORT = 8765
MAX_FRAME_BYTES = 20 * 1024 * 1024


def recv_exact(sock, n):
    buf = bytearray(n)
    view = memoryview(buf)
    got = 0
    while got < n:
        k = sock.recv_into(view[got:], n - got)
        if k == 0:
            raise ConnectionError("The phone closed the connection")
        got += k
    return bytes(buf)


def _usbmux_socket():
    """Connect to Apple's usbmux service."""
    if sys.platform == "win32":
        return socket.create_connection(("127.0.0.1", 27015), timeout=5)
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect("/var/run/usbmuxd")
    return s


def _usbmux_request(sock, payload, tag=1):
    """Send one plist request and return the plist reply (usbmux protocol v1)."""
    payload = dict(payload, ClientVersionString="tethercam", ProgName="tethercam")
    body = plistlib.dumps(payload)
    sock.sendall(struct.pack("<IIII", 16 + len(body), 1, 8, tag) + body)
    length, _version, _msg, _tag = struct.unpack("<IIII", recv_exact(sock, 16))
    return plistlib.loads(recv_exact(sock, length - 16))


def usb_service_missing_message():
    if sys.platform == "win32":
        return ("Can't reach Apple's USB service. Install iTunes from apple.com "
                "(not the Microsoft Store), then restart the PC.")
    return "Can't reach usbmuxd. Install it (for example: sudo apt install usbmuxd) and plug the iPhone in again."


def list_iphones():
    """Return the usbmux properties of every iPhone connected by USB ([] if none or no service)."""
    try:
        sock = _usbmux_socket()
    except OSError:
        return []
    with sock:
        reply = _usbmux_request(sock, {"MessageType": "ListDevices"})
    return [
        d.get("Properties", {}) for d in reply.get("DeviceList", [])
        if d.get("Properties", {}).get("ConnectionType", "USB") == "USB"
    ]


def connect_usb(udid, port=PHONE_PORT):
    """Open a TCP connection to `port` on the iPhone, tunnelled over the USB cable."""
    try:
        _usbmux_socket().close()
    except OSError:
        raise ConnectionError(usb_service_missing_message())
    devices = list_iphones()
    if udid:
        devices = [d for d in devices if d.get("SerialNumber") == udid]
    if not devices:
        raise ConnectionError(
            "No iPhone found over USB. Plug it in, unlock it, and tap 'Trust' on the phone."
        )

    sock = _usbmux_socket()
    reply = _usbmux_request(sock, {
        "MessageType": "Connect",
        "DeviceID": devices[0]["DeviceID"],
        "PortNumber": socket.htons(port),
    })
    if reply.get("Number", 1) != 0:
        sock.close()
        raise ConnectionError("iPhone found, but the Tethercam app isn't open on the phone.")
    return sock  # from here on, the socket is a raw pipe to the app


def read_frame(sock):
    (length,) = struct.unpack(">I", recv_exact(sock, 4))
    if length == 0 or length > MAX_FRAME_BYTES:
        raise ConnectionError(f"Bad frame size {length}; is the Tethercam app running?")
    data = np.frombuffer(recv_exact(sock, length), dtype=np.uint8)
    frame = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if frame is None:
        raise ConnectionError("Could not decode a frame from the iPhone")
    return frame


def frames(udid=None):
    """Yield BGR frames from the iPhone until the connection drops."""
    sock = connect_usb(udid)
    sock.settimeout(5)
    try:
        while True:
            yield read_frame(sock)
    finally:
        sock.close()
