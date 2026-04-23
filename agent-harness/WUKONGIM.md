# WuKongIM - Project Analysis

## CLI Harness

A Python-based CLI harness is available at `agent-harness/cli_anything/wukongim/`.

### Package Structure

```
agent-harness/
├── setup.py                      # Package installation
├── .gitignore                    # Git ignore rules
├── TEST.md                       # Test strategy documentation
├── validate_harness.py           # Harness validation script
└── cli_anything/wukongim/
    ├── __init__.py               # Package init
    ├── __main__.py               # Module entry point
    ├── wukongim_cli.py           # Main CLI script
    ├── wukongim.bat              # Windows launcher
    ├── wukongim.ps1              # PowerShell launcher
    ├── README.md                 # Usage documentation
    ├── test_cli.py               # Smoke test suite
    ├── core/
    │   ├── __init__.py
    │   └── config.py             # Configuration management
    ├── utils/
    │   ├── __init__.py
    │   └── backend.py            # Backend API wrapper
    └── tests/
        ├── __init__.py
        └── test_backend.py       # Unit tests
```

### Quick Start

```bash
# Install dependencies
pip install requests

# Login
python wukongim_cli.py auth login -u username -p password

# Check user info
python wukongim_cli.py auth me

# Send message
python wukongim_cli.py message send -t uid "Hello!"

# List conversations
python wukongim_cli.py conversations

# Logout
python wukongim_cli.py auth logout
```

### Session Management

Sessions are stored in `~/.wukongim/session.json`. The CLI automatically:
- Saves authentication tokens after login
- Includes auth headers in subsequent requests
- Clears session on logout

### Available Commands

**Authentication:**
- `auth login` - Login with username/password
- `auth logout` - Logout
- `auth register` - Register new account
- `auth me` - Get current user info
- `auth update-profile` - Update profile

**Conversations:**
- `conversations` - List conversations

**Messages:**
- `message send` - Send text message
- `message sync` - Sync message history
- `message search` - Search messages
- `message revoke` - Delete/revoke message

**Friends:**
- `friend list` - List friends
- `friend add` - Add friend
- `friend remove` - Remove friend

**Groups:**
- `group list` - List groups
- `group create` - Create group
- `group info` - Get group info

**Files:**
- `upload` - Upload file

### Testing

```bash
# Run smoke tests
python test_cli.py --username testuser --password testpass

# Or with environment variables
export WK_TEST_USERNAME=testuser
export WK_TEST_PASSWORD=testpass
python test_cli.py
```

---

## Backend Engine

**Primary Backend**: WuKongIM Server (Go-based distributed IM system)
- REST API: `http://42.194.218.158/v1/*`
- WebSocket: `42.194.218.158:5100`
- Authentication: Token-based (JWT-style)

**Secondary Backend**: TangSengDaoDao Server (Go-based)
- Used for extended features

## GUI Actions to API Mappings

| GUI Action | API Endpoint | Method |
|------------|--------------|--------|
| Login | `/v1/user/login` | POST |
| Username Login | `/v1/user/usernamelogin` | POST |
| Register | `/v1/user/register` | POST |
| Get User Info | `/v1/users/{uid}` | GET |
| Sync Friends | `/v1/friend/sync` | GET |
| Add Friend | `/v1/friend/apply` | POST |
| Create Group | `/v1/group/create` | POST |
| Get My Groups | `/v1/group/my` | GET |
| Sync Messages | `/v1/message/sync` | POST |
| Send Message | WebSocket | WS |
| Revoke Message | `/v1/message/revoke` | POST |
| Delete Message | `/v1/message` | DELETE |
| Search Messages | `/v1/message/search` | POST |
| Get Conversations | `/v1/conversations` | GET |
| Upload File | `/v1/file/upload` | POST |

## Data Model

### File Formats
- **Local Storage**: SQLite (sqflite), Hive, SharedPreferences
- **Message Format**: JSON
- **Session State**: JSON session files

### Key Data Structures

**User (UserInfo)**:
```json
{
  "uid": "string",
  "name": "string",
  "avatar": "string",
  "phone": "string",
  "sex": "number",
  "token": "string",
  "username": "string"
}
```

**Message (WKMessage)**:
```json
{
  "message_id": "string",
  "channel_id": "string",
  "channel_type": "number",
  "from_uid": "string",
  "content": "string",
  "created_at": "number"
}
```

**Channel Types**:
- `1`: Personal chat (uid)
- `2`: Group chat

## Existing CLI Tools

None - This is a GUI-only Flutter application. The CLI harness will be the first command-line interface.

## Command/Undo System

The app does not have a formal command pattern. State management uses Riverpod.

## CLI Architecture Recommendation

**Interaction Model**: Stateful REPL + Subcommand CLI

**Command Groups**:
1. **auth** - Login, logout, register, session management
2. **user** - User info, profile management
3. **conversation** - List, create, delete conversations
4. **message** - Send, receive, search, delete messages
5. **friend** - Add, remove, list friends
6. **group** - Create, manage groups
7. **file** - Upload, download files

**State Model**:
- Session token stored in JSON file
- Current user context persisted
- Message history cached locally

**Output Format**:
- Human-readable tables for interactive use
- JSON output with `--json` flag
