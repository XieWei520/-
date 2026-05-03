#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

PLACEHOLDER_PATTERN = re.compile(r"{{\s*([A-Za-z_][A-Za-z0-9_]*)\s*}}")
ROOT_DIR = Path(__file__).resolve().parent.parent
DEFAULT_ENV_FILE = ROOT_DIR / ".env"
DEFAULT_TEMPLATE_DIR = ROOT_DIR / "config"
DEFAULT_OUT_DIR = ROOT_DIR / "rendered"
PRIVATE_DIR_MODE = 0o700
PRIVATE_FILE_MODE = 0o600


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render .tpl config files with env values.")
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Path to .env file.")
    parser.add_argument("--template-dir", default=str(DEFAULT_TEMPLATE_DIR), help="Directory containing *.tpl files.")
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT_DIR), help="Directory to write rendered files.")
    return parser.parse_args()


def load_env(env_file: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip()
    return env


def render_template(content: str, env: dict[str, str]) -> str:
    rendered = content
    for key, value in env.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
    return rendered


def find_unresolved_placeholders(content: str) -> list[str]:
    return sorted(set(PLACEHOLDER_PATTERN.findall(content)))


def ensure_private_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    os.chmod(path, PRIVATE_DIR_MODE)


def ensure_private_output_parent(out_dir: Path, output_parent: Path) -> None:
    ensure_private_dir(out_dir)
    try:
        relative_parent = output_parent.relative_to(out_dir)
    except ValueError:
        ensure_private_dir(output_parent)
        return

    current = out_dir
    for part in relative_parent.parts:
        current = current / part
        ensure_private_dir(current)


def render_templates(template_dir: Path, out_dir: Path, env: dict[str, str]) -> None:
    rendered_outputs: list[tuple[Path, str]] = []
    unresolved: list[tuple[str, list[str]]] = []
    template_files = sorted(template_dir.rglob("*.tpl"))

    if not template_files:
        raise ValueError(f"No template files found under: {template_dir}")

    for tpl_file in template_files:
        relative = tpl_file.relative_to(template_dir)
        output_relative = Path(str(relative)[:-4])
        output_file = out_dir / output_relative
        template_content = tpl_file.read_text(encoding="utf-8")
        rendered_content = render_template(template_content, env)
        remaining_placeholders = find_unresolved_placeholders(rendered_content)
        if remaining_placeholders:
            unresolved.append((relative.as_posix(), remaining_placeholders))
            continue
        rendered_outputs.append((output_file, rendered_content))

    if unresolved:
        issues = "\n".join(
            f"- {rel}: {', '.join(tokens)}" for rel, tokens in unresolved
        )
        raise ValueError(f"Unresolved placeholders found after rendering:\n{issues}")

    ensure_private_dir(out_dir)
    for output_file, rendered_content in rendered_outputs:
        ensure_private_output_parent(out_dir, output_file.parent)
        output_file.touch(mode=PRIVATE_FILE_MODE, exist_ok=True)
        os.chmod(output_file, PRIVATE_FILE_MODE)
        output_file.write_text(rendered_content, encoding="utf-8")
        os.chmod(output_file, PRIVATE_FILE_MODE)
        print(f"Rendered: {output_file}")


def main() -> None:
    try:
        args = parse_args()
        env_file = Path(args.env_file)
        template_dir = Path(args.template_dir)
        out_dir = Path(args.out_dir)

        env = load_env(env_file)
        render_templates(template_dir, out_dir, env)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
