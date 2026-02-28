#!/usr/bin/env bash
# cms-session.sh — Core Claude Code multi-session manager
# Shares or copies: settings, MCPs, plugins from ~/.claude (configurable)
# Always isolates: history, projects, cache, auth per session
set -euo pipefail

# --- Configuration ---
CMS_CONFIG_DIR="${HOME}/.claude-multisession"
CMS_CONFIG_FILE="${CMS_CONFIG_DIR}/config"
CLAUDE_HOME_BASE="${HOME}/.claude-sessions"
CLAUDE_GLOBAL_CONFIG="${HOME}/.claude"

# --- Defaults (overridden by config file) ---
PERMISSIONS_MODE="default"
SHARING_MODE=""  # will be set per-session or globally

# --- Load global config if exists ---
if [[ -f "${CMS_CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CMS_CONFIG_FILE}"
fi

# --- Input validation ---
SESSION_NAME="${1:-default}"

# Sanitize session name: only allow alphanumeric, dash, underscore
if [[ ! "${SESSION_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid session name '${SESSION_NAME}'." >&2
    echo "Session names may only contain letters, numbers, dashes, and underscores." >&2
    exit 1
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

# --- Shared config items ---
SHARED_ITEMS=(settings.json plugins downloads paste-cache shell-snapshots session-env telemetry stats-cache.json debug ide)

# --- Link (symlink) shared global configuration ---
link_shared_config() {
    local name="$1"
    local source="${CLAUDE_GLOBAL_CONFIG}/${name}"
    local target="${CLAUDE_SESSION_DIR}/${name}"

    if [[ -e "${source}" ]] && [[ ! -e "${target}" ]]; then
        ln -sf "${source}" "${target}"
    fi
}

# --- Copy config (independent mode) ---
copy_independent_config() {
    local name="$1"
    local source="${CLAUDE_GLOBAL_CONFIG}/${name}"
    local target="${CLAUDE_SESSION_DIR}/${name}"

    if [[ -e "${source}" ]] && [[ ! -e "${target}" ]]; then
        if [[ -d "${source}" ]]; then
            cp -R "${source}" "${target}"
        else
            cp "${source}" "${target}"
        fi
    fi
}

# --- Session directory setup ---
CLAUDE_SESSION_DIR="${CLAUDE_HOME_BASE}/${SESSION_NAME}"
SESSION_CONFIG="${CLAUDE_SESSION_DIR}/.cms-session-config"
IS_NEW_SESSION=false

if [[ ! -d "${CLAUDE_SESSION_DIR}" ]]; then
    IS_NEW_SESSION=true
    echo "Creating new Claude session: ${SESSION_NAME}"
    mkdir -p "${CLAUDE_SESSION_DIR}"

    # Create session-specific directories
    for dir in projects cache backups file-history plans tasks todos; do
        mkdir -p "${CLAUDE_SESSION_DIR}/${dir}"
    done

    echo "Session directories created for: ${SESSION_NAME}"
fi

# --- First-launch: ask about sharing mode if interactive ---
# Determine sharing mode for this session
SESSION_SHARING_MODE=""
if [[ -f "${SESSION_CONFIG}" ]]; then
    # shellcheck source=/dev/null
    source "${SESSION_CONFIG}"
    SESSION_SHARING_MODE="${SESSION_SHARING_MODE:-}"
fi

if [[ -z "${SESSION_SHARING_MODE}" ]]; then
    # No per-session config yet
    if [[ "${IS_NEW_SESSION}" == true ]] && [[ -t 0 ]]; then
        # Interactive terminal + new session: ask the user
        echo ""
        echo "Configuration mode for '${SESSION_NAME}':"

        # Detect available global configs
        found_items=()
        for item in "${SHARED_ITEMS[@]}"; do
            if [[ -e "${CLAUDE_GLOBAL_CONFIG}/${item}" ]]; then
                found_items+=("${item}")
            fi
        done

        if [[ ${#found_items[@]} -gt 0 ]]; then
            echo "  Found global config: ${found_items[*]}"
        fi

        echo ""
        echo "  1) Shared  — Symlink settings/MCPs/plugins from ~/.claude (recommended)"
        echo "               All sessions use the same config. Changes apply everywhere."
        echo "  2) Independent — Copy config into this session"
        echo "               This session gets its own settings/MCPs/plugins."
        echo ""
        read -r -p "  Choose [1/2] (default: 1): " sharing_choice
        sharing_choice="${sharing_choice:-1}"

        case "${sharing_choice}" in
            2)
                SESSION_SHARING_MODE="independent"
                echo "  Independent mode selected."
                ;;
            *)
                SESSION_SHARING_MODE="shared"
                echo "  Shared mode selected."
                ;;
        esac
    else
        # Non-interactive or existing session: use global default
        SESSION_SHARING_MODE="${SHARING_MODE:-shared}"
    fi

    # Save per-session config
    mkdir -p "$(dirname "${SESSION_CONFIG}")"
    cat > "${SESSION_CONFIG}" << EOF
# Per-session config for ${SESSION_NAME}
SESSION_SHARING_MODE="${SESSION_SHARING_MODE}"
EOF
fi

# --- Apply sharing mode ---
case "${SESSION_SHARING_MODE}" in
    independent)
        for item in "${SHARED_ITEMS[@]}"; do
            copy_independent_config "${item}"
        done
        ;;
    *)
        for item in "${SHARED_ITEMS[@]}"; do
            link_shared_config "${item}"
        done
        ;;
esac

# --- Session-specific files ---
if [[ ! -f "${CLAUDE_SESSION_DIR}/history.jsonl" ]]; then
    touch "${CLAUDE_SESSION_DIR}/history.jsonl"
fi

# --- Independent auth directory per session ---
CLAUDE_AUTH_DIR="${CLAUDE_HOME_BASE}/${SESSION_NAME}/auth"
mkdir -p "${CLAUDE_AUTH_DIR}"
chmod 700 "${CLAUDE_AUTH_DIR}"

# --- Build CLI args ---
# Collect extra args passed after session name
EXTRA_ARGS=("${@:2}")

# Check if --dangerously-skip-permissions is already in extra args
HAS_SKIP_PERMS=false
for arg in "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"; do
    if [[ "${arg}" == "--dangerously-skip-permissions" ]]; then
        HAS_SKIP_PERMS=true
        break
    fi
done

CLAUDE_ARGS=()
if [[ "${PERMISSIONS_MODE}" == "full" ]] && [[ "${HAS_SKIP_PERMS}" == false ]]; then
    CLAUDE_ARGS+=("--dangerously-skip-permissions")
fi

# Determine effective permissions label
if [[ "${HAS_SKIP_PERMS}" == true ]] || [[ "${PERMISSIONS_MODE}" == "full" ]]; then
    PERM_LABEL="full (skip prompts)"
else
    PERM_LABEL="default"
fi

# --- Launch ---
echo ""
echo "Starting Claude session: ${SESSION_NAME}"
echo "  Session dir:  ${CLAUDE_SESSION_DIR}"
echo "  Auth dir:     ${CLAUDE_AUTH_DIR}"
echo "  Permissions:  ${PERM_LABEL}"
echo "  Config mode:  ${SESSION_SHARING_MODE}"
echo ""

export CLAUDE_HOME="${CLAUDE_SESSION_DIR}"
export CLAUDE_CONFIG_DIR="${CLAUDE_AUTH_DIR}"
exec claude ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
