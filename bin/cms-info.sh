#!/usr/bin/env bash
# cms-info.sh — Show detailed info for each Claude session
# Usage: cms-info [session-number|session-name]
set -euo pipefail

CLAUDE_HOME_BASE="${HOME}/.claude-sessions"

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    DIM='\033[2m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    BLUE='' GREEN='' RED='' YELLOW='' DIM='' BOLD='' NC=''
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

# --- Parse a JSON string value; returns empty for null ---
json_str() {
    local key="$1" json="$2"
    local val
    val=$(echo "${json}" | grep "\"${key}\"" | head -1)
    # Check for null
    if echo "${val}" | grep -q ": *null"; then
        echo ""
        return
    fi
    echo "${val}" | sed 's/.*"'"${key}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# --- Filter ---
FILTER="${1:-}"

echo -e "${BLUE}${BOLD}Claude Sessions - Info${NC}"
echo "================================================================="

if [[ ! -d "${CLAUDE_HOME_BASE}" ]]; then
    echo "  No sessions found. Run cms-install to set up."
    exit 0
fi

for session_dir in "${CLAUDE_HOME_BASE}"/*/; do
    [[ -d "${session_dir}" ]] || continue
    session_name="$(basename "${session_dir}")"
    auth_dir="${session_dir}auth"

    if [[ "${session_name}" == "default" ]]; then
        cmd="cms 0"
        num="0"
    else
        num="${session_name#session-}"
        cmd="cms ${num}"
    fi

    # Apply filter if specified
    if [[ -n "${FILTER}" ]]; then
        if [[ "${FILTER}" != "${num}" ]] && [[ "${FILTER}" != "${session_name}" ]]; then
            continue
        fi
    fi

    # Get auth info
    result=$(CLAUDE_HOME="${session_dir}" CLAUDE_CONFIG_DIR="${auth_dir}" claude auth status 2>&1) || true
    logged=$(echo "${result}" | grep '"loggedIn"' | grep -o 'true\|false') || true
    email=$(json_str "email" "${result}")
    sub=$(json_str "subscriptionType" "${result}")
    org=$(json_str "orgName" "${result}")

    if [[ "${logged}" != "true" ]] || [[ -z "${email}" ]]; then
        echo -e "\n  ${BLUE}${BOLD}[${cmd}]${NC} ${RED}not logged in${NC}"
        continue
    fi

    echo -e "\n  ${BLUE}${BOLD}[${cmd}]${NC} ${GREEN}${email}${NC}"
    echo -e "  Plan: ${YELLOW}${sub:-unknown}${NC}  |  Org: ${org:-none}"

    # Show history stats
    history_file="${session_dir}history.jsonl"
    if [[ -f "${history_file}" ]]; then
        lines=$(wc -l < "${history_file}" 2>/dev/null | tr -d ' ')
        last_used=$(file_mtime "${history_file}")
        echo -e "  Conversations: ${lines}  |  Last used: ${last_used}"
    fi
done

echo -e "\n-----------------------------------------------------------------"
echo -e "${DIM}For detailed rate limits, run /usage inside each active session.${NC}"
echo ""
