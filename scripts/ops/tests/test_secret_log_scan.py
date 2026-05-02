#!/usr/bin/env python3
from __future__ import annotations

import sys
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
SCRIPT_PATH = SCRIPT_DIR / "secret_log_scan.py"
sys.path.insert(0, str(SCRIPT_DIR))

from secret_log_scan import scan_text  # noqa: E402


class SecretLogScanTests(unittest.TestCase):
    def test_detects_act_token_without_printing_raw_value(self) -> None:
        raw_token = "2571b1659ff3498daa462b30365bfd63"
        text = (
            'wukongim-1 | {"msg":"token verify fail",'
            f'"uid":"u1","actToken":"{raw_token}"}}'
        )

        result = scan_text(text, source="wukongim")

        self.assertEqual(result.finding_count, 1)
        self.assertIn("actToken", result.redacted_report)
        self.assertIn("<redacted>", result.redacted_report)
        self.assertNotIn(raw_token, result.redacted_report)

    def test_ignores_safe_token_metadata(self) -> None:
        text = "auth_token_verify_failed uid=u1 token_empty=false token_hash=abcdef12 phase=im_connect"

        result = scan_text(text, source="tsdd-api")

        self.assertEqual(result.finding_count, 0)
        self.assertEqual(result.redacted_report, "")

    def test_detects_exact_dangerous_field_names(self) -> None:
        cases = [
            ("password=raw", "password"),
            ('"api_key":"raw"', "api_key"),
            ("Authorization: Bearer raw", "Authorization"),
            ("token=raw", "token"),
        ]

        for text, field in cases:
            with self.subTest(text=text):
                result = scan_text(text, source="dangerous")

                self.assertEqual(result.finding_count, 1)
                self.assertIn(field, result.redacted_report)
                self.assertIn("<redacted>", result.redacted_report)
                self.assertNotIn("raw", result.redacted_report)

    def test_redacts_multiple_secret_fields_on_same_line(self) -> None:
        text = '{"actToken":"raw1","password":"raw2"}'

        result = scan_text(text, source="mixed")

        self.assertEqual(result.finding_count, 2)
        self.assertIn("actToken", result.redacted_report)
        self.assertIn("password", result.redacted_report)
        self.assertNotIn("raw1", result.redacted_report)
        self.assertNotIn("raw2", result.redacted_report)

    def test_safe_metadata_and_real_secret_on_same_line_counts_only_secret(self) -> None:
        text = "token_hash=abc actToken=raw"

        result = scan_text(text, source="metadata")

        self.assertEqual(result.finding_count, 1)
        self.assertIn("token_hash=abc", result.redacted_report)
        self.assertIn("actToken=<redacted>", result.redacted_report)
        self.assertNotIn("token_hash=<redacted>", result.redacted_report)
        self.assertNotIn("actToken=raw", result.redacted_report)

    def test_decodes_docker_json_file_log_payload(self) -> None:
        text = '{"log":"{\\"actToken\\":\\"rawsecret\\"}\\n"}'

        result = scan_text(text, source="docker")

        self.assertEqual(result.finding_count, 1)
        self.assertIn("actToken", result.redacted_report)
        self.assertIn("<redacted>", result.redacted_report)
        self.assertNotIn("rawsecret", result.redacted_report)

    def test_cli_stdin_and_file_exit_behavior(self) -> None:
        stdin_result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--source", "stdin-log"],
            input=b"password=raw\n",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        self.assertEqual(stdin_result.returncode, 1)
        self.assertIn(b"stdin-log:1:", stdin_result.stdout)
        self.assertIn(b"<redacted>", stdin_result.stdout)
        self.assertNotIn(b"raw", stdin_result.stdout)
        self.assertEqual(stdin_result.stderr, b"")

        with tempfile.TemporaryDirectory() as tmp_dir:
            log_path = Path(tmp_dir) / "app.log"
            log_path.write_text("no secrets here\n", encoding="utf-8")

            file_result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), str(log_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(file_result.returncode, 0)
        self.assertEqual(file_result.stdout, b"")
        self.assertEqual(file_result.stderr, b"")

    def test_cli_missing_file_returns_distinct_error_code(self) -> None:
        missing_path = Path(tempfile.gettempdir()) / "secret-log-scan-missing-file.log"
        if missing_path.exists():
            self.fail(f"Test fixture path unexpectedly exists: {missing_path}")

        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), str(missing_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"error:", result.stderr.lower())
        self.assertIn(str(missing_path).encode(), result.stderr)


if __name__ == "__main__":
    unittest.main()
