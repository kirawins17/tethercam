"""tethercam: use your iPhone (plugged in over USB) as a webcam on Windows.

Flow, modelled on scrcpy's design:
  scrcpy:    adb forward  -> phone-side server -> video socket -> V4L2 sink
  tethercam: Apple usbmux -> Tethercam app     -> JPEG socket  -> virtual webcam

The virtual webcam is provided by OBS Studio's "OBS Virtual Camera" driver,
which Discord, Zoom, Teams, browsers etc. all see as a normal camera.
"""

import argparse
import plistlib
import socket
import struct
import sys
import time

import cv2
import numpy as np

PHONE_PORT = 8765
MAX_FRAME_BYTES = 20 * 1024 * 1024


def _usbmux_socket():
    """Connect to Apple's usbmux service (installed with iTunes / Apple Devices)."""
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


def connect_usb(udid, port):
    """Open a TCP connection to `port` on the iPhone, tunnelled over the USB cable."""
    try:
        listing = _usbmux_socket()
    except OSError:
        raise ConnectionError(
            "Can't reach Apple's USB service. Install iTunes from apple.com (not the "
            "Microsoft Store), then restart the PC."
        )
    with listing:
        reply = _usbmux_request(listing, {"MessageType": "ListDevices"})
    devices = [
        d.get("Properties", {}) for d in reply.get("DeviceList", [])
        if d.get("Properties", {}).get("ConnectionType", "USB") == "USB"
    ]
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


def recv_exact(sock, n):
    buf = bytearray(n)
    view = memoryview(buf)
    got = 0
    while got < n:
        k = sock.recv_into(view[got:], n - got)
        if k == 0:
            raise ConnectionError("The iPhone closed the connection")
        got += k
    return bytes(buf)


def read_frame(sock):
    (length,) = struct.unpack(">I", recv_exact(sock, 4))
    if length == 0 or length > MAX_FRAME_BYTES:
        raise ConnectionError(f"Bad frame size {length}; is the Tethercam app running?")
    data = np.frombuffer(recv_exact(sock, length), dtype=np.uint8)
    frame = cv2.imdecode(data, cv2.IMREAD_COLOR)
    if frame is None:
        raise ConnectionError("Could not decode a frame from the iPhone")
    return frame


ROTATIONS = {
    0: None,
    90: cv2.ROTATE_90_CLOCKWISE,
    180: cv2.ROTATE_180,
    270: cv2.ROTATE_90_COUNTERCLOCKWISE,
}


def fit(frame, width, height):
    """Scale to fit width x height without stretching, padding with black."""
    h, w = frame.shape[:2]
    if (w, h) == (width, height):
        return frame
    scale = min(width / w, height / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_AREA)
    canvas = np.zeros((height, width, 3), dtype=np.uint8)
    x, y = (width - nw) // 2, (height - nh) // 2
    canvas[y : y + nh, x : x + nw] = resized
    return canvas


def waiting_frame(width, height, message):
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    cv2.putText(frame, "tethercam", (40, height // 2 - 30),
                cv2.FONT_HERSHEY_SIMPLEX, 1.6, (255, 255, 255), 3, cv2.LINE_AA)
    cv2.putText(frame, message[:70], (40, height // 2 + 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (180, 180, 180), 2, cv2.LINE_AA)
    return frame


def main():
    p = argparse.ArgumentParser(prog="tethercam",
                                description="Use an iPhone over USB as a Windows webcam.")
    p.add_argument("--width", type=int, default=1280)
    p.add_argument("--height", type=int, default=720)
    p.add_argument("--fps", type=int, default=30)
    p.add_argument("--rotate", type=int, choices=sorted(ROTATIONS), default=0,
                   help="Rotate the image clockwise by this many degrees")
    p.add_argument("--mirror", action="store_true", help="Flip the image left-to-right")
    p.add_argument("--udid", help="Pick a specific iPhone if more than one is plugged in")
    p.add_argument("--preview", action="store_true", help="Also show a preview window")
    args = p.parse_args()

    import pyvirtualcam  # imported here so the protocol code can be tested without it

    try:
        cam = pyvirtualcam.Camera(args.width, args.height, args.fps,
                                  fmt=pyvirtualcam.PixelFormat.BGR)
    except RuntimeError as e:
        sys.exit(f"Could not start the virtual webcam: {e}\n"
                 "Install OBS Studio (it provides the 'OBS Virtual Camera' driver), "
                 "then run this again.")

    print(f"Virtual webcam ready: '{cam.device}' at {args.width}x{args.height}.")
    print("In Discord: Settings > Voice & Video > Camera > pick that camera. Ctrl+C to stop.")

    with cam:
        while True:
            try:
                sock = connect_usb(args.udid, PHONE_PORT)
                sock.settimeout(5)
                print("Connected to iPhone. Streaming...")
                frames, t0 = 0, time.time()
                while True:
                    frame = read_frame(sock)
                    if ROTATIONS[args.rotate] is not None:
                        frame = cv2.rotate(frame, ROTATIONS[args.rotate])
                    if args.mirror:
                        frame = cv2.flip(frame, 1)
                    frame = fit(frame, args.width, args.height)
                    cam.send(frame)
                    if args.preview:
                        cv2.imshow("tethercam preview (q to close)", frame)
                        if cv2.waitKey(1) & 0xFF == ord("q"):
                            args.preview = False
                            cv2.destroyAllWindows()
                    frames += 1
                    if time.time() - t0 >= 5:
                        print(f"  {frames / (time.time() - t0):.1f} fps", end="\r")
                        frames, t0 = 0, time.time()
            except KeyboardInterrupt:
                print("\nStopped.")
                return
            except Exception as e:  # keep the webcam alive and retry
                msg = str(e) or e.__class__.__name__
                if isinstance(e, socket.timeout):
                    msg = "No video. Open the Tethercam app and keep it on screen."
                print(f"Waiting for iPhone: {msg}")
                try:
                    sock.close()
                except Exception:
                    pass
                cam.send(waiting_frame(args.width, args.height, msg))
                try:
                    time.sleep(1.5)
                except KeyboardInterrupt:
                    print("\nStopped.")
                    return


if __name__ == "__main__":
    main()
