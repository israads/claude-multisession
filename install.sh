#!/usr/bin/env bash
# install.sh — Interactive installer for claude-multisession
set -euo pipefail

# --- Colors ---
if [[ -t 1 ]]; then
    BLUE='\033[0;34m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    BLUE='' GREEN='' RED='' YELLOW='' BOLD='' DIM='' NC=''
fi

CMS_CONFIG_DIR="${HOME}/.claude-multisession"
CMS_CONFIG_FILE="${CMS_CONFIG_DIR}/config"
CLAUDE_HOME_BASE="${HOME}/.claude-sessions"

echo -e "${BLUE}${BOLD}claude-multisession installer${NC}"
echo "================================================================="
echo ""

# --- Step 1: Check prerequisites ---
echo -e "${BOLD}[1/7] Checking prerequisites...${NC}"

if ! command -v claude &>/dev/null; then
    echo -e "${RED}Error: 'claude' CLI not found.${NC}" >&2
    echo "Install Claude Code first: npm install -g @anthropic-ai/claude-code" >&2
    exit 1
fi

CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
echo -e "  Claude CLI: ${GREEN}found${NC} (${CLAUDE_VERSION})"

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Darwin) echo -e "  Platform:   ${GREEN}macOS${NC}" ;;
    Linux)  echo -e "  Platform:   ${GREEN}Linux${NC}" ;;
    *)
        echo -e "  Platform:   ${YELLOW}${OS}${NC} (may have limited support)"
        echo "  Note: Windows users should run this inside WSL or Git Bash."
        ;;
esac
echo ""

# --- Step 2: Command name ---
echo -e "${BOLD}[2/7] Command name${NC}"
echo "  What base name do you want for your commands?"
echo ""
echo -e "  Examples: if you choose ${BOLD}clauded${NC}, you'll get:"
echo -e "    ${DIM}clauded      → default session${NC}"
echo -e "    ${DIM}clauded-1    → session 1 (default permissions)${NC}"
echo -e "    ${DIM}clauded-1!   → session 1 (full permissions)${NC}"
echo ""
read -r -p "  Command name (default: clauded): " CMD_NAME
CMD_NAME="${CMD_NAME:-clauded}"

# Validate: only allow alphanumeric and dash
if [[ ! "${CMD_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]]; then
    echo -e "  ${YELLOW}Invalid name. Using default: clauded${NC}"
    CMD_NAME="clauded"
fi
echo -e "  ${GREEN}Command name: ${CMD_NAME}${NC}"
echo ""

# --- Step 3: Permission mode ---
echo -e "${BOLD}[3/7] Permission mode${NC}"
echo "  How should Claude handle permissions in sessions?"
echo ""
echo "  1) Default — Claude asks before risky operations (recommended)"
echo "  2) Full permissions — skip all permission prompts (--dangerously-skip-permissions)"
echo ""
read -r -p "  Choose [1/2] (default: 1): " perm_choice
perm_choice="${perm_choice:-1}"

case "${perm_choice}" in
    2)
        PERMISSIONS_MODE="full"
        echo -e "  ${YELLOW}Full permissions mode selected.${NC}"
        ;;
    *)
        PERMISSIONS_MODE="default"
        echo -e "  ${GREEN}Default permissions mode selected.${NC}"
        ;;
esac
echo ""

# --- Step 4: Number of sessions ---
echo -e "${BOLD}[4/7] Number of sessions${NC}"
echo "  How many sessions do you want? (1-9)"
echo "  Each session gets independent auth, history, and projects."
echo ""
read -r -p "  Number of sessions (default: 5): " session_count
session_count="${session_count:-5}"

# Validate
if [[ ! "${session_count}" =~ ^[1-9]$ ]]; then
    echo -e "  ${YELLOW}Invalid input. Using default: 5${NC}"
    session_count=5
fi
echo -e "  ${GREEN}Will create ${session_count} session(s) + default.${NC}"
echo ""

# --- Step 5: Default sharing mode ---
echo -e "${BOLD}[5/7] Default config sharing mode${NC}"
echo "  How should sessions handle settings, MCPs, and plugins?"
echo ""
echo "  1) Shared — Symlink from ~/.claude (recommended)"
echo "     All sessions use the same config. Changes apply everywhere."
echo "  2) Independent — Copy config into each session"
echo "     Each session gets its own settings/MCPs/plugins."
echo "  3) Ask per session — Prompt on first launch of each session"
echo ""
read -r -p "  Choose [1/2/3] (default: 1): " sharing_choice
sharing_choice="${sharing_choice:-1}"

case "${sharing_choice}" in
    2)
        SHARING_MODE="independent"
        echo -e "  ${GREEN}Independent mode selected.${NC}"
        ;;
    3)
        SHARING_MODE="ask"
        echo -e "  ${GREEN}Will ask on each session's first launch.${NC}"
        ;;
    *)
        SHARING_MODE="shared"
        echo -e "  ${GREEN}Shared mode selected.${NC}"
        ;;
esac
echo ""

# --- Step 6: Create config and directories ---
echo -e "${BOLD}[6/7] Setting up...${NC}"

# Create config directory
mkdir -p "${CMS_CONFIG_DIR}"

# Write config file
cat > "${CMS_CONFIG_FILE}" << EOF
# claude-multisession configuration
# Generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
PERMISSIONS_MODE="${PERMISSIONS_MODE}"
SESSION_COUNT="${session_count}"
SHARING_MODE="${SHARING_MODE}"
CMD_NAME="${CMD_NAME}"
EOF
echo "  Config: ${CMS_CONFIG_FILE}"

# Create session directories
mkdir -p "${CLAUDE_HOME_BASE}"

# Pre-create session directories (without launching claude)
for i in $(seq 1 "${session_count}"); do
    session_name="session-${i}"
    session_dir="${CLAUDE_HOME_BASE}/${session_name}"
    if [[ ! -d "${session_dir}" ]]; then
        mkdir -p "${session_dir}"/{projects,cache,backups,file-history,plans,tasks,todos}
        mkdir -p "${session_dir}/auth"
        chmod 700 "${session_dir}/auth"
        echo "  Created: ${session_name}"
    else
        echo "  Exists:  ${session_name}"
    fi
done

# Also ensure default exists
default_dir="${CLAUDE_HOME_BASE}/default"
if [[ ! -d "${default_dir}" ]]; then
    mkdir -p "${default_dir}"/{projects,cache,backups,file-history,plans,tasks,todos}
    mkdir -p "${default_dir}/auth"
    chmod 700 "${default_dir}/auth"
    echo "  Created: default"
else
    echo "  Exists:  default"
fi
echo ""

# --- Step 7: Shell aliases ---
echo -e "${BOLD}[7/7] Shell aliases${NC}"

# Detect shell
SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
case "${SHELL_NAME}" in
    zsh)  RC_FILE="${HOME}/.zshrc" ;;
    bash) RC_FILE="${HOME}/.bashrc" ;;
    *)    RC_FILE="${HOME}/.${SHELL_NAME}rc" ;;
esac

# Build alias block
# Both patterns work: "name 1" (function) and "name-1" (alias)
# "name!" variants = full permissions
ALIAS_BLOCK="
# --- claude-multisession aliases ---

# Function: ${CMD_NAME} [N] — launch session N (0=default)
${CMD_NAME}() {
  cms \"\${1:-0}\" \"\${@:2}\"
}

# Dash aliases (default permissions)
alias ${CMD_NAME}-0='cms 0'"

for i in $(seq 1 "${session_count}"); do
    ALIAS_BLOCK="${ALIAS_BLOCK}
alias ${CMD_NAME}-${i}='cms ${i}'"
done

ALIAS_BLOCK="${ALIAS_BLOCK}

# Bang aliases: full permissions (--dangerously-skip-permissions)
# Usage: ${CMD_NAME}-1! or ${CMD_NAME}! 1
${CMD_NAME}!() {
  cms \"\${1:-0}\" --dangerously-skip-permissions \"\${@:2}\"
}
alias ${CMD_NAME}-0!='cms 0 --dangerously-skip-permissions'"

for i in $(seq 1 "${session_count}"); do
    ALIAS_BLOCK="${ALIAS_BLOCK}
alias ${CMD_NAME}-${i}!='cms ${i} --dangerously-skip-permissions'"
done

ALIAS_BLOCK="${ALIAS_BLOCK}
# --- end claude-multisession ---"

echo -e "  Commands that will be available:"
echo ""
echo -e "  ${BOLD}With space (function):${NC}"
echo -e "    ${GREEN}${CMD_NAME}${NC}        → default session"
echo -e "    ${GREEN}${CMD_NAME} 1${NC}      → session 1"
echo -e "    ${GREEN}${CMD_NAME} 2${NC}      → session 2"
echo ""
echo -e "  ${BOLD}With dash (alias):${NC}"
echo -e "    ${GREEN}${CMD_NAME}-1${NC}      → session 1"
echo -e "    ${GREEN}${CMD_NAME}-2${NC}      → session 2"
echo ""
echo -e "  ${BOLD}Full permissions (! suffix):${NC}"
echo -e "    ${GREEN}${CMD_NAME}! 1${NC}     → session 1 (skip prompts)"
echo -e "    ${GREEN}${CMD_NAME}-1!${NC}     → session 1 (skip prompts)"
echo ""
echo -e "  ${DIM}Both \"${CMD_NAME} 1\" and \"${CMD_NAME}-1\" launch the same session.${NC}"
echo ""

read -r -p "  Add to ${RC_FILE}? (Y/n): " add_aliases
add_aliases="${add_aliases:-Y}"

if [[ "${add_aliases}" =~ ^[Yy]$ ]]; then
    # Remove old aliases block if present
    if grep -q "# --- claude-multisession aliases ---" "${RC_FILE}" 2>/dev/null; then
        tmp_file="$(mktemp)"
        sed '/# --- claude-multisession aliases ---/,/# --- end claude-multisession ---/d' "${RC_FILE}" > "${tmp_file}"
        mv "${tmp_file}" "${RC_FILE}"
    fi

    echo "${ALIAS_BLOCK}" >> "${RC_FILE}"
    echo -e "  ${GREEN}Aliases added to ${RC_FILE}${NC}"
else
    echo "  Skipped. You can add them manually later."
fi

echo ""
echo "================================================================="
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "Quick start:"
echo "  1. Reload your shell:  source ${RC_FILE}"
echo "  2. Launch default:     ${CMD_NAME}  (or ${CMD_NAME}-0)"
echo "  3. Launch session 1:   ${CMD_NAME} 1  (or ${CMD_NAME}-1)"
echo "  4. Log in each session with a different account"
echo "  5. Check accounts:     cms-who"
echo ""
echo "Commands:"
echo "  ${CMD_NAME} [N]       Launch session N (0=default)"
echo "  ${CMD_NAME}-N         Same thing, dash style"
echo "  ${CMD_NAME}! N        Full permissions mode"
echo "  ${CMD_NAME}-N!        Full permissions mode, dash style"
echo "  cms-who          Show accounts per session"
echo "  cms-info [N]     Show detailed session info"
echo "  cms-list         List all sessions"
echo "  cms-clean <name> Delete a session"
echo ""
echo -e "${DIM}Sessions stored in: ${CLAUDE_HOME_BASE}${NC}"
echo -e "${DIM}Config stored in:   ${CMS_CONFIG_DIR}${NC}"
