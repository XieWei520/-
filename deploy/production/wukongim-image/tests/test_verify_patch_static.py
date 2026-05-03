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

    def _hash_only_source(self, extra_logs: str = "") -> str:
        return '''
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
        ''' + extra_logs + '''
            }
        '''

    def _source_with_token_fingerprint_body(self, body: str, extra_imports: str = "") -> str:
        return '''
            package handler
            import (
        ''' + extra_imports + '''
                "crypto/sha256"
                "encoding/hex"
                "go.uber.org/zap"
            )
            func tokenFingerprint(token string) string {
        ''' + body + '''
            }
            func f() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        '''

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

    def test_rejects_token_fingerprint_that_returns_raw_token(self) -> None:
        root = self._write_source('''
            package handler
            import (
                "crypto/sha256"
                "encoding/hex"
                "go.uber.org/zap"
            )
            func tokenFingerprint(token string) string {
                if token == "" { return "empty" }
                return token
            }
            func f() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"return token", result.stderr)

    def test_rejects_token_fingerprint_returning_token_via_string_conversion(self) -> None:
        root = self._write_source(self._source_with_token_fingerprint_body('''
                if token == "" { return "empty" }
                sum := sha256.Sum256([]byte(token))
                _ = hex.EncodeToString(sum[:])[:12]
                return string([]byte(token))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"unsafe tokenFingerprint return", result.stderr)
        self.assertIn(b"string([]byte(token))", result.stderr)

    def test_rejects_token_fingerprint_returning_token_via_fmt_sprintf(self) -> None:
        root = self._write_source(self._source_with_token_fingerprint_body('''
                if token == "" { return "empty" }
                sum := sha256.Sum256([]byte(token))
                _ = hex.EncodeToString(sum[:])[:12]
                return fmt.Sprintf("%s", token)
        ''', extra_imports='''
                "fmt"
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"unsafe tokenFingerprint return", result.stderr)
        self.assertIn(b"fmt.Sprintf", result.stderr)

    def test_rejects_zap_any_raw_connect_token(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.Any("token", connectPacket.Token))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.Any", result.stderr)
        self.assertIn(b"connectPacket.Token", result.stderr)

    def test_rejects_direct_device_token_with_unplanned_zap_field(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.Reflect("unexpectedField", device.Token))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.Reflect", result.stderr)
        self.assertIn(b"device.Token", result.stderr)

    def test_rejects_hash_looking_source_missing_required_hash_snippet(self) -> None:
        root = self._write_source('''
            package handler
            import (
                "crypto/sha256"
                "encoding/hex"
                "go.uber.org/zap"
            )
            func tokenFingerprint(token string) string {
                if token == "" { return "empty" }
                sum := []byte(token)
                return hex.EncodeToString(sum[:])[:12]
            }
            func f() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"sha256.Sum256", result.stderr)

    def test_rejects_token_fingerprint_with_unused_hash_and_raw_sum(self) -> None:
        root = self._write_source(self._source_with_token_fingerprint_body('''
                if token == "" { return "empty" }
                _ = sha256.Sum256([]byte(token))
                sum := []byte(token)
                return hex.EncodeToString(sum[:])[:12]
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"tokenFingerprint body", result.stderr)

    def test_rejects_zap_any_token_inside_collection(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.Any("token", []string{connectPacket.Token}))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.Any", result.stderr)
        self.assertIn(b"connectPacket.Token", result.stderr)

    def test_rejects_zap_string_token_inside_format_expression(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.String("token", fmt.Sprintf("%s", connectPacket.Token)))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.String", result.stderr)
        self.assertIn(b"fmt.Sprintf", result.stderr)

    def test_rejects_required_snippets_inside_comments_only(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            /*
            import (
                "crypto/sha256"
                "encoding/hex"
            )
            func tokenFingerprint(token string) string {
                if token == "" { return "empty" }
                sum := sha256.Sum256([]byte(token))
                return hex.EncodeToString(sum[:])[:12]
            }
            func commented() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
            */
            func f() {
                h.Info("no redaction implementation here")
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"missing required redaction snippet", result.stderr)

    def test_rejects_mytoken_fingerprint_substring_callee_in_zap_call(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.String("tokenHash", mytokenFingerprint(connectPacket.Token)))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.String", result.stderr)
        self.assertIn(b"mytokenFingerprint", result.stderr)

    def test_accepts_safe_token_fingerprint_body_with_compact_operator_spacing(self) -> None:
        root = self._write_source(self._source_with_token_fingerprint_body('''
                if token==""{return "empty"}
                sum:=sha256.Sum256([]byte(token))
                return hex.EncodeToString(sum[:])[:12]
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))

    def test_accepts_safe_token_fingerprint_body_with_split_return_slice_bound(self) -> None:
        root = self._write_source(self._source_with_token_fingerprint_body('''
                if token == "" {
                    return "empty"
                }
                sum := sha256.Sum256([]byte(token))
                return hex.EncodeToString(sum[:])[:
                    12]
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))

    def test_rejects_required_zap_fields_inside_raw_string_only(self) -> None:
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
                _ = `
                    zap.String("stage", "manager_token")
                    zap.String("tokenHash", tokenFingerprint(connectPacket.Token))
                    zap.String("stage", "device_token")
                    zap.String("expectedTokenHash", tokenFingerprint(device.Token))
                    zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token))
                `
                h.Info("no actual redacted zap fields")
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"missing required zap field", result.stderr)

    def test_rejects_sugared_infow_raw_connect_token(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Sugar().Infow("token leak", "token", connectPacket.Token)
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"Infow", result.stderr)
        self.assertIn(b"connectPacket.Token", result.stderr)

    def test_rejects_imports_and_token_fingerprint_inside_raw_string_only(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            func f() {
                _ = `
                    import (
                        "crypto/sha256"
                        "encoding/hex"
                    )
                    func tokenFingerprint(token string) string {
                        if token == "" { return "empty" }
                        sum := sha256.Sum256([]byte(token))
                        return hex.EncodeToString(sum[:])[:12]
                    }
                `
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"missing required import", result.stderr)
        self.assertIn(b"missing func tokenFingerprint", result.stderr)

    def test_rejects_zap_string_with_spaced_connect_token_selector(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.String("token", connectPacket . Token))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.String", result.stderr)
        self.assertIn(b"connectPacket", result.stderr)

    def test_rejects_zap_any_with_newline_connect_token_selector(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Error("token leak", zap.Any("token", connectPacket.
                    Token))
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"zap.Any", result.stderr)
        self.assertIn(b"connectPacket", result.stderr)

    def test_rejects_sugared_infow_with_spaced_device_token_selector(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Sugar().Infow("leak", "token", device . Token)
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"Infow", result.stderr)
        self.assertIn(b"device", result.stderr)

    def test_accepts_allowed_token_fingerprint_calls_with_spaced_selectors(self) -> None:
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
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket . Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.
                    Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket . Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))

    def test_rejects_sugared_error_raw_connect_token(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Sugar().Error("token leak", connectPacket.Token)
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"Error", result.stderr)
        self.assertIn(b"connectPacket.Token", result.stderr)

    def test_rejects_sugared_info_spaced_device_token(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Sugar().Info("token leak", device . Token)
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"Info", result.stderr)
        self.assertIn(b"device", result.stderr)

    def test_rejects_sugared_warn_and_debug_raw_tokens(self) -> None:
        root = self._write_source(self._hash_only_source('''
                h.Sugar().Warn("token leak", connectPacket.Token)
                h.Sugar().Debug("token leak", device.Token)
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"Warn", result.stderr)
        self.assertIn(b"Debug", result.stderr)

    def test_accepts_hash_only_redacted_logging(self) -> None:
        root = self._write_source(self._hash_only_source('''
                if device.Token != connectPacket.Token {
                    h.Debug("token mismatch without logging raw values")
                }
        '''))
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
        self.assertEqual(result.stdout, b"WuKongIM token log patch static verification passed\n")


if __name__ == "__main__":
    unittest.main()
