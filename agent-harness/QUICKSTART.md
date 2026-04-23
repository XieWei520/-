# WuKongIM CLI - Quick Start Guide

## Installation

### Option 1: Install as Python Package (Recommended)

```bash
cd C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\agent-harness
pip install -e .
```

This installs the CLI globally, making `wukongim` and `cli-anything-wukongim` commands available from anywhere.

### Option 2: Run Directly

```bash
# From the agent-harness directory
python -m cli_anything.wukongim [command]

# Or directly
python cli_anything/wukongim/wukongim_cli.py [command]
```

## Basic Usage

### 1. Login

```bash
wukongim auth login -u your_username -p your_password
```

### 2. Check Your Profile

```bash
wukongim auth me
```

### 3. List Conversations

```bash
wukongim conversations --limit 10
```

### 4. Send a Message

```bash
# To a user
wukongim message send -t friend_uid "Hello!"

# To a group
wukongim message send -g -t group_id "Group message"
```

### 5. List Friends

```bash
wukongim friend list
```

### 6. List Groups

```bash
wukongim group list
```

### 7. Upload a File

```bash
wukongim upload path/to/file.pdf
```

### 8. Logout

```bash
wukongim auth logout
```

## Command Reference

### Authentication

| Command | Description |
|---------|-------------|
| `auth login -u <user> -p <pass>` | Login with username/password |
| `auth logout` | Logout and clear session |
| `auth register -u <user> -p <pass>` | Register new account |
| `auth me` | Get current user info |
| `auth update-profile --name <name>` | Update profile |

### Messages

| Command | Description |
|---------|-------------|
| `message send -t <uid> "text"` | Send message to user |
| `message send -g -t <gid> "text"` | Send message to group |
| `message sync --channel-id <id>` | Sync messages for channel |
| `message search -k "keyword"` | Search messages |
| `message revoke --message-id <id> --channel-id <id>` | Revoke message |

### Friends

| Command | Description |
|---------|-------------|
| `friend list` | List all friends |
| `friend add --friend-uid <uid>` | Add friend |
| `friend remove --friend-uid <uid>` | Remove friend |

### Groups

| Command | Description |
|---------|-------------|
| `group list` | List my groups |
| `group create -n "name" -m "uid1,uid2"` | Create group |
| `group info --group-id <id>` | Get group info |

### Other

| Command | Description |
|---------|-------------|
| `conversations --limit 20` | List conversations |
| `upload <file>` | Upload file |

## Options

- `--json` - Output in JSON format (useful for scripting)

Example:
```bash
wukongim auth me --json | python -m json.tool
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WK_API_URL` | API base URL | `http://42.194.218.158` |
| `WK_APP_ID` | App ID | `wukongchat` |
| `WK_APP_KEY` | App Key | `25b002c6be2d539f264c` |
| `WK_TEST_USERNAME` | Test username for tests | - |
| `WK_TEST_PASSWORD` | Test password for tests | - |

## Examples

### Complete Workflow

```bash
# 1. Login
wukongim auth login -u john_doe -p secret123

# 2. Check profile
wukongim auth me

# 3. View conversations
wukongim conversations --limit 10

# 4. Send a message
wukongim message send -t abc123 "Hey, how are you?"

# 5. Create a group
wukongim group create -n "Project Team" -m "uid1,uid2,uid3"

# 6. Send to group
wukongim message send -g -t grp456 "Meeting at 3pm"

# 7. Upload a document
wukongim upload ./meeting_notes.pdf

# 8. Logout when done
wukongim auth logout
```

### Scripting with JSON

```bash
# Get user UID
wukongim auth me --json | python -c "import sys,json; print(json.load(sys.stdin)['uid'])"

# Count friends
wukongim friend list --json | python -c "import sys,json; print(len(json.load(sys.stdin)))"

# Search messages
wukongim message search -k "project" --json
```

## Troubleshooting

### "Not logged in" error
Run `wukongim auth login` first to authenticate.

### "Connection error"
- Check that the API server is reachable at `http://42.194.218.158`
- Verify your network connection
- Check firewall settings

### Session expires
Sessions may expire after extended periods. Simply re-login:
```bash
wukongim auth login -u your_username -p your_password
```

### Command not found (after installation)
Make sure the Python Scripts directory is in your PATH:
- Windows: `%APPDATA%\Python\Python3x\Scripts`
- Or reinstall with: `pip install --user -e .`

## Testing

Run the test suite:

```bash
# With credentials
wukongim auth login -u testuser -p testpass
python cli_anything/wukongim/test_cli.py

# Or with environment variables
set WK_TEST_USERNAME=testuser
set WK_TEST_PASSWORD=testpass
python cli_anything/wukongim/test_cli.py
```

## Getting Help

```bash
# General help
wukongim --help

# Command-specific help
wukongim auth --help
wukongim message --help
wukongim message send --help
```

## Session Storage

Session data is stored in `~/.wukongim/session.json`:
- Windows: `C:\Users\<username>\.wukongim\session.json`
- Linux/Mac: `~/.wukongim/session.json`

This includes your user ID, authentication token, and login timestamp.

## Next Steps

- Read the full documentation: `cli_anything/wukongim/README.md`
- Review test strategy: `TEST.md`
- Check project analysis: `WUKONGIM.md`
