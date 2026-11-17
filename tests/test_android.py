"""Tests for the Android source, using a fake adb and a real H.264 stream made by PyAV."""
import hashlib
import io
import os
import sys
import unittest
from unittest import mock

import av
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "pc"))
import android_source  # noqa: E402


def make_h264(n=10, w=320, h=240):
    """Encode n frames to a raw Annex-B H.264 stream, like scrcpy's raw_stream."""
    codec = av.CodecContext.create("libx264", "w")
    codec.width, codec.height, codec.pix_fmt = w, h, "yuv420p"
    codec.options = {"tune": "zerolatency"}
    out = b""
    for i in range(n):
        img = np.full((h, w, 3), (i * 20) % 255, np.uint8)
        frame = av.VideoFrame.from_ndarray(img, format="bgr24").reformat(format="yuv420p")
        for pkt in codec.encode(frame):
            out += bytes(pkt)
    for pkt in codec.encode(None):
        out += bytes(pkt)
    return out


class DecodeTests(unittest.TestCase):
    def test_decodes_stream_in_small_chunks(self):
        stream = io.BytesIO(make_h264())
        first = stream.read(1000)
        frames = []
        with self.assertRaises(ConnectionError):
            for f in android_source.decode_stream(first, lambda n: stream.read(min(n, 1000))):
                frames.append(f)
        self.assertGreaterEqual(len(frames), 8)
        self.assertEqual(frames[0].shape, (240, 320, 3))


class DeviceTests(unittest.TestCase):
    def pick(self, devices, serial=None):
        with mock.patch.object(android_source, "list_androids", return_value=devices):
            return android_source._pick_device("adb", serial)

    def test_picks_ready_phone(self):
        self.assertEqual(self.pick([("abc", "device")]), "abc")

    def test_unauthorized_phone(self):
        with self.assertRaisesRegex(ConnectionError, "Allow"):
            self.pick([("abc", "unauthorized")])

    def test_no_phone(self):
        with self.assertRaisesRegex(ConnectionError, "USB debugging"):
            self.pick([])

    def test_parses_adb_devices(self):
        out = "List of devices attached\nR58N123\tdevice\nemulator-5554\toffline\n\n"
        fake = mock.Mock(stdout=out)
        with mock.patch.object(android_source, "_run", return_value=fake):
            self.assertEqual(android_source.list_androids("adb"),
                             [("R58N123", "device"), ("emulator-5554", "offline")])


class ServerDownloadTests(unittest.TestCase):
    def test_rejects_tampered_download(self):
        tmp = os.path.join(os.path.dirname(__file__), "_tmp_data")
        os.makedirs(tmp, exist_ok=True)
        bad = mock.MagicMock()
        bad.__enter__.return_value.read.return_value = b"not the real server"
        try:
            with mock.patch.object(android_source, "data_dir", return_value=tmp), \
                 mock.patch("urllib.request.urlopen", return_value=bad):
                with self.assertRaisesRegex(ConnectionError, "safety check"):
                    android_source.server_file()
            self.assertFalse(os.listdir(tmp))
        finally:
            for f in os.listdir(tmp):
                os.remove(os.path.join(tmp, f))
            os.rmdir(tmp)

    def test_checksum_is_pinned(self):
        self.assertEqual(len(android_source.SERVER_SHA256), 64)
        self.assertEqual(hashlib.sha256(b"").hexdigest() != android_source.SERVER_SHA256, True)


if __name__ == "__main__":
    unittest.main()
