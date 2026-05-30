#!/bin/bash

# Requirements: brew install cliclick
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/../../keepalive.log"
PIDFILE="/tmp/keepitup.pid"

# Check if script is already running using PID file
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Script is already running with PID: $PID" | tee -a "$LOGFILE"
        exit 1
    else
        echo "Removing stale PID file" | tee -a "$LOGFILE"
        rm "$PIDFILE"
    fi
fi

# Write current PID to file
echo $$ > "$PIDFILE"

# Ensure PID file is removed on exit
trap "rm -f '$PIDFILE'" EXIT

BREAK_COUNT=3
BREAK_MIN=800   # ~13 min
BREAK_MAX=999   # ~16 min
INTERVAL_MIN=$((90 * 60))   # 1.5 hours
INTERVAL_MAX=$((150 * 60))  # 2.5 hours
TOTAL_RUNTIME=$(((9 * 3600) + RANDOM % (BREAK_MAX)))  # ~9 hours
RESTORE_ORIGINAL_FOCUS=false

echo "Script started at $(date)" | tee -a "$LOGFILE"

START_TIME=$(date +%s)
END_TIME=$((START_TIME + TOTAL_RUNTIME))

breaks_done=0
next_break=$((START_TIME + INTERVAL_MIN + RANDOM % (INTERVAL_MAX - INTERVAL_MIN)))

TARGET_APP="Omnissa Horizon Client"
TARGET_APP_BUNDLE_ID=$(osascript -e "id of application \"$TARGET_APP\"" 2>/dev/null || true)

has_accessibility_permissions() {
    osascript -l JavaScript <<'EOF' | grep -qx 'true'
ObjC.import('ApplicationServices');
$.AXIsProcessTrusted();
EOF
}

is_target_running() {
    if [ -n "$TARGET_APP_BUNDLE_ID" ]; then
        osascript -l JavaScript <<EOF | grep -q "true"
ObjC.import('AppKit');
$.NSRunningApplication.runningApplicationsWithBundleIdentifier('$TARGET_APP_BUNDLE_ID').count > 0;
EOF
        return
    fi

    pgrep -if 'Omnissa Horizon Client|VMware Horizon Client|vmware-view' >/dev/null
}

is_target_frontmost() {
    frontmost_bundle_id=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || true)
    [ "$frontmost_bundle_id" = "$TARGET_APP_BUNDLE_ID" ]
}

activate_target_app() {
    local attempt

    for attempt in 1 2 3; do
        # Use multiple focus strategies because some macOS/app states ignore a plain activate.
        osascript -e "tell application id \"$TARGET_APP_BUNDLE_ID\" to activate" 2>/dev/null || true
        open -b "$TARGET_APP_BUNDLE_ID" >/dev/null 2>&1 || true
        osascript -e "tell application \"System Events\" to set frontmost of first application process whose bundle identifier is \"$TARGET_APP_BUNDLE_ID\" to true" 2>/dev/null || true

        sleep 0.2

        if is_target_frontmost; then
            return 0
        fi
    done

    frontmost_bundle_id=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || true)
    echo "Focus failed. frontmost=$frontmost_bundle_id target=$TARGET_APP_BUNDLE_ID" | tee -a "$LOGFILE"

    return 1
}

# Check accessibility permissions for keystrokes
if ! has_accessibility_permissions; then
    echo "Accessibility permission is required for osascript/System Events keystrokes." | tee -a "$LOGFILE"
    echo "Grant Accessibility access to the app launching this script, then run it again." | tee -a "$LOGFILE"
    exit 1
fi

# Check if target app is running
if ! is_target_running; then
    echo "$TARGET_APP is not running." | tee -a "$LOGFILE"
    exit 1
fi

# Activate target app initially
if ! activate_target_app; then
    echo "Unable to focus $TARGET_APP." | tee -a "$LOGFILE"
    exit 1
fi

while [ $(date +%s) -lt $END_TIME ]; do
    current_time=$(date +%s)

    # Break handling
    if [ $breaks_done -lt $BREAK_COUNT ] && [ $current_time -ge $next_break ]; then
        break_duration=$((BREAK_MIN + RANDOM % (BREAK_MAX - BREAK_MIN)))
        echo "Break $((breaks_done+1)) started at $(date)" | tee -a "$LOGFILE"
        sleep $break_duration
        echo "Break $((breaks_done+1)) ended at $(date)" | tee -a "$LOGFILE"
        breaks_done=$((breaks_done+1))
        next_break=$((current_time + INTERVAL_MIN + RANDOM % (INTERVAL_MAX - INTERVAL_MIN)))
    fi

    # Get current active app bundle identifier for optional restore
    ORIGINAL_APP_BUNDLE_ID=""
    if [ "$RESTORE_ORIGINAL_FOCUS" = true ]; then
        ORIGINAL_APP_BUNDLE_ID=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || true)
    fi

    # Activate target app and send key presses
    if ! activate_target_app; then
        echo "Unable to focus $TARGET_APP during keepalive loop." | tee -a "$LOGFILE"
        sleep 5
        continue
    fi

    # Give focus transition a moment before sending keystrokes.
    sleep 0.2

    osascript -e 'tell application "System Events" to key code 123'  # Left arrow
    sleep 0.01
    osascript -e 'tell application "System Events" to key code 124'  # Right arrow
    osascript -e 'tell application "System Events" to key code 56'   # Shift

    # Mouse move (requires cliclick: brew install cliclick)
    if command -v cliclick &>/dev/null; then
        cliclick m:+10,+10
        sleep 0.01
        cliclick m:-10,-10
    fi

    # Restore original app focus when enabled
    if [ "$RESTORE_ORIGINAL_FOCUS" = true ] && [ -n "$ORIGINAL_APP_BUNDLE_ID" ] && [ "$ORIGINAL_APP_BUNDLE_ID" != "$TARGET_APP_BUNDLE_ID" ]; then
        osascript -e "tell application id \"$ORIGINAL_APP_BUNDLE_ID\" to activate"
        echo "Focus back to target=$ORIGINAL_APP_BUNDLE_ID" | tee -a "$LOGFILE"
    fi

    sleep 180

done

echo "Script ended at $(date)" | tee -a "$LOGFILE"
exit 0
