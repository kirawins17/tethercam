"""Tests for the main loop: reconnect, waiting screen and Ctrl+C."""
import os
import sys
import types
import unittest
from unittest import mock

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "pc"))
import tethercam  # noqa: E402


class FakeCam:
    def __init__(self, stop_after):
        self.sent, self.stop_after, self.device = [], stop_after, "fake"

    def send(self, frame):
        self.sent.append(frame)
        if len(self.sent) >= self.stop_after:
            raise KeyboardInterrupt


def args(**kw):
    base = dict(phone="auto", camera="back", width=320, height=240, fps=30, rotate=0,
                mirror=False, device=None, preview=False)
    base.update(kw)
    return types.SimpleNamespace(**base)


class MainLoopTests(unittest.TestCase):
    def test_ctrl_c_while_waiting_does_not_crash(self):
        cam = FakeCam(stop_after=1)
        with mock.patch.object(tethercam, "open_frames", side_effect=ConnectionError("no phone")):
            with self.assertRaises(KeyboardInterrupt):  # main() catches this and prints "Stopped."
                tethercam.run_loop(cam, args())
        self.assertEqual(len(cam.sent), 1)

    def test_reconnects_after_drop(self):
        frame = np.zeros((480, 640, 3), np.uint8)
        def gen(n):
            yield from [frame] * n
        streams = [gen(2), gen(1)]
        cam = FakeCam(stop_after=5)  # 2 frames, waiting, 1 frame, waiting
        with mock.patch.object(tethercam, "open_frames",
                               side_effect=lambda a: ("iphone", streams.pop(0))), \
             mock.patch.object(tethercam.time, "sleep"):
            with self.assertRaises(KeyboardInterrupt):
                tethercam.run_loop(cam, args())
        self.assertTrue(all(f.shape == (240, 320, 3) for f in cam.sent))

    def test_main_prints_stopped_on_ctrl_c(self):
        fake = types.ModuleType("pyvirtualcam")
        cam = mock.MagicMock()
        cam.__enter__.return_value = cam
        cam.device = "fake"
        fake.Camera = mock.Mock(return_value=cam)
        fake.PixelFormat = types.SimpleNamespace(BGR="BGR")
        with mock.patch.dict(sys.modules, {"pyvirtualcam": fake}), \
             mock.patch.object(sys, "argv", ["tethercam"]), \
             mock.patch.object(tethercam, "run_loop", side_effect=KeyboardInterrupt), \
             mock.patch("builtins.print") as printed:
            tethercam.main()
        self.assertIn("Stopped", " ".join(str(c) for c in printed.call_args_list))


if __name__ == "__main__":
    unittest.main()
