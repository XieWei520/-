#!/usr/bin/env python3
from __future__ import annotations

import unittest

from mysql_health_check import (
    RequiredColumn,
    RequiredIndex,
    evaluate_required_columns,
    evaluate_required_indexes,
    parse_column_rows,
    evaluate_slow_query_variables,
    parse_index_rows,
    parse_variable_rows,
)


class MysqlHealthCheckTests(unittest.TestCase):
    def test_parse_variable_rows_reads_mysql_batch_output(self) -> None:
        rows = parse_variable_rows(
            "slow_query_log\tON\nlong_query_time\t0.200000\n"
        )

        self.assertEqual(rows["slow_query_log"], "ON")
        self.assertEqual(rows["long_query_time"], "0.200000")

    def test_evaluate_slow_query_variables_enforces_enabled_and_threshold(self) -> None:
        ok = evaluate_slow_query_variables(
            {"slow_query_log": "ON", "long_query_time": "0.2"},
            max_long_query_time=0.5,
        )
        slow = evaluate_slow_query_variables(
            {"slow_query_log": "OFF", "long_query_time": "2"},
            max_long_query_time=0.5,
        )

        self.assertTrue(ok.ok)
        self.assertFalse(slow.ok)
        self.assertIn("slow_query_log=OFF", slow.detail)
        self.assertIn("long_query_time=2.0", slow.detail)

    def test_parse_index_rows_groups_table_index_columns(self) -> None:
        indexes = parse_index_rows(
            "favorite\tfavorite_uid_created_at_idx\tuid,created_at\n"
            "device\tdevice_uid_flag_last_login_idx\tuid,device_flag,last_login\n"
        )

        self.assertEqual(
            indexes[("favorite", "favorite_uid_created_at_idx")],
            ("uid", "created_at"),
        )

    def test_parse_column_rows_reads_required_columns(self) -> None:
        columns = parse_column_rows(
            "device\tdevice_flag\nuser_global_setting\tuid\n"
        )

        self.assertIn(("device", "device_flag"), columns)

    def test_evaluate_required_indexes_flags_missing_or_wrong_order(self) -> None:
        required = (
            RequiredIndex("favorite", "favorite_uid_created_at_idx", ("uid", "created_at")),
            RequiredIndex("device", "device_uid_flag_last_login_idx", ("uid", "device_flag", "last_login")),
        )
        indexes = {
            ("favorite", "favorite_uid_created_at_idx"): ("created_at", "uid"),
        }

        result = evaluate_required_indexes(indexes, required)

        self.assertFalse(result.ok)
        self.assertIn("favorite.favorite_uid_created_at_idx columns=created_at,uid", result.detail)
        self.assertIn("device.device_uid_flag_last_login_idx missing", result.detail)

    def test_evaluate_required_columns_flags_missing_columns(self) -> None:
        result = evaluate_required_columns(
            {("user_global_setting", "uid")},
            (
                RequiredColumn("device", "device_flag"),
                RequiredColumn("user_global_setting", "uid"),
            ),
        )

        self.assertFalse(result.ok)
        self.assertIn("device.device_flag missing", result.detail)


if __name__ == "__main__":
    unittest.main()
