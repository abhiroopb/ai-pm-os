#!/usr/bin/env bash
set -euo pipefail

# start-day.sh -- Daily operating environment bootstrap
#
# One command to start your day:
#   1. Validates prerequisites (cmux, amp, jq)
#   2. Bootstraps cmux (launch if needed, optional fullscreen)
#   3. Opens Chief of Staff workspace, launches Amp
#   4. Amp creates daily note, reviews workstreams, writes plan
#   5. Script parses plan, opens recommended workstream workspaces
#   6. Prints status report, archives plan
#
# Usage: start-day.sh [--all] [--dry-run] [--no-fullscreen] [--reuse-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Export REPO_ROOT before sourcing helpers (helpers use ${REPO_ROOT:-default})
export REPO_ROOT

# shellcheck source=cmux-helpers.sh
source "$SCRIPT_DIR/cmux-helpers.sh"

# --- Constants ---
SYSTEM_DIR="$REPO_ROOT/system"
NOTES_DIR="$REPO_ROOT/notes"
DAILY_DIR="$NOTES_DIR/daily"
WORKSTREAMS_DIR="$REPO_ROOT/workstreams"
PLAN_FILE="$SYSTEM_DIR/today-plan.json"
PLANS_ARCHIVE="$SYSTEM_DIR/plans"
LOGS_DIR="$SYSTEM_DIR/logs"
COS_PROMPT="$SYSTEM_DIR/chief-of-staff-prompt.md"
COS_WORKSPACE_NAME="Chief of Staff"

TODAY=$(date +%Y-%m-%d)
PLAN_WAIT_TIMEOUT=300  # seconds
PLAN_POLL_INTERVAL=3   # seconds

# --- Flags ---
FLAG_UPGRADE=false
FLAG_ALL=false
FLAG_DRY_RUN=false
FLAG_NO_FULLSCREEN=false
FLAG_REUSE_ONLY=false

# --- State ---
WORKSTREAMS_FOUND=()
WORKSTREAMS_OPENED=()
WORKSTREAMS_SKIPPED=()
WORKSTREAMS_FAILED=()
COS_REF=""
NOTE_PATH=""
IS_FIRST_RUN=false

# ============================================================================
# CLI
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --upgrade)       log_info "--upgrade is now default (ignored)" ;;
            --all)           FLAG_ALL=true ;;
            --dry-run)       FLAG_DRY_RUN=true ;;
            --no-fullscreen) FLAG_NO_FULLSCREEN=true ;;
            --reuse-only)    FLAG_REUSE_ONLY=true ;;
            -h|--help)       print_usage; exit 0 ;;
            *)               log_error "Unknown flag: $1"; print_usage; exit 1 ;;
        esac
        shift
    done
}

print_usage() {
    cat <<'USAGE'
Usage: start-day.sh [OPTIONS]

Bootstrap your daily operating environment in cmux.

Options:
  --upgrade        (no-op, upgrade always runs)
  --all            Open all valid workstreams (ignore Chief of Staff selection)
  --dry-run        Show what would happen without mutating anything
  --no-fullscreen  Skip fullscreen attempt
  --reuse-only     Only reuse existing workspaces, do not create new ones
  -h, --help       Show this help
USAGE
}

# ============================================================================
# Logging setup
# ============================================================================

setup_logging() {
    mkdir -p "$LOGS_DIR"
    local log_file="$LOGS_DIR/$TODAY.log"
    # Tee all output to log file and stdout
    exec > >(tee -a "$log_file") 2>&1
    log_info "=========================================="
    log_info "Start of day: $TODAY"
    log_info "Log file: $log_file"
    log_info "=========================================="
}

# ============================================================================
# First-run detection
# ============================================================================

detect_first_run() {
    if [[ ! -d "$DAILY_DIR" ]] || [[ ! -d "$PLANS_ARCHIVE" ]] || \
       [[ -z "$(ls -A "$PLANS_ARCHIVE" 2>/dev/null)" ]]; then
        IS_FIRST_RUN=true
    fi
}

print_welcome() {
    cat <<'WELCOME'

+======================================================+
|          Welcome to your Start-of-Day System          |
+======================================================+
|                                                       |
|  This is your first run. Here's what will happen:     |
|                                                       |
|  1. Create notes/daily/ for your daily notes          |
|  2. Create system/plans/ for plan archives            |
|  3. Open Chief of Staff workspace in cmux             |
|  4. Amp generates config.yaml for each workstream     |
|     (based on existing CONTEXT.md files)              |
|  5. Amp creates today's daily note                    |
|  6. Amp recommends which workstreams to open          |
|  7. Script opens recommended workstream workspaces    |
|                                                       |
|  Tip: Run with --dry-run first to preview.            |
|                                                       |
+======================================================+

WELCOME
}

# ============================================================================
# Phase 1: Discovery
# ============================================================================

phase_1_discover() {
    log_info "Phase 1: Discovery"

    # Hard prerequisites
    if [[ ! -d "$REPO_ROOT" ]]; then
        log_error "Repo root not found: $REPO_ROOT"
        exit 1
    fi
    if [[ ! -x "$CMUX_BIN" ]]; then
        log_error "cmux binary not found or not executable: $CMUX_BIN"
        exit 1
    fi
    if ! command -v amp >/dev/null 2>&1; then
        log_error "amp CLI not found in PATH"
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not found (install with: brew install jq)"
        exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "python3 not found"
        exit 1
    fi
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_error "PyYAML not found (install with: pip3 install pyyaml)"
        exit 1
    fi
    if [[ ! -f "$COS_PROMPT" ]]; then
        log_error "Chief of Staff prompt not found: $COS_PROMPT"
        exit 1
    fi

    log_ok "Prerequisites validated"

    # Discover workstreams (directories with CONTEXT.md, excluding shared/)
    local ws_dir ws_name
    for ws_dir in "$WORKSTREAMS_DIR"/*/; do
        [[ ! -d "$ws_dir" ]] && continue
        ws_name=$(basename "$ws_dir")
        [[ "$ws_name" == "shared" ]] && continue
        [[ -f "$ws_dir/CONTEXT.md" ]] || continue
        WORKSTREAMS_FOUND+=("$ws_name")
    done

    log_info "Found ${#WORKSTREAMS_FOUND[@]} workstreams: ${WORKSTREAMS_FOUND[*]+"${WORKSTREAMS_FOUND[*]}"}"

    # Ensure directories exist
    mkdir -p "$DAILY_DIR" "$PLANS_ARCHIVE" "$LOGS_DIR" "$NOTES_DIR/sensitive"

    NOTE_PATH="$DAILY_DIR/$TODAY.md"

    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Daily note path: $NOTE_PATH"
        [[ -f "$NOTE_PATH" ]] && log_info "[DRY RUN] Note already exists (will skip creation)"

        log_info "[DRY RUN] Workstream configs:"
        for ws_name in ${WORKSTREAMS_FOUND[@]+"${WORKSTREAMS_FOUND[@]}"}; do
            local cfg="$WORKSTREAMS_DIR/$ws_name/config.yaml"
            if [[ -f "$cfg" ]]; then
                local priority
                priority=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('priority', 'unknown'))
" "$cfg" 2>/dev/null || echo "unknown")
                log_info "  $ws_name: config.yaml exists (priority=$priority)"
            else
                log_info "  $ws_name: no config.yaml (will be generated on first run)"
            fi
        done
    fi
}

# ============================================================================
# Phase 2: cmux Bootstrap
# ============================================================================

phase_2_cmux_bootstrap() {
    log_info "Phase 2: cmux bootstrap"

    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        if cmux_cmd ping >/dev/null 2>&1; then
            log_info "[DRY RUN] cmux is running"
            local ws_list
            ws_list=$(cmux_cmd list-workspaces 2>/dev/null || true)
            local ws_count
            ws_count=$(echo "$ws_list" | grep -c 'workspace:' || true)
            log_info "[DRY RUN] Found $ws_count existing workspace(s) (will be cleaned in Phase 2b)"
        else
            log_info "[DRY RUN] cmux not running, would launch"
        fi
        return 0
    fi

    # Check if cmux is responding
    if ! cmux_cmd ping >/dev/null 2>&1; then
        log_info "cmux not responding, launching..."
        open -a cmux
        local elapsed=0
        while ! cmux_cmd ping >/dev/null 2>&1; do
            sleep 1
            (( elapsed += 1 ))
            if (( elapsed > 60 )); then
                log_error "cmux failed to start after 60s"
                log_error ""
                log_error "This usually means cmux's Socket Control Mode is set to 'cmux only',"
                log_error "which blocks connections from external terminals."
                log_error ""
                log_error "Fix: cmux Settings > Automation > Socket Control Mode > 'Full open access'"
                exit 1
            fi
        done
        log_ok "cmux started (${elapsed}s)"
    else
        log_ok "cmux already running"
    fi

    # Best-effort fullscreen
    if [[ "$FLAG_NO_FULLSCREEN" != "true" ]]; then
        osascript -e 'tell application "cmux" to activate' 2>/dev/null || true
        osascript -e '
            tell application "System Events"
                tell process "cmux"
                    try
                        set value of attribute "AXFullScreen" of window 1 to true
                    end try
                end tell
            end tell
        ' 2>/dev/null || log_warn "Fullscreen failed (non-critical)"
    fi
}

# ============================================================================
# Phase 2b: Clean up stale workspaces
# ============================================================================

phase_2b_cleanup_workspaces() {
    log_info "Phase 2b: Cleaning stale workspaces"

    local ws_list
    ws_list=$(cmux_cmd list-workspaces 2>/dev/null || true)

    if [[ -z "$ws_list" ]]; then
        log_info "No existing workspaces to clean"
        return 0
    fi

    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ref
        ref=$(echo "$line" | grep -oE 'workspace:[0-9]+' || true)
        [[ -z "$ref" ]] && continue

        local ws_name
        ws_name=$(echo "$line" | sed -E 's/^[* ]*workspace:[0-9]+  //' | sed 's/ *\[selected\]$//')

        if [[ "$FLAG_DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would close: $ws_name ($ref)"
        else
            log_info "Closing stale workspace: $ws_name ($ref)"
            cmux_cmd close-workspace --workspace "$ref" &>/dev/null || {
                log_warn "Failed to close: $ws_name ($ref)"
            }
        fi
        (( count += 1 ))
    done <<< "$ws_list"

    if (( count > 0 )); then
        log_ok "Cleaned $count stale workspace(s)"
        # Brief pause to let cmux settle after closing workspaces
        [[ "$FLAG_DRY_RUN" != "true" ]] && sleep 1 || true
    else
        log_info "No stale workspaces found"
    fi
}

# ============================================================================
# Optional: Upgrade
# ============================================================================

upgrade_amp() {
    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would upgrade amp"
        return 0
    fi

    log_info "Upgrading amp..."
    if amp upgrade 2>&1; then
        log_ok "amp upgraded"
    else
        log_warn "amp upgrade failed (non-critical, continuing)"
    fi
}

# ============================================================================
# Phase 3: Chief of Staff Bootstrap
# ============================================================================

phase_3_chief_of_staff() {
    log_info "Phase 3: Chief of Staff bootstrap"

    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would prepare workspace: $COS_WORKSPACE_NAME"
        if find_workspace_by_name "$COS_WORKSPACE_NAME" >/dev/null 2>&1; then
            log_info "[DRY RUN] Workspace exists, would reuse + reset surface"
        else
            log_info "[DRY RUN] Workspace missing, would create"
        fi
        log_info "[DRY RUN] Would send prompt: $COS_PROMPT"
        [[ -f "$NOTE_PATH" ]] && log_info "[DRY RUN] Note exists, would add skip-creation preamble"
        return 0
    fi

    # Remove stale plan file from a prior run
    rm -f "$PLAN_FILE"

    # Prepare the workspace
    COS_REF=$(find_or_create_workspace "$COS_WORKSPACE_NAME" "$REPO_ROOT") || {
        log_error "Failed to initialize Chief of Staff -- cannot continue"
        exit 1
    }

    set_workspace_status "$COS_REF" "status" "booting" "" "#FFA500"
    reset_workspace_surface "$COS_REF"

    # Now launch Amp
    log_info "Launching Amp in: $COS_WORKSPACE_NAME"
    send_to_workspace "$COS_REF" "cd $REPO_ROOT && $AMP_CMD"

    if wait_for_amp_ready "$COS_REF"; then
        set_workspace_status "$COS_REF" "status" "ready" "" "#00CC00"
        log_ok "Amp ready in: $COS_WORKSPACE_NAME"
    else
        set_workspace_status "$COS_REF" "status" "failed" "" "#FF0000"
        log_error "Amp failed to start in: $COS_WORKSPACE_NAME"
        exit 1
    fi

    # Pin to top of sidebar
    reorder_workspace "$COS_REF" 0

    # Set sidebar badges
    set_workspace_status "$COS_REF" "role" "Chief of Staff" "" "#4A90D9"
    set_workspace_status "$COS_REF" "status" "orienting" "" "#FFA500"

    # Build and send prompt
    if [[ -f "$NOTE_PATH" ]]; then
        # Second run today: skip note creation
        log_info "Daily note already exists, sending refresh prompt"
        local refresh_prompt
        refresh_prompt="Today's daily note already exists at $NOTE_PATH. Skip note creation (Step 2). Read it for context, then proceed directly to Step 3 (workstream review) and Step 4 (plan emission). Follow the remaining instructions in $COS_PROMPT"
        send_prompt_text "$COS_REF" "$refresh_prompt" "cos-refresh"
    else
        log_info "Sending full Chief of Staff prompt"
        send_prompt_via_file "$COS_REF" "$COS_PROMPT"
    fi

    set_workspace_status "$COS_REF" "status" "thinking" "" "#FFA500"
}

# ============================================================================
# Phase 4: Wait for Plan
# ============================================================================

phase_4_wait_for_plan() {
    log_info "Phase 4: Waiting for plan file ($PLAN_FILE)"

    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would poll for plan file (timeout: ${PLAN_WAIT_TIMEOUT}s)"
        return 0
    fi

    local elapsed=0

    while (( elapsed < PLAN_WAIT_TIMEOUT )); do
        # Check: file exists AND valid JSON AND has required field
        if [[ -f "$PLAN_FILE" ]] && \
           jq -e '.workstreams_to_open' "$PLAN_FILE" >/dev/null 2>&1; then
            log_ok "Valid plan received (${elapsed}s)"
            set_workspace_status "$COS_REF" "status" "plan ready" "" "#00CC00"
            return 0
        fi

        sleep "$PLAN_POLL_INTERVAL"
        (( elapsed += PLAN_POLL_INTERVAL ))

        # Progress indicator every 30s
        if (( elapsed % 30 == 0 )); then
            log_info "Waiting for plan... (${elapsed}s / ${PLAN_WAIT_TIMEOUT}s)"
        fi
    done

    # Fallback: no valid plan
    log_warn "============================================"
    log_warn "No valid plan after ${PLAN_WAIT_TIMEOUT}s"
    log_warn "Check the Chief of Staff workspace manually."
    log_warn "============================================"

    # Dump what Chief of Staff has said so far
    log_warn "Chief of Staff screen output:"
    echo "---"
    local cos_sf
    cos_sf=$(get_workspace_surface "$COS_REF" 2>/dev/null || true)
    if [[ -n "$cos_sf" ]]; then
        cmux_cmd read-screen --workspace "$COS_REF" --surface "$cos_sf" --scrollback 2>/dev/null || echo "(could not read screen)"
    else
        echo "(could not resolve surface)"
    fi
    echo "---"

    set_workspace_status "$COS_REF" "status" "plan failed" "" "#FF0000"

    # Fallback: launch high-priority workstreams from config.yaml
    log_warn "Falling back to config.yaml-based workstream selection"
    phase_5_fallback_launch
    phase_6_report
    exit 1
}

# Fallback when plan file is missing: launch workstreams with priority=high in config.yaml
phase_5_fallback_launch() {
    log_info "Fallback: scanning config.yaml for high-priority workstreams"

    local ws_name priority
    for ws_name in ${WORKSTREAMS_FOUND[@]+"${WORKSTREAMS_FOUND[@]}"}; do
        local cfg="$WORKSTREAMS_DIR/$ws_name/config.yaml"
        [[ -f "$cfg" ]] || continue

        priority=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)
print(d.get('priority', 'medium'))
" "$cfg" 2>/dev/null || echo "medium")

        if [[ "$priority" == "high" ]]; then
            log_info "Fallback launching: $ws_name (priority=high)"
            launch_single_workstream "$ws_name" "" "high"
        fi
    done
}

# ============================================================================
# Phase 4b: Launch Routines (independent of plan)
# ============================================================================

phase_4b_launch_routines() {
    log_info "Phase 4b: Launching routines"

    local routines_dir="$REPO_ROOT/routines"
    if [[ ! -d "$routines_dir" ]]; then
        log_info "No routines directory found, skipping"
        return 0
    fi

    local routine_dir routine_name
    for routine_dir in "$routines_dir"/*/; do
        [[ ! -d "$routine_dir" ]] && continue
        routine_name=$(basename "$routine_dir")
        [[ -f "$routine_dir/CONTEXT.md" ]] || continue

        if [[ "$FLAG_DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would launch routine: $routine_name"
            continue
        fi

        log_info "Launching routine: $routine_name"
        launch_single_workstream "$routine_name" "" "high"
    done
}

# ============================================================================
# Phase 5: Launch Workstreams
# ============================================================================

phase_5_launch_workstreams() {
    log_info "Phase 5: Launching workstreams"

    # --- 5a: Routines already launched in phase_4b, skip here ---

    # --- 5b: Launch workstreams from plan ---
    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        if [[ "$FLAG_ALL" == "true" ]]; then
            log_info "[DRY RUN] --all: would launch all ${#WORKSTREAMS_FOUND[@]} workstreams"
        else
            log_info "[DRY RUN] Would launch workstreams from plan file"
        fi
        for ws_name in ${WORKSTREAMS_FOUND[@]+"${WORKSTREAMS_FOUND[@]}"}; do
            WORKSTREAMS_OPENED+=("$ws_name [dry-run]")
        done
        return 0
    fi

    if [[ "$FLAG_ALL" == "true" ]]; then
        log_info "Flag --all: launching all discovered workstreams"
        for ws_name in ${WORKSTREAMS_FOUND[@]+"${WORKSTREAMS_FOUND[@]}"}; do
            launch_single_workstream "$ws_name" "" "medium"
        done
        return 0
    fi

    # Read from plan
    local count
    count=$(jq -r '.workstreams_to_open | length' "$PLAN_FILE")

    if (( count == 0 )); then
        log_info "No workstreams to open today"
    else
        local i
        for (( i = 0; i < count; i++ )); do
            local ws_name ws_prompt ws_priority
            ws_name=$(jq -r ".workstreams_to_open[$i].name" "$PLAN_FILE")
            ws_prompt=$(jq -r ".workstreams_to_open[$i].prompt" "$PLAN_FILE")
            ws_priority=$(jq -r ".workstreams_to_open[$i].priority // \"medium\"" "$PLAN_FILE")
            launch_single_workstream "$ws_name" "$ws_prompt" "$ws_priority"
        done
    fi

    # Track skipped workstreams from plan
    local skip_count
    skip_count=$(jq -r '.workstreams_skipped | length' "$PLAN_FILE" 2>/dev/null || echo 0)
    local i
    for (( i = 0; i < skip_count; i++ )); do
        local skip_name skip_reason
        skip_name=$(jq -r ".workstreams_skipped[$i].display_name // .workstreams_skipped[$i].name" "$PLAN_FILE")
        skip_reason=$(jq -r ".workstreams_skipped[$i].reason" "$PLAN_FILE")
        WORKSTREAMS_SKIPPED+=("$skip_name ($skip_reason)")
    done
}

launch_single_workstream() {
    local ws_name="$1"
    local ws_prompt="$2"
    local ws_priority="${3:-medium}"

    log_info "Launching: $ws_name (priority: $ws_priority)"

    if [[ "$FLAG_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would launch: $ws_name"
        WORKSTREAMS_OPENED+=("$ws_name")
        return 0
    fi

    # --reuse-only: skip if workspace doesn't already exist
    if [[ "$FLAG_REUSE_ONLY" == "true" ]]; then
        if ! find_workspace_by_name "$ws_name" >/dev/null 2>&1; then
            log_warn "Skipping $ws_name (--reuse-only, no existing workspace)"
            WORKSTREAMS_SKIPPED+=("$ws_name (no existing workspace)")
            return 0
        fi
    fi

    # Prepare workspace (find/create, reset, launch Amp, wait for ready)
    local ws_ref
    if ! ws_ref=$(prepare_workspace "$ws_name" "$REPO_ROOT"); then
        log_warn "Failed to launch: $ws_name"
        WORKSTREAMS_FAILED+=("$ws_name")
        return 0  # soft failure, continue with others
    fi

    # Send workstream prompt
    # Determine the correct path (workstreams/ or routines/)
    local ws_context_dir="workstreams"
    if [[ -d "$REPO_ROOT/routines/$ws_name" ]]; then
        ws_context_dir="routines"
    fi

    # Preamble: skip AGENTS.md session-start to avoid duplicate triage/todo/skill loading
    local preamble="IMPORTANT: Skip all AGENTS.md session-start steps (VPN, todo, memory distill, start-of-day, daemon, skill loading). You are a focused workspace launched by start-day.sh. Go straight to the task below."

    if [[ -n "$ws_prompt" && "$ws_prompt" != "null" ]]; then
        send_prompt_text "$ws_ref" "$preamble $ws_prompt" "$ws_name"
    else
        local default_prompt="Read $ws_context_dir/$ws_name/CONTEXT.md and resume from the last known state. Identify open questions, pending decisions, and next concrete deliverables."
        send_prompt_text "$ws_ref" "$preamble $default_prompt" "$ws_name"
    fi

    set_workspace_status "$ws_ref" "status" "active" "" "#00CC00"
    WORKSTREAMS_OPENED+=("$ws_name")
    log_ok "Launched: $ws_name"
}

# ============================================================================
# Phase 6: Archive & Report
# ============================================================================

phase_6_archive_and_report() {
    # Archive today's plan
    if [[ -f "$PLAN_FILE" && "$FLAG_DRY_RUN" != "true" ]]; then
        cp "$PLAN_FILE" "$PLANS_ARCHIVE/$TODAY.json"
        log_info "Plan archived: $PLANS_ARCHIVE/$TODAY.json"
    fi

    # Update Chief of Staff status
    if [[ -n "$COS_REF" && "$FLAG_DRY_RUN" != "true" ]]; then
        set_workspace_status "$COS_REF" "status" "ready" "" "#00CC00"
    fi

    phase_6_report
}

phase_6_report() {
    echo ""
    echo "+======================================================+"
    echo "|            Start of Day -- Status Report              |"
    echo "+======================================================+"
    echo "|  Date:            $TODAY"
    echo "|  Chief of Staff:  ${COS_REF:-not started}"

    if [[ -f "$NOTE_PATH" ]]; then
        echo "|  Daily note:      $NOTE_PATH (exists)"
    else
        echo "|  Daily note:      $NOTE_PATH (pending CoS creation)"
    fi

    echo "|"

    local opened_count="${#WORKSTREAMS_OPENED[@]:-0}"
    local skipped_count="${#WORKSTREAMS_SKIPPED[@]:-0}"
    local failed_count="${#WORKSTREAMS_FAILED[@]:-0}"

    if [[ "$opened_count" -gt 0 ]]; then
        echo "|  Opened:"
        for ws in ${WORKSTREAMS_OPENED[@]+"${WORKSTREAMS_OPENED[@]}"}; do
            echo "|    + $ws"
        done
    fi

    if [[ "$skipped_count" -gt 0 ]]; then
        echo "|  Skipped:"
        for ws in ${WORKSTREAMS_SKIPPED[@]+"${WORKSTREAMS_SKIPPED[@]}"}; do
            echo "|    - $ws"
        done
    fi

    if [[ "$failed_count" -gt 0 ]]; then
        echo "|  Failed:"
        for ws in ${WORKSTREAMS_FAILED[@]+"${WORKSTREAMS_FAILED[@]}"}; do
            echo "|    x $ws"
        done
    fi

    echo "|"
    echo "|  Workstreams available: ${#WORKSTREAMS_FOUND[@]}"
    echo "+======================================================+"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    parse_args "$@"
    setup_logging
    detect_first_run

    if [[ "$IS_FIRST_RUN" == "true" ]]; then
        print_welcome
    fi

    phase_1_discover

    upgrade_amp

    phase_2_cmux_bootstrap
    phase_2b_cleanup_workspaces
    phase_3_chief_of_staff
    phase_4b_launch_routines
    phase_4_wait_for_plan
    phase_5_launch_workstreams
    phase_6_archive_and_report

    log_ok "Start of day complete"
}

main "$@"
