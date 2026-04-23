# WuKongIM CLI - Test Strategy

## Overview

This document describes the testing approach for the WuKongIM CLI harness.

## Test Structure

```
cli_anything/wukongim/
├── tests/
│   ├── __init__.py
│   ├── test_backend.py      # Unit tests for backend wrapper
│   └── test_cli.py          # Integration/smoke tests
└── test_cli.py              # Legacy smoke test (kept for compatibility)
```

## Test Types

### 1. Unit Tests (`tests/test_backend.py`)

**Purpose**: Test individual components in isolation.

**Coverage**:
- `WuKongIMBackend` class initialization
- Token management (set/clear)
- Configuration loading
- Error handling

**Run**:
```bash
cd agent-harness
pytest cli_anything/wukongim/tests/test_backend.py -v
```

### 2. Integration/Smoke Tests (`test_cli.py`)

**Purpose**: Test the CLI as a whole with real API calls.

**Coverage**:
- Login/logout flow
- User info retrieval
- Conversation listing
- Friend/group operations
- JSON output format

**Requirements**:
- Valid test credentials
- Network access to API server

**Run**:
```bash
# With command line args
python cli_anything/wukongim/test_cli.py --username testuser --password testpass

# With environment variables
export WK_TEST_USERNAME=testuser
export WK_TEST_PASSWORD=testpass
python cli_anything/wukongim/test_cli.py
```

## Test Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `WK_TEST_USERNAME` | Test account username | `testuser` |
| `WK_TEST_PASSWORD` | Test account password | `secret123` |
| `WK_API_URL` | API base URL (optional) | `http://42.194.218.158` |

### Test Account

Tests require a valid WuKongIM account. You can:

1. Use an existing account
2. Register a new test account via the CLI:
   ```bash
   python -m cli_anything.wukongim auth register -u testuser -p secret123
   ```

## Running Tests

### Full Test Suite

```bash
cd C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\agent-harness

# Install dev dependencies
pip install -e .[dev]

# Run all tests
pytest cli_anything/wukongim/tests/ -v --cov=cli_anything.wukongim

# Run with smoke tests
python cli_anything/wukongim/test_cli.py --username $WK_TEST_USERNAME --password $WK_TEST_PASSWORD
```

### Individual Test Files

```bash
# Backend unit tests only
pytest cli_anything/wukongim/tests/test_backend.py -v

# With coverage
pytest cli_anything/wukongim/tests/ --cov=cli_anything.wukongim --cov-report=html
```

## Test Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| Backend wrapper | 80% | TBD |
| CLI commands | 70% | TBD |
| Session management | 90% | TBD |
| Configuration | 85% | TBD |

## Continuous Integration

Tests should be run:
- Before each commit (pre-commit hook)
- On CI/CD pipeline
- After dependency updates

## Known Limitations

1. **WebSocket tests**: Not implemented (requires persistent connection testing)
2. **File upload tests**: Require test files and more bandwidth
3. **Rate limiting**: Tests may fail if API rate limits are hit

## Future Test Additions

- [ ] WebSocket message testing
- [ ] Mock server for offline testing
- [ ] Performance benchmarks
- [ ] End-to-end workflow tests
- [ ] Cross-platform compatibility tests

## Troubleshooting

### "Connection error"
- Check API server is reachable
- Verify network connectivity
- Check firewall settings

### "Authentication failed"
- Verify test credentials are correct
- Check if account exists
- Try manual login via CLI

### Tests timing out
- Increase timeout in test configuration
- Check network latency
- Consider using local API server
