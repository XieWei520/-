#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKUP = ROOT / "scripts" / "backup_mysql.sh"
RESTORE = ROOT / "scripts" / "restore_mysql.sh"


class MysqlBackupRestoreScriptTests(unittest.TestCase):
    def test_backup_script_does_not_source_compose_env(self) -> None:
        source = BACKUP.read_text(encoding="utf-8")

        self.assertNotIn("source .env", source)
        self.assertIn("read_env_value", source)
        self.assertIn('docker compose --env-file .env exec -T mysql sh -c', source)

    def test_backup_script_uses_private_umask_directory_and_file_modes(self) -> None:
        source = BACKUP.read_text(encoding="utf-8")

        self.assertRegex(source, r"(?m)^umask 077$")
        self.assertIn('chmod 700 "${OUTPUT_DIR}"', source)
        self.assertIn('chmod 600 "${BACKUP_PATH}"', source)
        self.assertIn('chmod 600 "${BACKUP_PATH}.sha256"', source)

    def test_restore_script_does_not_source_compose_env(self) -> None:
        source = RESTORE.read_text(encoding="utf-8")

        self.assertNotIn("source .env", source)
        self.assertIn("read_env_value", source)
        self.assertIn('docker compose --env-file .env exec -T mysql sh -c', source)

    def test_restore_script_validates_and_quotes_mysql_database_identifier(self) -> None:
        source = RESTORE.read_text(encoding="utf-8")

        self.assertRegex(source, r"\[\[\s+\"\$\{MYSQL_DATABASE\}\"\s+=~\s+\^\[A-Za-z0-9_\]\+\$")
        self.assertIn("MYSQL_DATABASE_SQL_IDENTIFIER", source)
        self.assertIn(r"\`${MYSQL_DATABASE}\`", source)
        self.assertNotIn("DROP DATABASE IF EXISTS ${MYSQL_DATABASE};", source)
        self.assertNotIn("CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}", source)


if __name__ == "__main__":
    unittest.main()
