# WuKongIM CLI Harness

Command-line interface for WuKongIM messaging platform.

## Quick Start

### Installation

#### Option 1: Install as Package (Recommended)

```bash
cd C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\agent-harness

# Install in editable mode
pip install -e .

# Now you can use the CLI from anywhere
wukongim --help
# or
cli-anything-wukongim --help
```

#### Option 2: Direct Script Execution

```bash
# Install dependencies
pip install requests click

# Run directly
python -m cli_anything.wukongim --help
# or
python cli_anything/wukongim/wukongim_cli.py --help
```

#### Option 3: PowerShell Alias (Windows)

Add to your PowerShell profile (`$PROFILE`):

```powershell
Set-Alias wukongim "python -m cli_anything.wukongim"
```

Then reload your profile:

```powershell
. $PROFILE
```

### Basic Usage

```bash
# Login
python wukongim_cli.py auth login -u your_username -p your_password

# Check current user
python wukongim_cli.py auth me

# List conversations
python wukongim_cli.py conversations

# Send a message
python wukongim_cli.py message send -t friend_uid "Hello!"

# Send to group
python wukongim_cli.py message send -g group_id "Group message" -t group_id

# List friends
python wukongim_cli.py friend list

# List groups
python wukongim_cli.py group list

# Upload a file
python wukongim_cli.py upload /path/to/file.pdf

# Logout
python wukongim_cli.py auth logout
```

## Commands

### Authentication

| Command | Description |
|---------|-------------|
| `auth login -u <user> -p <pass>` | Login with username/password |
| `auth logout` | Logout and clear session |
| `auth register -u <user> -p <pass>` | Register new account |
| `auth me` | Get current user info |
| `auth update-profile --name <name>` | Update profile |

### Conversations

| Command | Description |
|---------|-------------|
| `conversations --limit 20` | List conversations |

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

### Files

| Command | Description |
|---------|-------------|
| `upload <file>` | Upload file |

## Options

- `--json` - Output in JSON format (for scripting)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WK_API_URL` | API base URL | `http://42.194.218.158` |
| `WK_APP_ID` | App ID | `wukongchat` |
| `WK_APP_KEY` | App Key | `25b002c6be2d539f264c` |

## Session Storage

Session data is stored in `~/.wukongim/session.json`. This includes:
- User ID (UID)
- Authentication token
- Username and display name
- Login timestamp

## Examples

### Full Workflow

```bash
# 1. Login
python wukongim_cli.py auth login -u john_doe -p secret123

# 2. Check profile
python wukongim_cli.py auth me

# 3. View conversations
python wukongim_cli.py conversations --limit 10

# 4. Send a message
python wukongim_cli.py message send -t abc123 "Hey, how are you?"

# 5. Sync recent messages
python wukongim_cli.py message sync --channel-id abc123 --limit 20

# 6. Create a group
python wukongim_cli.py group create -n "Project Team" -m "uid1,uid2,uid3"

# 7. Send to group
python wukongim_cli.py message send -g -t grp456 "Meeting at 3pm"

# 8. Upload a document
python wukongim_cli.py upload ./meeting_notes.pdf

# 9. Logout when done
python wukongim_cli.py auth logout
```

### Scripting with JSON Output

```bash
# Get user info as JSON for processing
python wukongim_cli.py auth me --json | jq '.uid'

# List all friend UIDs
python wukongim_cli.py friend list --json | jq '.[].uid'

# Search messages and count results
python wukongim_cli.py message search -k "project" --json | jq 'length'
```

## API Reference

For complete API documentation, see the WuKongIM server documentation.

Base endpoints:
- REST API: `http://42.194.218.158/v1/*`
- WebSocket: `42.194.218.158:5100`

## Troubleshooting

### "Not logged in" error
Run `auth login` first to authenticate.

### "Connection error"
Check that the API server is reachable at `http://42.194.218.158`.

### Session expires
Re-login with `auth login`. Sessions may expire after extended periods.

## License

Part of WuKongIM project.
