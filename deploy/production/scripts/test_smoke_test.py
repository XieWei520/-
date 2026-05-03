#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

from smoke_test import explain_http_base_url, validate_base_url

SCRIPT = Path(__file__).with_name("smoke_test.py")


class SmokeBaseUrlTests(unittest.TestCase):
    def test_rejects_http_public_release_url_by_default(self) -> None:
        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=False)

        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=True)

    def test_allows_http_loopback_only_when_explicitly_allowed(self) -> None:
        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://127.0.0.1", allow_http=False)

        self.assertEqual(
            validate_base_url("http://127.0.0.1", allow_http=True),
            "http://127.0.0.1",
        )

    def test_explains_https_equivalent(self) -> None:
        self.assertIn(
            "https://infoequity.qingyunshe.top",
            explain_http_base_url("http://infoequity.qingyunshe.top"),
        )

    def test_rejects_query_or_fragment_in_base_url(self) -> None:
        for url in (
            "https://example.com/api?x=1",
            "https://example.com/api#frag",
        ):
            with self.subTest(url=url):
                with self.assertRaisesRegex(ValueError, "query|fragment|Invalid"):
                    validate_base_url(url)

    def test_normalizes_https_path_prefix_trailing_slash(self) -> None:
        self.assertEqual(
            validate_base_url("https://example.com/api/"),
            "https://example.com/api",
        )
        self.assertEqual(
            validate_base_url("https://example.com/"),
            "https://example.com",
        )

    def test_cli_validation_error_is_concise_exit_2(self) -> None:
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--base-url",
                "http://infoequity.qingyunshe.top",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )

        self.assertEqual(completed.returncode, 2, completed)
        self.assertIn("Use HTTPS", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)


if __name__ == "__main__":
    unittest.main()
