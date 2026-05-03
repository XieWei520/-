#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

from smoke_test import (
    extract_required_field,
    request_json,
    explain_http_base_url,
    redact_text,
    validate_base_url,
)

SCRIPT = Path(__file__).with_name("smoke_test.py")


def assert_absent_without_echo(
    test_case: unittest.TestCase,
    needle: str,
    haystack: str,
    label: str,
) -> None:
    if needle in haystack:
        test_case.fail(f"{label} was present in diagnostic output")


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


class SmokeRedactionTests(unittest.TestCase):
    def test_redact_text_redacts_sensitive_prefix_before_json_payload(self) -> None:
        cases = (
            (
                'token=abc123 {"ok":true,"token":"def456"}',
                ("abc123", "def456"),
                ("token=<redacted>", '"token":"<redacted>"'),
            ),
            (
                'dsn=mysql://user:pass@host/db {"data":{"api_key":"json-key-value"}}',
                ("mysql://user:pass@host/db", "json-key-value"),
                ("dsn=<redacted>", '"api_key":"<redacted>"'),
            ),
        )

        for raw, secret_values, expected_fragments in cases:
            with self.subTest(raw=raw.split(" ", 1)[0]):
                rendered = redact_text(raw)
                for value in secret_values:
                    assert_absent_without_echo(self, value, rendered, "sensitive prefix/json value")
                for fragment in expected_fragments:
                    self.assertIn(fragment, rendered)

    def test_redact_text_covers_dsn_credential_and_pass_style_names(self) -> None:
        sensitive_values = {
            "mysqlDsn": "mysql://" + "redaction-db/app",
            "apiCredential": "api-" + "credential-regression",
            "redisPass": "redis-" + "pass-regression",
            "adminpwd": "admin-" + "pwd-regression",
            "DSN": "dsn-" + "regression",
            "credential": "credential-" + "regression",
        }

        json_rendered = redact_text(json.dumps({"nested": sensitive_values}))
        text_rendered = redact_text(
            "\n".join(
                f"{key}: {value}" if key in {"apiCredential", "adminpwd", "credential"} else f"{key}={value}"
                for key, value in sensitive_values.items()
            )
        )

        for label, value in sensitive_values.items():
            with self.subTest(label=label, source="json"):
                assert_absent_without_echo(self, value, json_rendered, label)
            with self.subTest(label=label, source="text"):
                assert_absent_without_echo(self, value, text_rendered, label)
        self.assertIn("<redacted>", json_rendered)
        self.assertIn("<redacted>", text_rendered)

    def test_redact_text_redacts_full_multi_token_sensitive_field_values(self) -> None:
        authorization_tail = "shorttail"
        credential_tail = "short spaced tail"
        rendered = redact_text(
            "\n".join(
                [
                    f"authorization: Bearer {authorization_tail}",
                    f"apiCredential: Basic {credential_tail}",
                    "message: still visible",
                ]
            )
        )

        assert_absent_without_echo(self, "Bearer", rendered, "authorization scheme")
        assert_absent_without_echo(self, authorization_tail, rendered, "authorization tail")
        assert_absent_without_echo(self, "Basic", rendered, "credential scheme")
        assert_absent_without_echo(self, credential_tail, rendered, "credential tail")
        self.assertEqual(rendered.count("<redacted>"), 2)
        self.assertIn("message: still visible", rendered)

    def test_missing_required_field_error_reports_shape_without_secret_values(self) -> None:
        payload = {
            "code": 0,
            "data": {
                "password": "passwordValue123",
                "token": "tokenValue123",
                "safe": "present",
            },
        }

        with self.assertRaisesRegex(RuntimeError, "shape|keys"):
            extract_required_field(payload, "uid")

        try:
            extract_required_field(payload, "uid")
        except RuntimeError as exc:
            message = str(exc)
        else:  # pragma: no cover - defensive guard
            self.fail("extract_required_field unexpectedly found uid")

        assert_absent_without_echo(self, "passwordValue123", message, "password value")
        assert_absent_without_echo(self, "tokenValue123", message, "token value")

    def test_http_error_redacts_sensitive_response_body_values(self) -> None:
        import urllib.error
        from unittest import mock

        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"
        sensitive_password = "passwordValue123"
        body = (
            b'{"token":"tokenValue1234567890abcdefghijklmnopqrstuvwxyz",'
            b'"password":"passwordValue123","message":"failed"}'
        )
        http_error = urllib.error.HTTPError(
            url="https://example.invalid/v1",
            code=500,
            msg="server error",
            hdrs={},
            fp=None,
        )
        http_error.read = lambda: body  # type: ignore[method-assign]

        with mock.patch("smoke_test.request.urlopen", side_effect=http_error):
            with self.assertRaises(RuntimeError) as caught:
                request_json(
                    base_url="https://example.invalid",
                    method="POST",
                    path="/v1",
                    app_id="app",
                    app_key="<app-signing-secret>",
                    device_id="device",
                    device_session_id="session",
                    payload={"password": sensitive_password},
                    timeout=1.0,
                )

        message = str(caught.exception)
        assert_absent_without_echo(self, sensitive_token, message, "token value")
        assert_absent_without_echo(self, sensitive_password, message, "password value")
        self.assertIn("<redacted>", message)

    def test_url_error_redacts_sensitive_reason_values(self) -> None:
        import urllib.error
        from unittest import mock

        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"

        with mock.patch(
            "smoke_test.request.urlopen",
            side_effect=urllib.error.URLError(f"connection failed token={sensitive_token}"),
        ):
            with self.assertRaises(RuntimeError) as caught:
                request_json(
                    base_url="https://example.invalid",
                    method="GET",
                    path="/v1",
                    app_id="app",
                    app_key="<app-signing-secret>",
                    device_id="device",
                    device_session_id="session",
                    timeout=1.0,
                )

        message = str(caught.exception)
        assert_absent_without_echo(self, sensitive_token, message, "token value")
        self.assertIn("<redacted>", message)


if __name__ == "__main__":
    unittest.main()
