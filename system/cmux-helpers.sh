#!/usr/bin/env bash
# cmux-helpers.sh — Shared library for cmux workspace management with Amp
#
# Usage:
#   source system/cmux-helpers.sh                          # from start-day.sh
#   bash system/cmux-helpers.sh launch <workstream-name>   # standalone (from Chief of Staff)
#
# Architecture:
#   ┌──────────────┐     ┌────────────────┐     ┌───────────┐
#   │ start-day.sh │────>│ cmux-helpers.sh│────>│  cmux CLI │
#   └──────────────┘     │                │     └───────────┘
#   ┌──────────────┐     │  Functions:    │     ┌───────────┐
#   │ Amp (CoS)    │────>│  prepare_ws()  │────>│    Amp    │
#   └──────────────┘     │  launch()      │     └───────────┘
#                        └────────────────┘

set -euo pipefail

# --- Configuration (all overridable via env) ---
CMUX_BIN="${CMUX_BIN:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
AMP_CMD="${AMP_CMD:-amp}"
REPO_ROOT="${REPO_ROOT:-$HOME/Development/ai-pm-os}"

AMP_READY_TIMEOUT="${AMP_READY_TIMEOUT:-60}"
AMP_READY_POLL="${AMP_READY_POLL:-2}"

# --- Logging ---
_helpers_log() {
    local level="$1"; shift
    local ts
    ts=$(date '+%H:%M:%S')
    echo "[$ts] [$level] $*" >&2
}

log_info()  { _helpers_log "INFO"  "$@"; }
log_warn()  { _helpers_log "WARN"  "$@"; }
log_error() { _helpers_log "ERROR" "$@"; }
log_ok()    { _helpers_log " OK  " "$@"; }

# --- Core cmux wrapper ---
cmux_cmd() {
    "$CMUX_BIN" "$@"
}

# --- Workspace Functions ---

# Get the terminal surface ref for a workspace.
# cmux read-screen requires --surface; this resolves it from the workspace tree.
get_workspace_surface() {
    local ws_ref="$1"
    local tree_output
    tree_output=$(cmux_cmd tree --workspace "$ws_ref" 2>/dev/null) || return 1
    local surface_ref
    surface_ref=$(echo "$tree_output" | grep -oE 'surface:[0-9]+' | head -1 || true)
    if [[ -z "$surface_ref" ]]; then
        return 1
    fi
    echo "$surface_ref"
}

# Find workspace by exact name. Prints ref (e.g. "workspace:2") on success.
find_workspace_by_name() {
    local target_name="$1"
    local output
    output=$(cmux_cmd list-workspaces 2>/dev/null) || return 1

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ref
        ref=$(echo "$line" | grep -oE 'workspace:[0-9]+' || true)
        [[ -z "$ref" ]] && continue

        # Strip leading markers, ref, trailing [selected]
        local ws_name
        ws_name=$(echo "$line" | sed -E 's/^[* ]*workspace:[0-9]+  //' | sed 's/ *\[selected\]$//')
        if [[ "$ws_name" == "$target_name" ]]; then
            echo "$ref"
            return 0
        fi
    done <<< "$output"
    return 1
}

# Find or create workspace by name. Prints ref on success.
find_or_create_workspace() {
    local name="$1"
    local cwd="${2:-$REPO_ROOT}"
    local ws_ref

    if ws_ref=$(find_workspace_by_name "$name"); then
        log_info "Reusing workspace: $name ($ws_ref)"
        echo "$ws_ref"
        return 0
    fi

    log_info "Creating workspace: $name"
    local output
    output=$(cmux_cmd new-workspace --cwd "$cwd" 2>&1) || {
        log_error "Failed to create workspace: $name"
        return 1
    }

    # Try to extract ref from output
    ws_ref=$(echo "$output" | grep -oE 'workspace:[0-9]+' | head -1 || true)

    # Fallback: find the workspace we just created (it may be the newest)
    if [[ -z "$ws_ref" ]]; then
        sleep 1
        # Re-list and grab the last (newest) workspace
        ws_ref=$(cmux_cmd list-workspaces 2>/dev/null | grep -oE 'workspace:[0-9]+' | tail -1 || true)
    fi

    if [[ -z "$ws_ref" ]]; then
        log_error "Could not determine ref for new workspace: $name"
        return 1
    fi

    cmux_cmd rename-workspace --workspace "$ws_ref" "$name" &>/dev/null || {
        log_warn "Failed to rename workspace to: $name"
    }

    log_ok "Created workspace: $name ($ws_ref)"
    echo "$ws_ref"
}

# Reset workspace surface to a clean shell prompt.
# Interrupts running processes and exits the AI agent if active.
reset_workspace_surface() {
    local ws_ref="$1"

    # Resolve the terminal surface (required for read-screen)
    local sf_ref
    sf_ref=$(get_workspace_surface "$ws_ref" || true)

    # Interrupt anything running
    cmux_cmd send-key --workspace "$ws_ref" "ctrl+c" &>/dev/null || true
    sleep 1
    cmux_cmd send-key --workspace "$ws_ref" "ctrl+c" &>/dev/null || true
    sleep 0.5

    # Check if Amp is at its prompt (need --surface for read-screen)
    local screen=""
    if [[ -n "$sf_ref" ]]; then
        screen=$(cmux_cmd read-screen --workspace "$ws_ref" --surface "$sf_ref" --lines 5 2>/dev/null || true)
    fi

    if echo "$screen" | grep -qE '(❯|> |╭──|╰──)'; then
        log_info "Amp session detected, exiting..."
        cmux_cmd send --workspace "$ws_ref" "/exit" &>/dev/null || true
        cmux_cmd send-key --workspace "$ws_ref" "Enter" &>/dev/null || true
        sleep 3

        # Verify Amp exited
        if [[ -n "$sf_ref" ]]; then
            screen=$(cmux_cmd read-screen --workspace "$ws_ref" --surface "$sf_ref" --lines 5 2>/dev/null || true)
        fi
        if echo "$screen" | grep -qE '(❯|> |╭──|╰──)'; then
            log_warn "Amp may still be running, sending /exit again"
            cmux_cmd send --workspace "$ws_ref" "/exit" &>/dev/null || true
            cmux_cmd send-key --workspace "$ws_ref" "Enter" &>/dev/null || true
            sleep 3
        fi
    fi
}

# Wait for Amp's prompt to appear. Returns 0 on success, 1 on timeout.
wait_for_amp_ready() {
    local ws_ref="$1"
    local timeout="${2:-$AMP_READY_TIMEOUT}"
    local elapsed=0

    # Resolve the terminal surface (required for read-screen)
    # Retry a few times since brand-new workspaces may not have a surface immediately
    local sf_ref=""
    local sf_attempts=0
    while [[ -z "$sf_ref" ]] && (( sf_attempts < 5 )); do
        sf_ref=$(get_workspace_surface "$ws_ref" || true)
        if [[ -z "$sf_ref" ]]; then
            (( sf_attempts += 1 ))
            sleep 1
        fi
    done
    if [[ -z "$sf_ref" ]]; then
        log_error "No surface found for $ws_ref after ${sf_attempts} attempts, cannot poll for Amp prompt"
        return 1
    fi

    while (( elapsed < timeout )); do
        local screen
        screen=$(cmux_cmd read-screen --workspace "$ws_ref" --surface "$sf_ref" --lines 5 2>/dev/null || true)
        if echo "$screen" | grep -qE '(❯|> |╭──|╰──)'; then
            return 0
        fi
        sleep "$AMP_READY_POLL"
        (( elapsed += AMP_READY_POLL ))
    done

    log_error "Amp not ready after ${timeout}s in $ws_ref"
    return 1
}

# Type text into workspace and press Enter.
send_to_workspace() {
    local ws_ref="$1"
    local text="$2"

    if [[ -z "$text" ]]; then
        log_warn "Empty text for send_to_workspace, skipping"
        return 0
    fi

    cmux_cmd send --workspace "$ws_ref" "$text" &>/dev/null || {
        log_error "Failed to send text to $ws_ref"
        return 1
    }
    cmux_cmd send-key --workspace "$ws_ref" "Enter" &>/dev/null || {
        log_error "Failed to send Enter to $ws_ref"
        return 1
    }
}

# Set a sidebar status badge on a workspace.
set_workspace_status() {
    local ws_ref="$1"
    local key="$2"
    local value="$3"
    local icon="${4:-}"
    local color="${5:-}"

    local args=(set-status "$key" "$value" --workspace "$ws_ref")
    [[ -n "$icon" ]] && args+=(--icon "$icon")
    [[ -n "$color" ]] && args+=(--color "$color")

    cmux_cmd "${args[@]}" &>/dev/null || true
}

# Clear a sidebar status badge.
clear_workspace_status() {
    local ws_ref="$1"
    local key="$2"
    cmux_cmd clear-status "$key" --workspace "$ws_ref" &>/dev/null || true
}

# Reorder workspace to a specific index (0 = top).
reorder_workspace() {
    local ws_ref="$1"
    local index="$2"
    cmux_cmd reorder-workspace --workspace "$ws_ref" --index "$index" &>/dev/null || {
        log_warn "Failed to reorder $ws_ref to index $index"
    }
}

# Tell the AI agent to read and follow instructions from a file.
send_prompt_via_file() {
    local ws_ref="$1"
    local prompt_file="$2"

    if [[ ! -f "$prompt_file" ]]; then
        log_error "Prompt file not found: $prompt_file"
        return 1
    fi

    send_to_workspace "$ws_ref" "Read and follow all instructions in $prompt_file"
}

# Send prompt text directly inline to the workspace.
send_prompt_text() {
    local ws_ref="$1"
    local prompt_text="$2"
    local label="${3:-prompt}"

    send_to_workspace "$ws_ref" "$prompt_text"
}

# Run a shell command in a workspace and wait for the shell prompt to return.
# Usage: run_shell_in_workspace <ws_ref> <command> [timeout_seconds]
run_shell_in_workspace() {
    local ws_ref="$1"
    local cmd="$2"
    local timeout="${3:-120}"
    local elapsed=0

    log_info "Running in $ws_ref: $cmd"
    send_to_workspace "$ws_ref" "$cmd"

    local sf_ref
    sf_ref=$(get_workspace_surface "$ws_ref" || true)
    if [[ -z "$sf_ref" ]]; then
        log_warn "No surface for $ws_ref, sleeping 10s as fallback"
        sleep 10
        return 0
    fi

    while (( elapsed < timeout )); do
        sleep 2
        (( elapsed += 2 ))
        local screen
        screen=$(cmux_cmd read-screen --workspace "$ws_ref" --surface "$sf_ref" --lines 3 2>/dev/null || true)
        # Shell prompt returned (zsh % or bash $)
        if echo "$screen" | grep -qE '[\$%] *$'; then
            log_ok "Command completed (${elapsed}s)"
            return 0
        fi
    done

    log_warn "Command may not have finished (timeout: ${timeout}s)"
    return 0
}

# Full lifecycle: find/create workspace, reset surface, launch Amp, wait for ready.
# Prints workspace ref on success.
prepare_workspace() {
    local name="$1"
    local cwd="${2:-$REPO_ROOT}"
    local ws_ref

    ws_ref=$(find_or_create_workspace "$name" "$cwd") || return 1

    set_workspace_status "$ws_ref" "status" "booting" "" "#FFA500"

    reset_workspace_surface "$ws_ref"

    log_info "Launching Amp in: $name"
    send_to_workspace "$ws_ref" "cd $cwd && $AMP_CMD"

    if wait_for_amp_ready "$ws_ref"; then
        set_workspace_status "$ws_ref" "status" "ready" "" "#00CC00"
        log_ok "Amp ready in: $name"
    else
        set_workspace_status "$ws_ref" "status" "failed" "" "#FF0000"
        log_error "Amp failed to start in: $name"
        return 1
    fi

    echo "$ws_ref"
}

# --- Standalone CLI ---
# When invoked directly: bash cmux-helpers.sh launch <workstream-name>
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        launch)
            ws_name="${2:?Usage: cmux-helpers.sh launch <workstream-name>}"

            # Check workstreams/ first, then routines/
            if [[ -d "$REPO_ROOT/workstreams/$ws_name" ]] && [[ -f "$REPO_ROOT/workstreams/$ws_name/CONTEXT.md" ]]; then
                ws_dir="$REPO_ROOT/workstreams/$ws_name"
            elif [[ -d "$REPO_ROOT/routines/$ws_name" ]] && [[ -f "$REPO_ROOT/routines/$ws_name/CONTEXT.md" ]]; then
                ws_dir="$REPO_ROOT/routines/$ws_name"
            else
                log_error "Invalid workstream/routine: $ws_name (missing CONTEXT.md in workstreams/ or routines/)"
                exit 1
            fi

            # Default prompt (use relative path from repo root)
            ws_rel="${ws_dir#$REPO_ROOT/}"
            prompt="Read $ws_rel/CONTEXT.md and resume from the last known state. Identify open questions, pending decisions, and next concrete deliverables."

            # Override with config.yaml startup_instruction if available
            if [[ -f "$ws_dir/config.yaml" ]]; then
                startup=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
v = d.get('startup_instruction', '')
if v:
    print(v)
" "$ws_dir/config.yaml" 2>/dev/null || true)
                [[ -n "$startup" ]] && prompt="$startup"
            fi

            # Preamble: skip AGENTS.md session-start to avoid duplicate work
            preamble="IMPORTANT: Skip all AGENTS.md session-start steps (VPN, todo, memory distill, start-of-day, daemon, skill loading). You are a focused workspace launched by start-day.sh. Go straight to the task below."

            ws_ref=$(prepare_workspace "$ws_name" "$REPO_ROOT") || exit 1
            log_ok "Launched workstream: $ws_name"
            send_prompt_text "$ws_ref" "$preamble $prompt" "$ws_name"
            ;;
        *)
            echo "Usage: cmux-helpers.sh launch <workstream-name>"
            echo ""
            echo "Commands:"
            echo "  launch <name>   Open a workstream workspace and start Amp"
            exit 1
            ;;
    esac
fi
