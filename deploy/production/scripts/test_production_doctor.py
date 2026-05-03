#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest

from production_doctor import (
    CheckResult,
    ServiceStatus,
    evaluate_perf_payload,
    evaluate_services,
    evaluate_logs,
    parse_compose_ps_json,
    redact_text,
    render_result,
    run_edge_check,
    scan_log_issues,
)


def assert_absent_without_echo(
    test_case: unittest.TestCase,
    needle: str,
    haystack: str,
    label: str,
) -> None:
    if needle in haystack:
        test_case.fail(f"{label} was present in diagnostic output")


class ProductionDoctorTests(unittest.TestCase):
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

    def test_parse_compose_ps_json_accepts_array_output(self) -> None:
        payload = """
        [
          {"Service":"nginx","State":"running","Health":""},
          {"Service":"tsdd-api","State":"running","Health":"healthy"}
        ]
        """

        statuses = parse_compose_ps_json(payload)

        self.assertEqual(statuses["nginx"].state, "running")
        self.assertEqual(statuses["tsdd-api"].health, "healthy")

    def test_parse_compose_ps_json_accepts_ndjson_output(self) -> None:
        payload = (
            '{"Service":"nginx","State":"running","Health":""}\n'
            '{"Service":"wukongim","State":"running","Health":"healthy"}\n'
        )

        statuses = parse_compose_ps_json(payload)

        self.assertEqual(set(statuses), {"nginx", "wukongim"})

    def test_evaluate_services_flags_missing_and_unhealthy_services(self) -> None:
        statuses = {
            "nginx": ServiceStatus("nginx", "running", ""),
            "wukongim": ServiceStatus("wukongim", "running", "unhealthy"),
        }

        result = evaluate_services(statuses, required_services=("nginx", "wukongim", "mysql"))

        self.assertFalse(result.ok)
        self.assertIn("mysql missing", result.detail)
        self.assertIn("wukongim health=unhealthy", result.detail)

    def test_scan_log_issues_detects_severe_runtime_lines(self) -> None:
        logs = """
        nginx started
        tsdd-api panic: connection pool exhausted
        wukongim {"level":"error","msg":"failed to parse frame"}
        """

        issues = scan_log_issues(logs)

        self.assertEqual(len(issues), 2)
        self.assertIn("panic", issues[0].lower())
        self.assertIn("error", issues[1].lower())

    def test_log_issue_preview_redacts_sensitive_values(self) -> None:
        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"
        sensitive_password = "passwordValue123"
        logs = (
            f'tsdd-api {{"level":"error","token":"{sensitive_token}",'
            f'"password":"{sensitive_password}","msg":"failed"}}'
        )

        result = evaluate_logs(logs)
        rendered = render_result(result)

        self.assertFalse(result.ok)
        assert_absent_without_echo(self, sensitive_token, rendered, "token value")
        assert_absent_without_echo(self, sensitive_password, rendered, "password value")
        self.assertIn("<redacted>", rendered)

    def test_log_issue_preview_redacts_dsn_credential_and_pass_style_names(self) -> None:
        sensitive_values = {
            "mysqlDsn": "mysql://" + "redaction-db/app",
            "apiCredential": "api-" + "credential-regression",
            "redisPass": "redis-" + "pass-regression",
            "adminpwd": "admin-" + "pwd-regression",
            "DSN": "dsn-" + "regression",
            "credential": "credential-" + "regression",
        }
        logs = "\n".join(
            [
                "tsdd-api "
                + json.dumps({"level": "error", "msg": "failed", **sensitive_values}),
                "fatal bootstrap "
                + " ".join(
                    f"{key}: {value}" if key in {"apiCredential", "adminpwd", "credential"} else f"{key}={value}"
                    for key, value in sensitive_values.items()
                ),
            ]
        )

        result = evaluate_logs(logs)
        rendered = render_result(result)

        self.assertFalse(result.ok)
        for label, value in sensitive_values.items():
            with self.subTest(label=label):
                assert_absent_without_echo(self, value, rendered, label)
        self.assertIn("<redacted>", rendered)

    def test_scan_log_issues_ignores_business_info_failed_lines(self) -> None:
        logs = """
        wukongim {"level":"info","msg":"hasPermissionForChannel failed","reasonCode":"ReasonDisband"}
        """

        self.assertEqual(scan_log_issues(logs), [])

    def test_evaluate_perf_payload_enforces_p95_thresholds(self) -> None:
        result = evaluate_perf_payload(
            '{"setting_p95_ms": 120.5, "favorites_p95_ms": 80.0, "failure_rate": 0.0}',
            setting_p95_limit_ms=200.0,
            favorites_p95_limit_ms=200.0,
            max_failure_rate=0.0,
        )

        self.assertTrue(result.ok)

        slow = evaluate_perf_payload(
            '{"setting_p95_ms": 260.0, "favorites_p95_ms": 80.0, "failure_rate": 0.2}',
            setting_p95_limit_ms=200.0,
            favorites_p95_limit_ms=200.0,
            max_failure_rate=0.1,
        )

        self.assertFalse(slow.ok)
        self.assertIn("setting_p95_ms=260.0", slow.detail)
        self.assertIn("failure_rate=0.2", slow.detail)

    def test_evaluate_perf_payload_missing_fields_reports_keys_not_sensitive_payload(self) -> None:
        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"
        sensitive_password = "passwordValue123"

        result = evaluate_perf_payload(
            (
                '{"failure_rate": 0.0, '
                f'"token": "{sensitive_token}", '
                f'"password": "{sensitive_password}"'
                "}"
            ),
            setting_p95_limit_ms=200.0,
            favorites_p95_limit_ms=200.0,
            max_failure_rate=0.0,
        )

        self.assertFalse(result.ok)
        self.assertRegex(result.detail, "keys|shape")
        assert_absent_without_echo(self, sensitive_token, result.detail, "token value")
        assert_absent_without_echo(self, sensitive_password, result.detail, "password value")

    def test_run_edge_check_redacts_sensitive_failure_details(self) -> None:
        import argparse
        from unittest import mock

        sensitive_token = "tokenValue1234567890abcdefghijklmnopqrstuvwxyz"
        args = argparse.Namespace(env_file=".env", edge_timeout=1.0, insecure_tls=False)

        with mock.patch("production_doctor.edge_health_check.parse_args", return_value=args):
            with mock.patch(
                "production_doctor.edge_health_check.run_checks",
                return_value=[CheckResult("https api ping", False, f"failed token={sensitive_token}")],
            ):
                result = run_edge_check(args)

        self.assertFalse(result.ok)
        assert_absent_without_echo(self, sensitive_token, result.detail, "token value")
        self.assertIn("<redacted>", result.detail)

    def test_parse_args_enables_mysql_health_by_default(self) -> None:
        args = __import__("production_doctor").parse_args([])

        self.assertFalse(args.skip_mysql)
        self.assertEqual(args.mysql_max_long_query_time, 0.5)
        self.assertEqual(args.log_since, "30m")


if __name__ == "__main__":
    unittest.main()
