#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_patch_static.py"


class VerifyPatchStaticTests(unittest.TestCase):
    def _write_source(self, body: str) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        source = root / "internal" / "user" / "handler"
        source.mkdir(parents=True)
        (source / "event_connect.go").write_text(textwrap.dedent(body), encoding="utf-8")
        return root

    def _run(self, root: Path) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run([sys.executable, str(SCRIPT), str(root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def test_rejects_raw_act_and_expect_token_fields(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            func f() {
                h.Error("token verify fail", zap.String("expectToken", device.Token), zap.String("actToken", connectPacket.Token))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"expectToken", result.stderr)
        self.assertIn(b"actToken", result.stderr)

    def test_rejects_manager_raw_token_field(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            func f() {
                h.Error("manager token verify fail", zap.String("token", connectPacket.Token))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"manager raw token", result.stderr.lower())

    def test_accepts_hash_only_redacted_logging(self) -> None:
        root = self._write_source('''
            package handler
            import (
                "crypto/sha256"
                "encoding/hex"
                "go.uber.org/zap"
            )
            func tokenFingerprint(token string) string {
                if token == "" { return "empty" }
                sum := sha256.Sum256([]byte(token))
                return hex.EncodeToString(sum[:])[:12]
            }
            func f() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
        self.assertEqual(result.stdout, b"WuKongIM token log patch static verification passed\n")


if __name__ == "__main__":
    unittest.main()
