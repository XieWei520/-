# WuKongIM CLI Harness - Directory Structure

```
agent-harness/
│
├── 📄 setup.py                       # Package installation (pip install -e .)
├── 📄 .gitignore                     # Git ignore rules
├── 📄 HARNESS_SUMMARY.md             # Build summary (this report)
├── 📄 QUICKSTART.md                  # Quick start guide
├── 📄 TEST.md                        # Test strategy
├── 📄 validate_harness.py            # Validation script
├── 📄 WUKONGIM.md                    # Project analysis
│
├── 📁 cli_anything/                  # Namespace package
│   ├── 📄 __init__.py                # Package marker
│   │
│   └── 📁 wukongim/                  # WuKongIM CLI package
│       ├── 📄 __init__.py            # Package init (exports main classes)
│       ├── 📄 __main__.py            # Module entry point (python -m)
│       ├── 📄 wukongim_cli.py        # ⭐ Main CLI script (28KB)
│       ├── 📄 wukongim.bat           # Windows batch launcher
│       ├── 📄 wukongim.ps1           # PowerShell launcher
│       ├── 📄 README.md              # Usage documentation
│       ├── 📄 test_cli.py            # Integration/smoke tests
│       │
│       ├── 📁 core/                  # Core modules
│       │   ├── 📄 __init__.py
│       │   └── 📄 config.py          # Configuration management
│       │
│       ├── 📁 utils/                 # Utility modules
│       │   ├── 📄 __init__.py
│       │   └── 📄 backend.py         # ⭐ Backend API wrapper (10KB)
│       │
│       └── 📁 tests/                 # Test suite
│           ├── 📄 __init__.py
│           └── 📄 test_backend.py    # Unit tests
│
└── 📁 __pycache__/                   # Python cache (auto-generated)
└── 📁 cli_anything_wukongim.egg-info/ # Package info (auto-generated)
```

## Key Files

### Entry Points

| File | Purpose | Usage |
|------|---------|-------|
| `wukongim_cli.py` | Main CLI implementation | Direct execution |
| `__main__.py` | Module entry point | `python -m cli_anything.wukongim` |
| `wukongim.bat` | Windows launcher | Double-click or CMD |
| `wukongim.ps1` | PowerShell launcher | PowerShell |
| Console scripts | Installed commands | `wukongim`, `cli-anything-wukongim` |

### Core Components

| File | Size | Purpose |
|------|------|---------|
| `wukongim_cli.py` | 28KB | Complete CLI with all commands |
| `backend.py` | 10KB | API wrapper for Flutter backend |
| `config.py` | 3KB | Configuration management |
| `test_cli.py` | 7KB | Integration test suite |
| `test_backend.py` | 4KB | Unit tests |

### Documentation

| File | Purpose |
|------|---------|
| `README.md` | CLI usage and installation |
| `QUICKSTART.md` | Quick start guide |
| `TEST.md` | Test strategy and coverage |
| `WUKONGIM.md` | Project analysis |
| `HARNESS_SUMMARY.md` | Build summary |
| `STRUCTURE.md` | This file |

## Package Installation

After running `pip install -e .`:

1. Console scripts are created:
   - `wukongim` → Points to `wukongim_cli.main()`
   - `cli-anything-wukongim` → Points to `wukongim_cli.main()`

2. Package is importable:
   ```python
   from cli_anything.wukongim import WuKongIMClient, SessionManager
   from cli_anything.wukongim.utils import WuKongIMBackend
   from cli_anything.wukongim.core import Config
   ```

3. Module can be run:
   ```bash
   python -m cli_anything.wukongim --help
   ```

## Session Storage

```
~/.wukongim/
├── session.json          # User session (token, UID, etc.)
└── config.json           # Configuration (optional)
```

Windows: `C:\Users\<username>\.wukongim\`

## Dependencies

**Required:**
- `requests>=2.28.0` - HTTP client
- `click>=8.0.0` - CLI framework (optional, for future enhancements)

**Development:**
- `pytest>=7.0.0` - Testing framework
- `pytest-cov>=3.0.0` - Coverage reporting

## Import Hierarchy

```
cli_anything (namespace)
└── wukongim (package)
    ├── wukongim_cli (module)
    │   ├── WuKongIMClient (class)
    │   ├── SessionManager (class)
    │   └── main (function)
    ├── utils (package)
    │   └── backend (module)
    │       ├── WuKongIMBackend (class)
    │       └── APIError (exception)
    └── core (package)
        └── config (module)
            ├── Config (class)
            └── get_config (function)
```

## Command Flow

```
User Input
    ↓
Console Script (wukongim)
    ↓
wukongim_cli.main()
    ↓
Argument Parser
    ↓
Command Function (e.g., cmd_login)
    ↓
WuKongIMClient
    ↓
WuKongIMBackend
    ↓
HTTP Request (requests)
    ↓
WuKongIM API
    ↓
Response → Output
```

## Test Flow

```
validate_harness.py
    ↓
[1] Check directory structure
[2] Check Python syntax
[3] Check dependencies
[4] Check CLI functionality
[5] Check documentation
[6] Check package metadata
    ↓
PASS/FAIL report

test_cli.py
    ↓
Login → Get User → List Data → Logout
    ↓
Test summary

test_backend.py (pytest)
    ↓
Unit tests for backend classes
    ↓
Coverage report
```

---

**Total Files**: 20+  
**Total Code**: ~45KB  
**Documentation**: ~25KB  
**Tests**: 2 suites
