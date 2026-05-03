#!/usr/bin/env python3
from __future__ import annotations

import unittest

from apply_device_flag_migration import build_migration_steps, parse_count


class DeviceFlagMigrationTests(unittest.TestCase):
    def test_parse_count_reads_mysql_scalar_output(self) -> None:
        self.assertEqual(parse_count("1\n"), 1)
        self.assertEqual(parse_count("mysql: [Warning] ignored\n0\n"), 0)

    def test_build_migration_steps_adds_column_before_index(self) -> None:
        steps = build_migration_steps(has_column=False, has_index=False)

        self.assertEqual(len(steps), 2)
        self.assertIn("ADD COLUMN `device_flag`", steps[0].sql)
        self.assertIn("CREATE INDEX `device_uid_flag_last_login_idx`", steps[1].sql)

    def test_build_migration_steps_only_adds_missing_index(self) -> None:
        steps = build_migration_steps(has_column=True, has_index=False)

        self.assertEqual(len(steps), 1)
        self.assertIn("CREATE INDEX", steps[0].sql)

    def test_build_migration_steps_is_empty_when_already_applied(self) -> None:
        self.assertEqual(build_migration_steps(has_column=True, has_index=True), [])


if __name__ == "__main__":
    unittest.main()
