#!/usr/bin/env bash
# cms-launcher.sh — Launch Claude Code sessions by number
# Usage: cms [N] [claude-args...]
#   cms       → default session
#   cms 0     → default session
#   cms 1     → session-1
#   cms 2     → session-2
#   cms 1 -c  → session-1 with --continue
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SESSION_NUM="${1:-0}"

# Validate session number
if [[ ! "${SESSION_NUM}" =~ ^[0-9]+$ ]]; then
    # Not a number — pass everything as claude args to default session
    exec "${SCRIPT_DIR}/cms-session.sh" "default" "$@"
fi

# Map number to session name
if [[ "${SESSION_NUM}" -eq 0 ]]; then
    SESSION_NAME="default"
else
    SESSION_NAME="session-${SESSION_NUM}"
fi

# Pass remaining args (skip the session number)
shift 2>/dev/null || true
exec "${SCRIPT_DIR}/cms-session.sh" "${SESSION_NAME}" "$@"
