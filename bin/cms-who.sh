#!/usr/bin/env bash
# cms-who.sh — Show which account is logged in on each Claude session
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

echo -e "${BLUE}${BOLD}Claude Sessions - Accounts${NC}"
echo "================================================================="
printf "  ${DIM}%-12s %-15s %-8s %s${NC}\n" "Command" "Session" "Plan" "Account"
echo "-----------------------------------------------------------------"

if [[ ! -d "${CLAUDE_HOME_BASE}" ]]; then
    echo "  No sessions found. Run cms-install to set up."
    exit 0
fi

# --- Cross-platform email extraction from .claude.json ---
get_email_from_json() {
    local session_dir="$1"
    local claude_json="${session_dir}/auth/.claude.json"
    if [[ -f "${claude_json}" ]]; then
        local email
        email=$(grep -o '"emailAddress"[[:space:]]*:[[:space:]]*"[^"]*"' "${claude_json}" 2>/dev/null | head -1 | sed 's/.*"emailAddress"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if [[ -n "${email}" ]]; then
            echo "${email}"
            return 0
        fi
    fi
    return 1
}

for session_dir in "${CLAUDE_HOME_BASE}"/*/; do
    [[ -d "${session_dir}" ]] || continue
    session_name="$(basename "${session_dir}")"
    auth_dir="${session_dir}auth"

    if [[ "${session_name}" == "default" ]]; then
        cmd="cms 0"
    else
        cmd="cms ${session_name#session-}"
    fi

    # Try fast path: read email from .claude.json
    email=""
    email=$(get_email_from_json "${session_dir}") || true

    if [[ -n "${email}" ]]; then
        result=$(CLAUDE_HOME="${session_dir}" CLAUDE_CONFIG_DIR="${auth_dir}" claude auth status 2>&1) || true
        sub=$(json_str "subscriptionType" "${result}")
        sub="${sub:-?}"
        printf "  %-12s %-15s ${YELLOW}%-8s${NC} ${GREEN}%s${NC}\n" "${cmd}" "${session_name}" "${sub}" "${email}"
    else
        # Fallback: use claude auth status
        result=$(CLAUDE_HOME="${session_dir}" CLAUDE_CONFIG_DIR="${auth_dir}" claude auth status 2>&1) || true
        logged=$(echo "${result}" | grep '"loggedIn"' | grep -o 'true\|false') || true
        email=$(json_str "email" "${result}")
        sub=$(json_str "subscriptionType" "${result}")

        if [[ "${logged}" == "true" ]] && [[ -n "${email}" ]]; then
            printf "  %-12s %-15s ${YELLOW}%-8s${NC} ${GREEN}%s${NC}\n" "${cmd}" "${session_name}" "${sub}" "${email}"
        else
            printf "  %-12s %-15s %-8s ${RED}%s${NC}\n" "${cmd}" "${session_name}" "-" "not logged in"
        fi
    fi
done

echo ""
