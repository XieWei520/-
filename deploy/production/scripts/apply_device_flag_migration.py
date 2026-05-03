#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from mysql_health_check import DEFAULT_ENV_FILE, run_mysql_query


COLUMN_EXISTS_SQL = (
    "SELECT COUNT(*) FROM information_schema.COLUMNS "
    "WHERE TABLE_SCHEMA = DATABASE() "
    "AND TABLE_NAME = 'device' "
    "AND COLUMN_NAME = 'device_flag'"
)
INDEX_EXISTS_SQL = (
    "SELECT COUNT(*) FROM information_schema.STATISTICS "
    "WHERE TABLE_SCHEMA = DATABASE() "
    "AND TABLE_NAME = 'device' "
    "AND INDEX_NAME = 'device_uid_flag_last_login_idx'"
)


@dataclass(frozen=True)
class MigrationStep:
    name: str
    sql: str


def parse_count(text: str) -> int:
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.lower().startswith("mysql:"):
            continue
        return int(line)
    return 0


def build_migration_steps(has_column: bool, has_index: bool) -> list[MigrationStep]:
    steps: list[MigrationStep] = []
    if not has_column:
        steps.append(
            MigrationStep(
                name="add device.device_flag",
                sql=(
                    "ALTER TABLE `device` "
                    "ADD COLUMN `device_flag` SMALLINT NOT NULL DEFAULT 0 "
                    "COMMENT 'device flag: 0 app, 1 web, 2 pc' "
                    "AFTER `device_model`"
                ),
            )
        )
    if not has_index:
        steps.append(
            MigrationStep(
                name="add device_uid_flag_last_login_idx",
                sql=(
                    "CREATE INDEX `device_uid_flag_last_login_idx` "
                    "ON `device` (`uid`, `device_flag`, `last_login`)"
                ),
            )
        )
    return steps


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Apply the idempotent device_flag/device_uid_flag_last_login_idx migration."
    )
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE, help="Path to .env file.")
    parser.add_argument("--timeout", type=float, default=60.0, help="Per MySQL command timeout.")
    parser.add_argument("--apply", action="store_true", help="Apply missing migration steps.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    cwd = Path(__file__).resolve().parent.parent
    has_column = parse_count(
        run_mysql_query(args.env_file, cwd, COLUMN_EXISTS_SQL, args.timeout)
    ) > 0
    has_index = parse_count(
        run_mysql_query(args.env_file, cwd, INDEX_EXISTS_SQL, args.timeout)
    ) > 0
    steps = build_migration_steps(has_column=has_column, has_index=has_index)

    if not steps:
        print("device flag migration already applied")
        return 0

    mode = "APPLY" if args.apply else "DRY-RUN"
    for step in steps:
        print(f"[{mode}] {step.name}: {step.sql}")
        if args.apply:
            run_mysql_query(args.env_file, cwd, step.sql, args.timeout)

    if not args.apply:
        print("dry run only; pass --apply to execute")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
