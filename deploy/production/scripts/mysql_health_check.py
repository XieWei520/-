#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path


DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
DEFAULT_REQUIRED_INDEXES = (
    ("favorite", "favorite_uid_client_msg_no_uidx", ("uid", "client_msg_no")),
    ("favorite", "favorite_uid_created_at_idx", ("uid", "created_at")),
    ("moment", "moment_uid_status_created_at_idx", ("uid", "status", "created_at")),
    ("moment_comment", "moment_comment_moment_status_created_at_idx", ("moment_id", "status", "created_at")),
    ("reaction_users", "reaction_users_channel_seq_idx", ("channel_id", "channel_type", "seq")),
    ("device", "device_uid_flag_last_login_idx", ("uid", "device_flag", "last_login")),
    ("user_global_setting", "user_global_setting_uid_uidx", ("uid",)),
    ("call_room", "call_room_callee_status_created_at_idx", ("callee_uid", "status", "created_at")),
    ("call_signal", "call_signal_room_id_created_at_idx", ("room_id", "created_at")),
)
DEFAULT_REQUIRED_COLUMNS = (
    ("device", "device_flag"),
)


@dataclass(frozen=True)
class RequiredIndex:
    table: str
    index: str
    columns: tuple[str, ...]


@dataclass(frozen=True)
class RequiredColumn:
    table: str
    column: str


@dataclass(frozen=True)
class CheckResult:
    name: str
    ok: bool
    detail: str


def parse_variable_rows(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or "\t" not in line or line.lower().startswith("mysql:"):
            continue
        key, value = line.split("\t", 1)
        values[key.strip()] = value.strip()
    return values


def evaluate_slow_query_variables(
    variables: dict[str, str],
    max_long_query_time: float,
) -> CheckResult:
    issues: list[str] = []
    slow_query_log = variables.get("slow_query_log", "").upper()
    if slow_query_log != "ON":
        issues.append(f"slow_query_log={slow_query_log or 'missing'}")

    raw_long_query_time = variables.get("long_query_time", "")
    try:
        long_query_time = float(raw_long_query_time)
    except ValueError:
        issues.append(f"long_query_time={raw_long_query_time or 'missing'}")
    else:
        if long_query_time > max_long_query_time:
            issues.append(f"long_query_time={long_query_time} > {max_long_query_time}")

    if issues:
        return CheckResult("mysql slow query config", False, "; ".join(issues))
    return CheckResult(
        "mysql slow query config",
        True,
        f"slow_query_log=ON; long_query_time={float(raw_long_query_time)}",
    )


def parse_index_rows(text: str) -> dict[tuple[str, str], tuple[str, ...]]:
    indexes: dict[tuple[str, str], tuple[str, ...]] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or "\t" not in line or line.lower().startswith("mysql:"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        table_name, index_name, columns = parts[0].strip(), parts[1].strip(), parts[2].strip()
        indexes[(table_name, index_name)] = tuple(
            column.strip() for column in columns.split(",") if column.strip()
        )
    return indexes


def parse_column_rows(text: str) -> set[tuple[str, str]]:
    columns: set[tuple[str, str]] = set()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or "\t" not in line or line.lower().startswith("mysql:"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        columns.add((parts[0].strip(), parts[1].strip()))
    return columns


def evaluate_required_columns(
    columns: set[tuple[str, str]],
    required: tuple[RequiredColumn, ...],
) -> CheckResult:
    issues = [
        f"{item.table}.{item.column} missing"
        for item in required
        if (item.table, item.column) not in columns
    ]
    if issues:
        return CheckResult("mysql required columns", False, "; ".join(issues))
    return CheckResult(
        "mysql required columns",
        True,
        f"{len(required)}/{len(required)} required columns present",
    )


def evaluate_required_indexes(
    indexes: dict[tuple[str, str], tuple[str, ...]],
    required: tuple[RequiredIndex, ...],
) -> CheckResult:
    issues: list[str] = []
    for item in required:
        actual = indexes.get((item.table, item.index))
        if actual is None:
            issues.append(f"{item.table}.{item.index} missing")
            continue
        if actual != item.columns:
            issues.append(
                f"{item.table}.{item.index} columns={','.join(actual)} expected={','.join(item.columns)}"
            )

    if issues:
        return CheckResult("mysql required indexes", False, "; ".join(issues))
    return CheckResult(
        "mysql required indexes",
        True,
        f"{len(required)}/{len(required)} required indexes present",
    )


def render_result(result: CheckResult) -> str:
    verdict = "PASS" if result.ok else "FAIL"
    return f"[{verdict}] {result.name:<25} {result.detail}"


def _quote_sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build_index_query(required: tuple[RequiredIndex, ...]) -> str:
    names = sorted({item.index for item in required})
    quoted_names = ",".join(_quote_sql_string(name) for name in names)
    return (
        "SELECT TABLE_NAME, INDEX_NAME, "
        "GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',') AS columns "
        "FROM information_schema.STATISTICS "
        "WHERE TABLE_SCHEMA = DATABASE() "
        f"AND INDEX_NAME IN ({quoted_names}) "
        "GROUP BY TABLE_NAME, INDEX_NAME "
        "ORDER BY TABLE_NAME, INDEX_NAME"
    )


def build_column_query(required: tuple[RequiredColumn, ...]) -> str:
    clauses = " OR ".join(
        f"(TABLE_NAME={_quote_sql_string(item.table)} AND COLUMN_NAME={_quote_sql_string(item.column)})"
        for item in required
    )
    return (
        "SELECT TABLE_NAME, COLUMN_NAME "
        "FROM information_schema.COLUMNS "
        "WHERE TABLE_SCHEMA = DATABASE() "
        f"AND ({clauses}) "
        "ORDER BY TABLE_NAME, COLUMN_NAME"
    )


def run_mysql_query(env_file: Path, cwd: Path, sql: str, timeout: float) -> str:
    command = f'mysql -N -B -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -e {shlex.quote(sql)}'
    proc = subprocess.run(
        [
            "docker",
            "compose",
            "--env-file",
            str(env_file),
            "exec",
            "-T",
            "mysql",
            "sh",
            "-lc",
            command,
        ],
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stdout.strip() or "mysql query failed")
    return proc.stdout


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check MySQL slow-query settings and required production indexes."
    )
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE, help="Path to .env file.")
    parser.add_argument(
        "--max-long-query-time",
        type=float,
        default=0.5,
        help="Maximum allowed MySQL long_query_time in seconds.",
    )
    parser.add_argument("--timeout", type=float, default=20.0, help="Per docker/mysql command timeout.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    cwd = Path(__file__).resolve().parent.parent
    required = tuple(
        RequiredIndex(table=table, index=index, columns=columns)
        for table, index, columns in DEFAULT_REQUIRED_INDEXES
    )
    required_columns = tuple(
        RequiredColumn(table=table, column=column)
        for table, column in DEFAULT_REQUIRED_COLUMNS
    )

    try:
        variable_rows = run_mysql_query(
            args.env_file,
            cwd,
            "SHOW VARIABLES WHERE Variable_name IN ('slow_query_log','long_query_time')",
            args.timeout,
        )
        column_rows = run_mysql_query(
            args.env_file,
            cwd,
            build_column_query(required_columns),
            args.timeout,
        )
        index_rows = run_mysql_query(
            args.env_file,
            cwd,
            build_index_query(required),
            args.timeout,
        )
        results = [
            evaluate_slow_query_variables(
                parse_variable_rows(variable_rows),
                max_long_query_time=args.max_long_query_time,
            ),
            evaluate_required_columns(parse_column_rows(column_rows), required_columns),
            evaluate_required_indexes(parse_index_rows(index_rows), required),
        ]
    except Exception as exc:
        results = [CheckResult("mysql health query", False, str(exc))]

    for result in results:
        print(render_result(result))

    failures = [result for result in results if not result.ok]
    if failures:
        print(f"mysql health check failed: {len(failures)}/{len(results)} checks unhealthy")
        return 1

    print(f"mysql health check passed: {len(results)}/{len(results)} checks healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
