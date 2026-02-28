#!/usr/bin/env bash
# cms-list.sh — List all Claude sessions
set -euo pipefail

CLAUDE_HOME_BASE="${HOME}/.claude-sessions"

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    BOLD='' DIM='' GREEN='' RED='' NC=''
fi

# --- Cross-platform stat ---
file_mtime() {
    local file="$1"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$file" 2>/dev/null || echo "unknown"
    else
        stat -c "%y" "$file" 2>/dev/null | cut -d. -f1 || echo "unknown"
    fi
}

echo -e "${BOLD}Claude Sessions${NC}"
echo "================================"

if [[ ! -d "${CLAUDE_HOME_BASE}" ]]; then
    echo "No sessions found. Run cms-install to set up."
    exit 0
fi

for session_dir in "${CLAUDE_HOME_BASE}"/*/; do
    [[ -d "${session_dir}" ]] || continue
    session_name="$(basename "${session_dir}")"

    if [[ "${session_name}" == "default" ]]; then
        cmd="cms 0"
    else
        cmd="cms ${session_name#session-}"
    fi

    # Check configuration
    if [[ -f "${session_dir}/settings.json" ]] || [[ -L "${session_dir}/settings.json" ]]; then
        status="${GREEN}configured${NC}"
    else
        status="${RED}not configured${NC}"
    fi

    # Check last used
    if [[ -f "${session_dir}/history.jsonl" ]]; then
        last_used=$(file_mtime "${session_dir}/history.jsonl")
        status="${status} ${DIM}(last: ${last_used})${NC}"
    fi

    printf "  %-12s -> %-15s %b\n" "${cmd}" "${session_name}" "${status}"
done

echo ""
echo -e "${DIM}Usage: cms [N]  |  cms-who  |  cms-info  |  cms-clean <name>${NC}"
