#!/usr/bin/env python3
"""
WuKongIM CLI Harness Validation Script

Validates the harness structure, installation, and basic functionality.

Usage:
    python validate_harness.py
"""

import sys
import os
from pathlib import Path

# Colors for output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def check(condition, message, critical=True):
    """Check a condition and print result."""
    if condition:
        print(f"{Colors.GREEN}[OK]{Colors.RESET} {message}")
        return True
    else:
        status = "CRITICAL" if critical else "WARNING"
        print(f"{Colors.RED}[FAIL]{Colors.RESET} {message} [{status}]")
        return not critical

def main():
    """Run validation checks."""
    print(f"\n{Colors.BOLD}{'=' * 60}{Colors.RESET}")
    print(f"{Colors.BOLD}WuKongIM CLI Harness - Validation{Colors.RESET}")
    print(f"{Colors.BOLD}{'=' * 60}{Colors.RESET}\n")
    
    harness_dir = Path(__file__).parent
    cli_dir = harness_dir / "cli_anything" / "wukongim"
    
    all_passed = True
    
    # 1. Check directory structure
    print(f"{Colors.BLUE}[1] Checking directory structure...{Colors.RESET}")
    all_passed &= check(cli_dir.exists(), "CLI directory exists")
    all_passed &= check((cli_dir / "wukongim_cli.py").exists(), "wukongim_cli.py exists")
    all_passed &= check((cli_dir / "__init__.py").exists(), "__init__.py exists")
    all_passed &= check((cli_dir / "__main__.py").exists(), "__main__.py exists")
    all_passed &= check((cli_dir / "README.md").exists(), "README.md exists")
    all_passed &= check((cli_dir / "utils").exists(), "utils/ directory exists")
    all_passed &= check((cli_dir / "core").exists(), "core/ directory exists")
    all_passed &= check((cli_dir / "tests").exists(), "tests/ directory exists")
    all_passed &= check((harness_dir / "setup.py").exists(), "setup.py exists")
    all_passed &= check((harness_dir / "TEST.md").exists(), "TEST.md exists")
    print()
    
    # 2. Check Python files are valid
    print(f"{Colors.BLUE}[2] Checking Python syntax...{Colors.RESET}")
    py_files = [
        cli_dir / "wukongim_cli.py",
        cli_dir / "__init__.py",
        cli_dir / "__main__.py",
        cli_dir / "utils" / "backend.py",
        cli_dir / "core" / "config.py",
    ]
    
    for py_file in py_files:
        if py_file.exists():
            try:
                compile(py_file.read_text(encoding='utf-8'), py_file, 'exec')
                print(f"{Colors.GREEN}[OK]{Colors.RESET} {py_file.name} - syntax OK")
            except SyntaxError as e:
                print(f"{Colors.RED}[FAIL]{Colors.RESET} {py_file.name} - syntax error: {e}")
                all_passed = False
            except UnicodeDecodeError as e:
                print(f"{Colors.YELLOW}[WARN]{Colors.RESET} {py_file.name} - encoding issue: {e}")
        else:
            print(f"{Colors.RED}[FAIL]{Colors.RESET} {py_file.name} - not found")
            all_passed = False
    print()
    
    # 3. Check dependencies
    print(f"{Colors.BLUE}[3] Checking dependencies...{Colors.RESET}")
    try:
        import requests
        print(f"{Colors.GREEN}[OK]{Colors.RESET} requests library installed")
    except ImportError:
        print(f"{Colors.RED}[FAIL]{Colors.RESET} requests library NOT installed")
        print(f"  Install with: pip install requests")
        all_passed = False
    
    try:
        import click
        print(f"{Colors.GREEN}[OK]{Colors.RESET} click library installed")
    except ImportError:
        print(f"{Colors.YELLOW}[WARN]{Colors.RESET} click library NOT installed (optional)")
    print()
    
    # 4. Check CLI functionality
    print(f"{Colors.BLUE}[4] Checking CLI functionality...{Colors.RESET}")
    import subprocess
    
    # Test --help
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.wukongim", "--help"],
        capture_output=True,
        text=True,
        cwd=str(harness_dir)
    )
    all_passed &= check(
        result.returncode == 0 and "wukongim" in result.stdout,
        "CLI --help works"
    )
    
    # Test auth --help
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.wukongim", "auth", "--help"],
        capture_output=True,
        text=True,
        cwd=str(harness_dir)
    )
    all_passed &= check(
        result.returncode == 0 and "login" in result.stdout,
        "auth subcommand works"
    )
    
    # Test message --help
    result = subprocess.run(
        [sys.executable, "-m", "cli_anything.wukongim", "message", "--help"],
        capture_output=True,
        text=True,
        cwd=str(harness_dir)
    )
    all_passed &= check(
        result.returncode == 0 and "send" in result.stdout,
        "message subcommand works"
    )
    print()
    
    # 5. Check documentation
    print(f"{Colors.BLUE}[5] Checking documentation...{Colors.RESET}")
    all_passed &= check((cli_dir / "README.md").exists(), "CLI README.md exists")
    all_passed &= check((harness_dir / "WUKONGIM.md").exists(), "WUKONGIM.md exists")
    all_passed &= check((harness_dir / "TEST.md").exists(), "TEST.md exists")
    
    # Check README has essential sections
    readme_path = cli_dir / "README.md"
    if readme_path.exists():
        try:
            readme_content = readme_path.read_text(encoding="utf-8")
            all_passed &= check("Installation" in readme_content, "README has Installation section")
            all_passed &= check("Usage" in readme_content or "Quick Start" in readme_content, "README has usage instructions")
            all_passed &= check("auth" in readme_content, "README documents auth commands")
            all_passed &= check("message" in readme_content, "README documents message commands")
        except UnicodeDecodeError:
            print(f"{Colors.YELLOW}[WARN]{Colors.RESET} Could not read README.md")
    print()
    
    # 6. Check package metadata
    print(f"{Colors.BLUE}[6] Checking package metadata...{Colors.RESET}")
    setup_path = harness_dir / "setup.py"
    if setup_path.exists():
        try:
            setup_content = setup_path.read_text(encoding="utf-8")
            all_passed &= check("cli-anything-wukongim" in setup_content, "Package name defined")
            all_passed &= check("console_scripts" in setup_content, "Console scripts defined")
            all_passed &= check("find_namespace_packages" in setup_content, "Namespace packages configured")
            all_passed &= check("requests" in setup_content, "Dependencies listed")
        except UnicodeDecodeError:
            print(f"{Colors.YELLOW}[WARN]{Colors.RESET} Could not read setup.py")
    print()
    
    # Summary
    print(f"{Colors.BOLD}{'=' * 60}{Colors.RESET}")
    if all_passed:
        print(f"{Colors.GREEN}[PASS] All validation checks passed!{Colors.RESET}")
        print(f"\n{Colors.BLUE}Next steps:{Colors.RESET}")
        print(f"  1. Install the package: pip install -e .")
        print(f"  2. Login: wukongim auth login -u <username> -p <password>")
        print(f"  3. Run tests: python cli_anything/wukongim/test_cli.py")
    else:
        print(f"{Colors.RED}[FAIL] Some validation checks failed.{Colors.RESET}")
        print(f"\nPlease review the errors above and fix them.")
    print(f"{Colors.BOLD}{'=' * 60}{Colors.RESET}\n")
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
