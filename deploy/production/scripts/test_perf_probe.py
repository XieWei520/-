#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

from perf_probe import (
    ProbeFailure,
    collect_samples,
    evaluate_thresholds,
    explain_http_base_url,
    extract_required_field,
    request_json,
    summarize_probe_result,
    validate_base_url,
)

SCRIPT = Path(__file__).with_name("perf_probe.py")


def assert_absent_without_echo(
    test_case: unittest.TestCase,
    needle: str,
    haystack: str,
    label: str,
) -> None:
    if needle in haystack:
        test_case.fail(f"{label} was present in diagnostic output")


class PerfProbeTests(unittest.TestCase):
    def test_summarize_probe_result_includes_counts_max_and_failure_rate(self) -> None:
        result = summarize_probe_result(
            setting_samples=[10.0, 20.0, 30.0],
            favorite_samples=[5.0, 15.0],
            failure_count=1,
        )

        self.assertEqual(result["setting_count"], 3)
        self.assertEqual(result["favorites_count"], 2)
        self.assertEqual(result["request_count"], 6)
        self.assertEqual(result["failure_count"], 1)
        self.assertAlmostEqual(result["failure_rate"], 1 / 6)
        self.assertEqual(result["setting_max_ms"], 30.0)
        self.assertEqual(result["favorites_max_ms"], 15.0)

    def test_evaluate_thresholds_reports_latency_and_failure_rate(self) -> None:
        payload = {
            "setting_p95_ms": 260.0,
            "favorites_p95_ms": 80.0,
            "failure_rate": 0.2,
        }

        issues = evaluate_thresholds(
            payload,
            setting_p95_limit_ms=200.0,
            favorites_p95_limit_ms=200.0,
            max_failure_rate=0.1,
        )

        self.assertIn("setting_p95_ms=260.0 > 200.0", issues)
        self.assertIn("failure_rate=0.2 > 0.1", issues)

    def test_collect_samples_records_successes_and_failures(self) -> None:
        def fake_request(endpoint: str) -> float:
            if endpoint == "favorites":
                raise ProbeFailure("favorites failed")
            return 12.5

        collected = collect_samples(
            endpoints=("setting", "favorites"),
            sample_count=3,
            concurrency=2,
            request_once=fake_request,
        )

        self.assertEqual(collected.samples_by_endpoint["setting"], [12.5, 12.5, 12.5])
        self.assertEqual(collected.samples_by_endpoint["favorites"], [])
        self.assertEqual(collected.failure_count, 3)
        self.assertEqual(len(collected.failures), 3)

    def test_rejects_http_public_release_url_by_default(self) -> None:
        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=False)

        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=True)

        self.assertIn(
            "https://infoequity.qingyunshe.top",
            explain_http_base_url("http://infoequity.qingyunshe.top"),
        )

    def test_allows_http_loopback_only_when_explicitly_allowed(self) -> None:
        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://127.0.0.1", allow_http=False)

        self.assertEqual(
            validate_base_url("http://127.0.0.1", allow_http=True),
            "http://127.0.0.1",
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

    def test_missing_required_field_error_reports_shape_without_secret_values(self) -> None:
        payload = {
            "data": {
                "token": "tokenValue123",
                "password": "passwordValue123",
                "safe": "present",
            }
        }

        with self.assertRaises(RuntimeError) as caught:
            extract_required_field(payload, "uid")

        message = str(caught.exception)
        self.assertRegex(message, "shape|keys")
        assert_absent_without_echo(self, "tokenValue123", message, "token value")
        assert_absent_without_echo(self, "passwordValue123", message, "password value")

    def test_request_json_redacts_sensitive_http_error_body_values(self) -> None:
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

        with mock.patch("perf_probe.request.urlopen", side_effect=http_error):
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

    def test_request_json_redacts_sensitive_url_error_values(self) -> None:
        import urllib.error
        from unittest import mock

        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"

        with mock.patch(
            "perf_probe.request.urlopen",
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

    def test_collect_samples_redacts_sensitive_exception_text(self) -> None:
        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"

        def fake_request(_endpoint: str) -> float:
            raise ProbeFailure(f"request failed token={sensitive_token}")

        collected = collect_samples(
            endpoints=("setting",),
            sample_count=1,
            concurrency=1,
            request_once=fake_request,
        )

        joined = "\n".join(collected.failures)
        assert_absent_without_echo(self, sensitive_token, joined, "token value")
        self.assertIn("<redacted>", joined)


if __name__ == "__main__":
    unittest.main()
