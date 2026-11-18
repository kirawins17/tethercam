"""tethercam: use your phone (iPhone or Android, plugged in by USB) as a webcam.

Works on Windows and Linux.

  iPhone:  Tethercam app -> Apple usbmux (USB) -> JPEG frames  ┐
                                                               ├-> virtual webcam
  Android: scrcpy server -> adb forward (USB)  -> H.264 stream ┘

The virtual webcam is "OBS Virtual Camera" on Windows and a v4l2loopback
device on Linux. Discord, Zoom, Teams, OBS and browsers see it as a normal camera.
"""

import argparse
import socket
import sys
import time

import cv2
import numpy as np

import android_source as android
import iphone_source as iphone

__version__ = "1.4.1"

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
    canvas[y: y + nh, x: x + nw] = resized
    return canvas


def waiting_frame(width, height, message):
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    cv2.putText(frame, "tethercam", (40, height // 2 - 30),
                cv2.FONT_HERSHEY_SIMPLEX, 1.6, (255, 255, 255), 3, cv2.LINE_AA)
    cv2.putText(frame, message[:70], (40, height // 2 + 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (180, 180, 180), 2, cv2.LINE_AA)
    return frame


def pick_phone(choice):
    """Decide which phone to use. 'auto' picks whichever is plugged in."""
    if choice != "auto":
        return choice
    if iphone.list_iphones():
        return "iphone"
    if any(state in ("device", "unauthorized") for _, state in android.list_androids()):
        return "android"
    raise ConnectionError("No phone found. Plug in your phone. "
                          "iPhone: unlock it and tap Trust. Android: turn on USB debugging.")


def open_frames(args):
    phone = pick_phone(args.phone)
    if phone == "iphone":
        return phone, iphone.frames(args.device)
    return phone, android.frames(args.device, facing=args.camera,
                                 max_size=max(args.width, args.height), max_fps=args.fps)


def camera_help():
    if sys.platform == "win32":
        return ("Install OBS Studio (it provides the 'OBS Virtual Camera' driver). "
                "If OBS is open, close it.")
    return ("Load the virtual camera module, then run tethercam again:\n"
            "  sudo modprobe v4l2loopback exclusive_caps=1 card_label=tethercam")


def main():
    p = argparse.ArgumentParser(prog="tethercam",
                                description="Use your phone over USB as a webcam.")
    p.add_argument("--phone", choices=["auto", "iphone", "android"], default="auto",
                   help="Which phone to use (default: whichever is plugged in)")
    p.add_argument("--camera", choices=["back", "front"], default="back",
                   help="Android only. On iPhone, switch cameras in the app.")
    p.add_argument("--width", type=int, default=1280)
    p.add_argument("--height", type=int, default=720)
    p.add_argument("--fps", type=int, default=30)
    p.add_argument("--rotate", type=int, choices=sorted(ROTATIONS), default=0,
                   help="Rotate the picture clockwise by this many degrees")
    p.add_argument("--mirror", action="store_true", help="Flip the picture left to right")
    p.add_argument("--device", help="Pick one phone (iPhone UDID or Android serial)")
    p.add_argument("--preview", action="store_true", help="Also show a preview window")
    p.add_argument("--version", action="version", version=f"tethercam {__version__}")
    args = p.parse_args()

    import pyvirtualcam  # imported here so the rest can be tested without it

    try:
        cam = pyvirtualcam.Camera(args.width, args.height, args.fps,
                                  fmt=pyvirtualcam.PixelFormat.BGR)
    except Exception as e:  # pyvirtualcam raises RuntimeError on both platforms
        sys.exit(f"Could not start the virtual webcam: {e}\n{camera_help()}")

    name = cam.device if sys.platform == "win32" else "tethercam"
    print(f"tethercam {__version__}. Virtual webcam ready: '{cam.device}' at {args.width}x{args.height}.")
    print(f"In Discord: Settings > Voice & Video > Camera > {name}. Ctrl+C to stop.")

    try:
        with cam:
            run_loop(cam, args)
    except KeyboardInterrupt:
        print("\nStopped.")


def run_loop(cam, args):
    """Stream frames forever. Reconnect when the phone drops. Ctrl+C stops it."""
    while True:
        stream = None
        try:
            phone, stream = open_frames(args)
            label = "iPhone" if phone == "iphone" else "Android phone"
            print(f"Connected to {label}. Streaming...")
            frames, t0 = 0, time.time()
            for frame in stream:
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
            raise ConnectionError("The video stopped")
        except Exception as e:  # keep the webcam alive and retry (Ctrl+C is not an Exception)
            msg = str(e) or e.__class__.__name__
            if isinstance(e, socket.timeout):
                msg = "No video. Keep the phone unlocked (iPhone: keep the Tethercam app open)."
            print(f"Waiting for phone: {msg}")
            cam.send(waiting_frame(args.width, args.height, msg.splitlines()[0]))
            time.sleep(1.5)
        finally:
            if stream is not None:
                stream.close()

if __name__ == "__main__":
    main()
