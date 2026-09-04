import ast
import json
import struct
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class ReleaseTests(unittest.TestCase):
    def test_published_tree_excludes_private_or_agent_files(self):
        paths = subprocess.check_output(["git","ls-files","-z"],cwd=ROOT).decode().split("\0")
        forbidden = {"agents.md","agents.override.md","project.md"}
        for name in filter(None,paths):
            p = Path(name)
            self.assertFalse(any(part.casefold() in forbidden for part in p.parts),name)
            self.assertNotIn("work",p.parts,name)
            self.assertNotIn("__pycache__",p.parts,name)
            self.assertFalse(p.is_absolute(),name)

    def test_no_missing_local_runtime_imports(self):
        for name in ("lenslink_backend.py","obs_control.py","secure_io.py"):
            tree=ast.parse((ROOT/name).read_text())
            for node in ast.walk(tree):
                if isinstance(node,ast.ImportFrom) and node.module in {"runtime_guard","secure_io","obs_control"}:
                    self.assertTrue((ROOT/(node.module+".py")).is_file(),node.module)

    def test_marketplace_payload_and_preview(self):
        manifest=json.loads((ROOT/"manifest.json").read_text())
        self.assertEqual(manifest["id"],"io.github.camerontucker.lenslink")
        self.assertEqual(manifest["entryPoints"]["barWidget"],"Panel.qml")
        for name in ("LICENSE","README.md","SECURITY.md","docs/ASSETS.md","docs/SECURITY_VERIFICATION.md"):
            self.assertTrue((ROOT/name).is_file(),name)
        data=(ROOT/"preview.png").read_bytes()
        self.assertEqual(data[:8],b"\x89PNG\r\n\x1a\n")
        width,height=struct.unpack("!II",data[16:24])
        self.assertLessEqual(width*height,40000000)
        self.assertLessEqual(len(data),50000000)
        self.assertNotIn(b"eXIf",data)

    def test_capture_hooks_are_not_shipped(self):
        panel=(ROOT/"Panel.qml").read_text()
        self.assertNotIn("capturePreview",panel)
        self.assertNotIn("saveToFile",panel)
        self.assertNotIn("synthetic-meeting-feed",panel)
