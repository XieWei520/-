#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from unittest import mock

import render_config


class RenderConfigSecurityTests(unittest.TestCase):
    def test_render_templates_uses_private_umask_temp_file_and_atomic_replace(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            template_dir = temp_path / "templates"
            out_dir = temp_path / "rendered"
            template_file = template_dir / "nested" / "secret.conf.tpl"
            template_file.parent.mkdir(parents=True)
            template_file.write_text("password={{MYSQL_PASSWORD}}\n", encoding="utf-8")

            chmod_calls: list[tuple[Path, int]] = []
            replace_calls: list[tuple[Path, Path]] = []
            umask_calls: list[int] = []

            original_chmod = render_config.os.chmod
            original_replace = render_config.os.replace

            def record_umask(mode: int) -> int:
                umask_calls.append(mode)
                return 0o022

            def record_chmod(path: str | Path, mode: int) -> None:
                chmod_calls.append((Path(path), mode))
                original_chmod(path, mode)

            def record_replace(src: str | Path, dst: str | Path) -> None:
                source = Path(src)
                destination = Path(dst)
                replace_calls.append((source, destination))
                self.assertEqual(destination.parent, source.parent)
                original_replace(src, dst)

            with (
                mock.patch.object(render_config.os, "umask", side_effect=record_umask),
                mock.patch.object(render_config.os, "chmod", side_effect=record_chmod),
                mock.patch.object(render_config.os, "replace", side_effect=record_replace),
            ):
                render_config.render_templates(
                    template_dir=template_dir,
                    out_dir=out_dir,
                    env={"MYSQL_PASSWORD": "runtime-secret"},
                )

            output_file = out_dir / "nested" / "secret.conf"
            self.assertTrue(output_file.is_file())
            self.assertEqual("password=runtime-secret\n", output_file.read_text(encoding="utf-8"))
            self.assertEqual([0o077, 0o022], umask_calls)
            self.assertEqual(1, len(replace_calls))
            temp_file, final_file = replace_calls[0]
            self.assertEqual(output_file, final_file)
            self.assertEqual(output_file.parent, temp_file.parent)
            self.assertFalse(temp_file.exists())
            self.assertIn((out_dir, 0o700), chmod_calls)
            self.assertIn((out_dir / "nested", 0o700), chmod_calls)
            self.assertIn((output_file, 0o600), chmod_calls)

    def test_render_templates_rejects_symlink_output_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            template_dir = temp_path / "templates"
            template_dir.mkdir()
            (template_dir / "secret.conf.tpl").write_text("password={{MYSQL_PASSWORD}}\n", encoding="utf-8")
            target_dir = temp_path / "actual-rendered"
            target_dir.mkdir()
            symlink_out_dir = temp_path / "rendered-link"
            try:
                symlink_out_dir.symlink_to(target_dir, target_is_directory=True)
            except (NotImplementedError, OSError) as exc:
                self.skipTest(f"Symlink creation is unavailable: {exc}")

            with self.assertRaisesRegex(ValueError, "symlink"):
                render_config.render_templates(
                    template_dir=template_dir,
                    out_dir=symlink_out_dir,
                    env={"MYSQL_PASSWORD": "runtime-secret"},
                )

            self.assertFalse((target_dir / "secret.conf").exists())


if __name__ == "__main__":
    unittest.main()
