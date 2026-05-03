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
        self.assertIn('chmod 600 "${CHECKSUM_PATH}"', source)

    def test_backup_script_uses_unique_temp_files_and_atomic_moves(self) -> None:
        source = BACKUP.read_text(encoding="utf-8")

        self.assertNotIn('TMP_PATH="${BACKUP_PATH}.tmp"', source)
        self.assertIn('TMP_BACKUP="$(mktemp "${OUTPUT_DIR%/}/.${FILENAME##*/}.XXXXXX")"', source)
        self.assertIn('TMP_SHA256="$(mktemp "${OUTPUT_DIR%/}/.${FILENAME##*/}.sha256.XXXXXX")"', source)
        self.assertIn('trap cleanup_tmp EXIT', source)
        self.assertIn('rm -f "${TMP_BACKUP}"', source)
        self.assertIn('rm -f "${TMP_SHA256}"', source)
        self.assertIn('mv -f -T "${TMP_BACKUP}" "${BACKUP_PATH}"', source)
        self.assertIn('mv -f -T "${TMP_SHA256}" "${CHECKSUM_PATH}"', source)
        self.assertIn('sha256sum "${BACKUP_PATH}" > "${TMP_SHA256}"', source)
        self.assertNotIn('> "${BACKUP_PATH}.sha256"', source)

    def test_backup_script_rejects_symlink_or_non_regular_outputs(self) -> None:
        source = BACKUP.read_text(encoding="utf-8")

        self.assertIn('[[ ! -L "${OUTPUT_DIR}" ]] || die "Backup output directory must not be a symlink: ${OUTPUT_DIR}"', source)
        self.assertIn('[[ ! -L "${BACKUP_PATH}" ]] || die "Backup path must not be a symlink: ${BACKUP_PATH}"', source)
        self.assertIn('[[ ! -e "${BACKUP_PATH}" || -f "${BACKUP_PATH}" ]] || die "Backup path exists and is not a regular file: ${BACKUP_PATH}"', source)
        self.assertIn('[[ ! -L "${CHECKSUM_PATH}" ]] || die "Checksum path must not be a symlink: ${CHECKSUM_PATH}"', source)
        self.assertIn('[[ ! -e "${CHECKSUM_PATH}" || -f "${CHECKSUM_PATH}" ]] || die "Checksum path exists and is not a regular file: ${CHECKSUM_PATH}"', source)

    def test_backup_script_rejects_filename_path_traversal(self) -> None:
        source = BACKUP.read_text(encoding="utf-8")

        self.assertIn("validate_backup_filename", source)
        self.assertIn('*/*|*\\\\*)', source)
        self.assertIn('die "--filename must be a file name, not a path: ${FILENAME}"', source)

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
