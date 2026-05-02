#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
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


if __name__ == "__main__":
    unittest.main()
