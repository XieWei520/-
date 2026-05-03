#!/usr/bin/env python3
from __future__ import annotations

import unittest

from production_doctor import (
    ServiceStatus,
    evaluate_perf_payload,
    evaluate_services,
    parse_compose_ps_json,
    scan_log_issues,
)


class ProductionDoctorTests(unittest.TestCase):
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

    def test_parse_args_enables_mysql_health_by_default(self) -> None:
        args = __import__("production_doctor").parse_args([])

        self.assertFalse(args.skip_mysql)
        self.assertEqual(args.mysql_max_long_query_time, 0.5)
        self.assertEqual(args.log_since, "30m")


if __name__ == "__main__":
    unittest.main()
