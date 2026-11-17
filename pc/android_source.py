"""Android source: uses scrcpy's server to stream the phone camera over USB.

scrcpy (https://github.com/Genymobile/scrcpy, Apache-2.0) already does the
hard part on the phone. We push its small server to the phone with adb, ask it
for the camera as a raw H.264 stream, and decode that with PyAV.
Nothing is installed on the phone; the server is removed when it stops.

Needs: Android 12 or newer, USB debugging on, and adb on the PC.
"""

import hashlib
import os
import random
import shutil
import socket
import subprocess
import sys
import time
import urllib.request

SCRCPY_VERSION = "3.3.2"
SERVER_URL = (f"https://github.com/Genymobile/scrcpy/releases/download/"
              f"v{SCRCPY_VERSION}/scrcpy-server-v{SCRCPY_VERSION}")
SERVER_SHA256 = "2ee5ca0863ef440f5b7c75856bb475c5283d0a8359cb370b1c161314fd29dfd9"
DEVICE_PATH = "/data/local/tmp/tethercam-scrcpy-server.jar"
LOCAL_PORT = 27183


def data_dir():
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))
    else:
        base = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    path = os.path.join(base, "tethercam")
    os.makedirs(path, exist_ok=True)
    return path


def find_adb():
    found = shutil.which("adb")
    if found:
        return found
    if sys.platform == "win32":
        local = os.environ.get("LOCALAPPDATA", "")
        for candidate in (
            os.path.join(local, "Microsoft", "WinGet", "Links", "adb.exe"),
            os.path.join(local, "Android", "Sdk", "platform-tools", "adb.exe"),
        ):
            if os.path.isfile(candidate):
                return candidate
    return None


def _run(adb, *args, serial=None, timeout=20):
    cmd = [adb] + (["-s", serial] if serial else []) + list(args)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def list_androids(adb=None):
    """Return [(serial, state)] for every phone adb can see ([] if adb is missing)."""
    adb = adb or find_adb()
    if not adb:
        return []
    try:
        out = _run(adb, "devices").stdout
    except (OSError, subprocess.SubprocessError):
        return []
    devices = []
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            devices.append((parts[0], parts[1]))
    return devices


def server_file():
    """Path to the scrcpy server, downloaded once and checked against its SHA-256."""
    path = os.path.join(data_dir(), f"scrcpy-server-v{SCRCPY_VERSION}")

    def ok():
        if not os.path.isfile(path):
            return False
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest() == SERVER_SHA256

    if not ok():
        print(f"Downloading the scrcpy server v{SCRCPY_VERSION} (one time)...")
        with urllib.request.urlopen(SERVER_URL, timeout=30) as r:
            data = r.read()
        if hashlib.sha256(data).hexdigest() != SERVER_SHA256:
            raise ConnectionError("The scrcpy server download failed its safety check. Try again later.")
        with open(path, "wb") as f:
            f.write(data)
    return path


def _pick_device(adb, serial):
    devices = list_androids(adb)
    if serial:
        devices = [d for d in devices if d[0] == serial]
    ready = [s for s, state in devices if state == "device"]
    if ready:
        return ready[0]
    if any(state == "unauthorized" for _, state in devices):
        raise ConnectionError("Android phone found. Unlock it and tap 'Allow' on the USB debugging prompt.")
    raise ConnectionError("No Android phone found. Plug it in and turn on USB debugging.")


def decode_stream(first, read):
    """Decode a raw H.264 byte stream into BGR frames. `read(n)` returns b"" at the end."""
    import av  # PyAV, imported here so iPhone users don't need it loaded

    codec = av.CodecContext.create("h264", "r")
    data = first
    while True:
        for packet in codec.parse(data):
            for frame in codec.decode(packet):
                yield frame.to_ndarray(format="bgr24")
        data = read(65536)
        if not data:
            raise ConnectionError("The phone closed the connection")


def frames(serial=None, facing="back", max_size=1280, max_fps=30):
    """Yield BGR frames from the Android camera until the connection drops."""
    adb = find_adb()
    if not adb:
        raise ConnectionError("adb is not installed. Run the Tethercam installer again, "
                              "or install Android platform-tools.")
    serial = _pick_device(adb, serial)

    push = _run(adb, "push", server_file(), DEVICE_PATH, serial=serial, timeout=60)
    if push.returncode != 0:
        raise ConnectionError(f"Could not copy the scrcpy server to the phone: {push.stderr.strip()}")

    scid = random.randint(0, 0x7FFFFFFF)
    _run(adb, "forward", f"tcp:{LOCAL_PORT}", f"localabstract:scrcpy_{scid:08x}", serial=serial)

    server = subprocess.Popen(
        [adb, "-s", serial, "shell", f"CLASSPATH={DEVICE_PATH}", "app_process", "/",
         "com.genymobile.scrcpy.Server", SCRCPY_VERSION,
         f"scid={scid:08x}", "log_level=warn",
         "video_source=camera", f"camera_facing={facing}",
         f"max_size={max_size}", f"max_fps={max_fps}",
         "audio=false", "control=false", "tunnel_forward=true", "raw_stream=true",
         "cleanup=true"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )

    sock, first = None, b""
    try:
        # The adb tunnel accepts a connection before the server is ready and
        # then drops it, so retry until the first video bytes arrive.
        deadline = time.time() + 10
        while time.time() < deadline:
            if server.poll() is not None:
                log = (server.stdout.read() or "").strip().splitlines()
                hint = log[-1] if log else "the server stopped"
                if "Android 12" in "\n".join(log):
                    hint = "The camera needs Android 12 or newer."
                raise ConnectionError(f"Android camera could not start: {hint}")
            try:
                sock = socket.create_connection(("127.0.0.1", LOCAL_PORT), timeout=5)
                first = sock.recv(65536)
                if first:
                    break
            except OSError:
                pass
            if sock:
                sock.close()
                sock = None
            time.sleep(0.3)
        if not first:
            raise ConnectionError("Android camera did not start. Unlock the phone and try again.")

        yield from decode_stream(first, sock.recv)
    finally:
        if sock:
            sock.close()
        if server.poll() is None:
            server.terminate()
        _run(adb, "forward", "--remove", f"tcp:{LOCAL_PORT}", serial=serial)
