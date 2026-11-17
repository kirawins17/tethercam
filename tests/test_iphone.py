"""Tests for the iPhone source: usbmux handshake and frame protocol, using a fake iPhone."""
import os
import plistlib
import socket
import struct
import sys
import threading
import unittest

import cv2
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "pc"))
import iphone_source as tethercam  # noqa: E402
import tethercam as main  # noqa: E402

JPEG = cv2.imencode(".jpg", np.full((720, 1280, 3), 90, np.uint8))[1].tobytes()


def fake_usbmuxd(conn, devices, connect_result=0):
    def read():
        length, _, _, tag = struct.unpack("<IIII", tethercam.recv_exact(conn, 16))
        return plistlib.loads(tethercam.recv_exact(conn, length - 16)), tag

    def write(obj, tag):
        body = plistlib.dumps(obj)
        conn.sendall(struct.pack("<IIII", 16 + len(body), 1, 8, tag) + body)

    try:
        req, tag = read()
    except ConnectionError:  # the client only checked that the service is there
        conn.close()
        return
    if req["MessageType"] == "ListDevices":
        write({"DeviceList": devices}, tag)
    elif req["MessageType"] == "Connect":
        assert req["PortNumber"] == socket.htons(tethercam.PHONE_PORT)
        write({"MessageType": "Result", "Number": connect_result}, tag)
        if connect_result == 0:
            conn.sendall(struct.pack(">I", len(JPEG)) + JPEG)


class ProtocolTests(unittest.TestCase):
    def use_fake(self, devices, connect_result=0):
        def factory():
            a, b = socket.socketpair()
            threading.Thread(target=fake_usbmuxd, args=(b, devices, connect_result),
                             daemon=True).start()
            return a
        tethercam._usbmux_socket = factory

    def test_streams_a_frame(self):
        self.use_fake([{"Properties": {"ConnectionType": "USB", "DeviceID": 7}}])
        sock = tethercam.connect_usb(None, tethercam.PHONE_PORT)
        self.assertEqual(tethercam.read_frame(sock).shape, (720, 1280, 3))

    def test_no_phone(self):
        self.use_fake([])
        with self.assertRaises(ConnectionError):
            tethercam.connect_usb(None, tethercam.PHONE_PORT)

    def test_ignores_wifi_devices(self):
        self.use_fake([{"Properties": {"ConnectionType": "Network", "DeviceID": 9}}])
        with self.assertRaises(ConnectionError):
            tethercam.connect_usb(None, tethercam.PHONE_PORT)

    def test_app_not_open(self):
        self.use_fake([{"Properties": {"ConnectionType": "USB", "DeviceID": 7}}], connect_result=3)
        with self.assertRaises(ConnectionError):
            tethercam.connect_usb(None, tethercam.PHONE_PORT)

    def test_rejects_huge_frame(self):
        a, b = socket.socketpair()
        b.sendall(struct.pack(">I", tethercam.MAX_FRAME_BYTES + 1))
        with self.assertRaises(ConnectionError):
            tethercam.read_frame(a)

    def test_fit_letterboxes(self):
        out = main.fit(np.zeros((1280, 720, 3), np.uint8), 1280, 720)
        self.assertEqual(out.shape, (720, 1280, 3))


if __name__ == "__main__":
    unittest.main()
