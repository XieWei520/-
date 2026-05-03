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

    def test_restore_script_does_not_source_compose_env(self) -> None:
        source = RESTORE.read_text(encoding="utf-8")

        self.assertNotIn("source .env", source)
        self.assertIn("read_env_value", source)
        self.assertIn('docker compose --env-file .env exec -T mysql sh -c', source)


if __name__ == "__main__":
    unittest.main()
