#!/usr/bin/env python3
from __future__ import annotations

import tempfile
import types
import unittest
from pathlib import Path

import render_config


class RenderConfigSecurityTests(unittest.TestCase):
    def test_render_templates_sets_private_modes_on_output_dirs_and_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            template_dir = temp_path / "templates"
            out_dir = temp_path / "rendered"
            template_file = template_dir / "nested" / "secret.conf.tpl"
            template_file.parent.mkdir(parents=True)
            template_file.write_text("password={{MYSQL_PASSWORD}}\n", encoding="utf-8")

            chmod_calls: list[tuple[Path, int]] = []

            def record_chmod(path: str | Path, mode: int) -> None:
                chmod_calls.append((Path(path), mode))

            patched_os = types.SimpleNamespace(chmod=record_chmod)
            original_os = getattr(render_config, "os", None)
            render_config.os = patched_os  # type: ignore[attr-defined]
            try:
                render_config.render_templates(
                    template_dir=template_dir,
                    out_dir=out_dir,
                    env={"MYSQL_PASSWORD": "runtime-secret"},
                )
            finally:
                if original_os is None:
                    delattr(render_config, "os")
                else:
                    render_config.os = original_os  # type: ignore[attr-defined]

            output_file = out_dir / "nested" / "secret.conf"
            self.assertTrue(output_file.is_file())
            self.assertIn((out_dir, 0o700), chmod_calls)
            self.assertIn((out_dir / "nested", 0o700), chmod_calls)
            self.assertIn((output_file, 0o600), chmod_calls)


if __name__ == "__main__":
    unittest.main()
