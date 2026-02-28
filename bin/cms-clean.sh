#!/usr/bin/env bash
# cms-clean.sh — Delete a Claude session
# Usage: cms-clean <session-name>
#   cms-clean session-1
#   cms-clean default
set -euo pipefail

CLAUDE_HOME_BASE="${HOME}/.claude-sessions"

SESSION_NAME="${1:-}"

if [[ -z "${SESSION_NAME}" ]]; then
    echo "Usage: cms-clean <session-name>" >&2
    echo "" >&2
    echo "Available sessions:" >&2
    if [[ -d "${CLAUDE_HOME_BASE}" ]]; then
        for d in "${CLAUDE_HOME_BASE}"/*/; do
            [[ -d "${d}" ]] && echo "  $(basename "${d}")"
        done
    else
        echo "  (none)"
    fi
    exit 1
fi

# Sanitize session name
if [[ ! "${SESSION_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid session name '${SESSION_NAME}'." >&2
    exit 1
fi

SESSION_DIR="${CLAUDE_HOME_BASE}/${SESSION_NAME}"

if [[ ! -d "${SESSION_DIR}" ]]; then
    echo "Error: Session '${SESSION_NAME}' not found." >&2
    exit 1
fi

echo "This will delete all data for session: ${SESSION_NAME}"
echo "  Directory: ${SESSION_DIR}"
read -r -p "Are you sure? (y/N): " confirm

if [[ "${confirm}" =~ ^[Yy]$ ]]; then
    rm -rf "${SESSION_DIR}"
    echo "Session '${SESSION_NAME}' deleted."
else
    echo "Cancelled."
fi
