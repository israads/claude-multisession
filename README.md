# claude-multisession

Run multiple Claude Code instances with **independent accounts**, isolated history, and shared (or independent) configuration.

## Why?

Claude Code ties authentication, history, and projects to a single `~/.claude` directory. If you have multiple accounts (personal, work, different orgs), you can't easily switch between them. This package solves that by creating isolated session directories, each with its own auth, while optionally sharing settings, MCPs, and plugins across all sessions.

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
git clone https://github.com/israellaguan/claude-multisession.git
cd claude-multisession
./install.sh
```

## Usage

During installation you choose your command name (default: `clauded`). Both space and dash syntax work identically:

```bash
clauded 1      # space syntax → session 1
clauded-1      # dash syntax  → session 1 (same thing)
```

### All commands

| Command | Action |
|---------|--------|
| `clauded` | Launch default session |
| `clauded 1` or `clauded-1` | Launch session 1 |
| `clauded 2` or `clauded-2` | Launch session 2 |
| `clauded! 1` or `clauded-1!` | Session 1 with full permissions |
| `cms-who` | Show all accounts |
| `cms-info` | Show all session info |
| `cms-info 2` | Info for session 2 only |
| `cms-list` | List sessions |
| `cms-clean session-1` | Delete session 1 |

### Custom command names

The installer asks what you want your command to be called. For example, if you choose `claude-session`:

```bash
claude-session 1      # session 1
claude-session-1      # session 1 (same)
claude-session! 1     # session 1, full permissions
claude-session-1!     # session 1, full permissions (same)
```

### Permission convention

- **`clauded-N`** — Default permissions (Claude asks before risky operations)
- **`clauded-N!`** — Full permissions (`--dangerously-skip-permissions`)

The `!` suffix means "dangerous mode / skip all prompts".

## How it works

Each session gets its own directory under `~/.claude-sessions/`:

```
~/.claude-sessions/
├── default/          # clauded / clauded-0
│   ├── auth/         # Independent authentication (chmod 700)
│   ├── history.jsonl # Independent conversation history
│   ├── projects/     # Independent project memory
│   ├── settings.json # Symlink to ~/.claude/settings.json (if shared mode)
│   └── ...
├── session-1/        # clauded 1 / clauded-1
│   ├── auth/
│   ├── history.jsonl
│   └── ...
└── session-2/        # clauded 2 / clauded-2
    └── ...
```

### What's isolated per session
- Authentication (login with different accounts)
- Conversation history
- Project memory and context
- Cache and file history

### What's shared (configurable per session)
- `settings.json` (permissions, preferences)
- MCP servers configuration
- Plugins and extensions
- IDE configuration

### First-launch prompt

When you launch a new session for the first time, you'll be asked:

```
Configuration mode for 'session-1':
  Found global config: settings.json plugins ide

  1) Shared  — Symlink settings/MCPs/plugins from ~/.claude (recommended)
  2) Independent — Copy config into this session

  Choose [1/2] (default: 1):
```

This is stored per-session, so session-1 can be shared while session-2 is independent.

You can also set a global default during installation to skip this prompt.

## Configuration

Global config lives in `~/.claude-multisession/config`:

```bash
PERMISSIONS_MODE="default"   # "default" or "full"
SESSION_COUNT="5"
SHARING_MODE="shared"        # "shared", "independent", or "ask"
CMD_NAME="clauded"           # your chosen command name
```

- **`PERMISSIONS_MODE=default`** — Claude asks before risky operations
- **`PERMISSIONS_MODE=full`** — Adds `--dangerously-skip-permissions` flag
- **`SHARING_MODE=shared`** — Symlinks settings/MCPs from `~/.claude`
- **`SHARING_MODE=independent`** — Each session gets its own copy
- **`SHARING_MODE=ask`** — Prompt on first launch of each session
- **`CMD_NAME`** — The command name you chose during install

Per-session config is stored in `~/.claude-sessions/<name>/.cms-session-config`.

## Platform support

| Platform | Support |
|----------|---------|
| macOS | Full |
| Linux | Full |
| Windows (WSL) | Full (run inside WSL) |
| Windows (Git Bash) | Partial (some features may not work) |
| Windows (native) | Not supported |

## Security

- Session names are sanitized (alphanumeric, dash, underscore only) to prevent path traversal
- Auth directories have restrictive permissions (700)
- No hardcoded permission flags — everything is configurable
- All variable expansions are properly quoted

## Uninstall

```bash
npm uninstall -g claude-multisession
```

Then optionally remove data:

```bash
rm -rf ~/.claude-sessions
rm -rf ~/.claude-multisession
```

And remove the alias block from your `.zshrc` or `.bashrc` (between `# --- claude-multisession aliases ---` markers).

## License

MIT
