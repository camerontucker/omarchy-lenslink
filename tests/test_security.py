import json
import os
import socket
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch
import obs_control as obs
import secure_io as files

class FileBoundaryTests(unittest.TestCase):
    def test_fifo_symlink_hardlink_and_unsafe_parent_rejected_without_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            target = root / "settings.json"
            real = root / "real"
            real.write_bytes(b"secret")
            real.chmod(0o600)
            start = time.monotonic()
            os.mkfifo(target)
            with self.assertRaises(files.UnsafeInput):
                files.read_file(target)
            with self.assertRaises(files.UnsafeInput):
                files.write_file(target, b"{}")
            target.unlink()
            target.symlink_to(real)
            with self.assertRaises(OSError):
                files.read_file(target)
            with self.assertRaises(OSError):
                files.write_file(target, b"{}")
            self.assertEqual(real.read_bytes(), b"secret")
            target.unlink()
            os.link(real, target)
            with self.assertRaises(files.UnsafeInput):
                files.read_file(target)
            target.unlink()
            root.chmod(0o777)
            with self.assertRaises(files.UnsafeInput):
                files.read_file(real)
            root.chmod(0o700)
            self.assertLess(time.monotonic() - start, 1)

class ObsBoundaryTests(unittest.TestCase):
    def test_handshake_eof_closes_socket(self):
        from unittest.mock import MagicMock
        sock = MagicMock()
        sock.recv.return_value = b""
        with patch.object(socket, "create_connection", return_value=sock), self.assertRaises(obs.ObsError):
            obs.WebSocket(4455)
        sock.close.assert_called_once()

    def test_drip_and_ping_stream_have_absolute_and_frame_limits(self):
        client, server = socket.socketpair()
        ws = obs.WebSocket.__new__(obs.WebSocket)
        ws.sock, ws.buffer, ws.frames = client, b"", 0
        ws.deadline = time.monotonic() + .15
        stopped = threading.Event()
        def drip():
            while not stopped.wait(.02):
                try:
                    server.send(b'x')
                except OSError:
                    break
        thread = threading.Thread(target=drip)
        thread.start()
        try:
            with self.assertRaises((obs.ObsError, OSError)):
                ws._read(100)
        finally:
            stopped.set(); thread.join(); client.close(); server.close()
        ws = obs.WebSocket.__new__(obs.WebSocket)
        ws.frames = 0
        with patch.object(ws, "_read", side_effect=lambda count: b'\x89\x00' if count == 2 else b''), \
             patch.object(ws, "_send_control"), self.assertRaises(obs.ObsError):
            ws.receive()

class JsonBoundaryTests(unittest.TestCase):
    def test_malformed_network_objects_are_rejected(self):
        for raw in (b'[]', b'{"x":NaN}', b'{"x":1e309}', b'{"x":1,"x":2}',
                    b'{"x":' + b'['*40 + b'0' + b']'*40 + b'}',
                    json.dumps({"x":"a"*1025}).encode()):
            with self.subTest(raw=raw[:24]), self.assertRaises(files.UnsafeInput):
                files.json_object(raw)

    def test_non_private_obs_credentials_rejected_before_connect(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"config.json"
            path.write_text('{"server_password":"test-only","server_port":4455}')
            path.chmod(0o644)
            with patch.object(obs,"OBS_CONFIG",path), patch.object(obs,"WebSocket") as websocket:
                with self.assertRaises(files.UnsafeInput): obs.Obs()
                websocket.assert_not_called()
