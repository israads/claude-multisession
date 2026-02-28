# claude-multisession

Run multiple Claude Code instances **simultaneously**, each logged into a **different account**, with isolated conversation history — all from the same machine.

## The problem

Claude Code stores everything in one directory (`~/.claude`): your login, your conversation history, your project memory. That means:

- You can only be logged into **one account at a time**
- Switching accounts means logging out and back in
- You lose conversation context when switching
- You can't run two sessions with different accounts in parallel

If you have a personal account and a work account, or multiple clients each with their own org — you're stuck constantly logging in and out.

## What this solves

`claude-multisession` creates isolated session directories. Each session has its own authentication and history, but they all share your settings, MCP servers, and plugins. You log in once per session, and it stays logged in forever.

## Real-world use cases

### You have personal + work accounts

Your company gives you a Claude Max org seat. You also pay for a personal Pro account for side projects. Without multisession, you'd log out of one to use the other.

```bash
clauded-1    # → logged in as you@company.com (Max, Company Org)
clauded-2    # → logged in as you@gmail.com (Pro, personal)
```

Both run simultaneously. Each keeps its own conversation history.

### You freelance for multiple clients

Each client has their own Claude org and gave you a seat. You work on Client A in the morning and Client B in the afternoon — or both at the same time.

```bash
clauded-1    # → you@clientA.com — working on their API
clauded-2    # → you@clientB.com — working on their frontend
clauded-3    # → you@personal.com — your own side project
```

Conversations, project memory, and billing stay completely separate.

### You want to maximize rate limits

Claude Code has per-account rate limits. With multiple accounts on different plans, you can keep working when one hits its limit.

```bash
clauded-1    # → account A (hit rate limit)
clauded-2    # → account B (still has capacity) — keep working
```

### You share a machine with a teammate

Two developers, one workstation. Each has their own Claude account.

```bash
clauded-1    # → dev1@team.com
clauded-2    # → dev2@team.com
```

Independent history, independent auth, independent billing.

### You want separate contexts per project

Even with one account, you might want isolated conversation history per project so Claude doesn't mix up context.

```bash
clauded-1    # → big-refactor project (long conversation history)
clauded-2    # → quick-fixes (fresh context, no clutter)
```

## Quick example

```bash
# Install
npm install -g claude-multisession
cms-install    # interactive setup, takes 30 seconds

# Open two terminals
clauded-1      # Terminal 1: logs in as work@company.com
clauded-2      # Terminal 2: logs in as me@gmail.com

# Check who's logged in where
cms-who
# Claude Sessions - Accounts
# =================================================================
#   Command      Session         Plan     Account
# -----------------------------------------------------------------
#   cms 0        default         -        not logged in
#   cms 1        session-1       max      work@company.com
#   cms 2        session-2       pro      me@gmail.com
```

Each session remembers its login. Next time you run `clauded-1`, you're already authenticated — no need to log in again.

## Install

### npm (recommended)

```bash
npm install -g claude-multisession
cms-install
```

### npx (one-shot)

```bash
npx claude-multisession
```

### Manual

```bash
git clone https://github.com/israads/claude-multisession.git
cd claude-multisession
./install.sh
```

The installer walks you through 7 steps: checks prerequisites, asks your preferred command name, permission mode, number of sessions, config sharing preference, creates directories, and sets up shell aliases.

## Usage

During installation you choose your command name (default: `clauded`). Both space and dash syntax work identically:

```bash
clauded 1      # space syntax → session 1
clauded-1      # dash syntax  → session 1 (same thing)
```

### All commands

| Command | What it does |
|---------|-------------|
| `clauded` | Launch default session (session 0) |
| `clauded 1` or `clauded-1` | Launch session 1 |
| `clauded 2` or `clauded-2` | Launch session 2 |
| `clauded! 1` or `clauded-1!` | Session 1 with full permissions (skip prompts) |
| `cms-who` | Show which account is logged into each session |
| `cms-info` | Show detailed info (email, plan, org, conversations) |
| `cms-info 2` | Info for session 2 only |
| `cms-list` | List all sessions with status |
| `cms-clean session-1` | Delete session 1 and all its data |

### Custom command names

The installer asks what you want your command to be called. If you prefer `cs` instead of `clauded`:

```bash
cs 1       # session 1
cs-1       # session 1 (same)
cs! 1      # session 1, full permissions
cs-1!      # session 1, full permissions (same)
```

### Permission modes

- **`clauded-N`** — Default permissions: Claude asks before risky operations
- **`clauded-N!`** — Full permissions: `--dangerously-skip-permissions` (the `!` means "skip all safety prompts")

## How it works

```
~/.claude/                  ← your global config (shared)
  ├── settings.json
  ├── plugins/
  └── ...

~/.claude-sessions/         ← created by multisession
  ├── default/              ← clauded / clauded-0
  │   ├── auth/             ← independent login (chmod 700)
  │   ├── history.jsonl     ← independent conversations
  │   ├── projects/         ← independent project memory
  │   ├── settings.json     ← symlink → ~/.claude/settings.json
  │   └── plugins           ← symlink → ~/.claude/plugins
  ├── session-1/            ← clauded-1
  │   ├── auth/             ← different account
  │   ├── history.jsonl     ← different conversations
  │   └── ...
  └── session-2/            ← clauded-2
      └── ...
```

**Isolated per session:** authentication, conversation history, project memory, cache.

**Shared across sessions (configurable):** settings.json, MCP servers, plugins, IDE config. On first launch of each session, you choose whether to share (symlink) or copy (independent).

## Configuration

Global config: `~/.claude-multisession/config`

```bash
PERMISSIONS_MODE="default"   # "default" or "full"
SESSION_COUNT="5"            # number of sessions
SHARING_MODE="shared"        # "shared", "independent", or "ask"
CMD_NAME="clauded"           # your chosen command name
```

| Setting | Options | What it controls |
|---------|---------|-----------------|
| `PERMISSIONS_MODE` | `default` / `full` | Whether Claude asks before risky operations |
| `SHARING_MODE` | `shared` / `independent` / `ask` | Whether sessions share settings from `~/.claude` or get their own copy |
| `CMD_NAME` | any name | The command you type to launch sessions |

Per-session overrides are stored in `~/.claude-sessions/<name>/.cms-session-config`.

## Platform support

| Platform | Status |
|----------|--------|
| macOS | Full support |
| Linux | Full support |
| Windows (WSL) | Full support (run inside WSL) |
| Windows (Git Bash) | Partial |
| Windows (native) | Not supported |

## Security

- Session names are sanitized (`[a-zA-Z0-9_-]` only) to prevent path traversal
- Auth directories have restrictive permissions (`chmod 700`)
- No hardcoded permission flags — everything is user-configurable
- All variable expansions are properly quoted to prevent injection

## Uninstall

```bash
npm uninstall -g claude-multisession
```

Optionally remove data:

```bash
rm -rf ~/.claude-sessions
rm -rf ~/.claude-multisession
```

And remove the alias block from your `.zshrc` or `.bashrc` (between `# --- claude-multisession aliases ---` markers).

## License

MIT
