#!/bin/bash

# Requirements: sudo apt install xdotool
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/../../keepalive.log"
PIDFILE="/tmp/keeplive.pid"

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

BREAK_COUNT=0
BREAK_MIN=800   # 13 min
BREAK_MAX=999   # 16 min
INTERVAL_MIN=$((90 * 60))   # 1.5 hours
INTERVAL_MAX=$((150 * 60))  # 2.5 hours
TOTAL_RUNTIME=$(((9 * 3600) + RANDOM % (BREAK_MAX)))  # 8.5 hours = 30600 seconds

echo "Script started at $(date)" | tee -a "$LOGFILE"

START_TIME=$(date +%s)
END_TIME=$((START_TIME + TOTAL_RUNTIME))

breaks_done=0
next_break=$((START_TIME + INTERVAL_MIN + RANDOM % (INTERVAL_MAX - INTERVAL_MIN)))

# Find all matching windows
WIN_IDS=$(xdotool search --name "sunilbi-w11" | sort)

# Try to activate the first valid one
for WIN_ID in $WIN_IDS; do
    if xdotool windowfocus $WIN_ID 2>/dev/null; then
        ACTIVE_WIN=$WIN_ID
        break
    fi
done

if [ -z "$ACTIVE_WIN" ]; then
    echo "Omnissa Horizon Client window not found." | tee -a "$LOGFILE"
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

    ORIGINAL_ACTIVE_WIN=$(xdotool getactivewindow)

    xdotool windowactivate $ACTIVE_WIN
    # Key presses with window focus
    xdotool key Left
    sleep 0.01
    xdotool key Right

    xdotool windowactivate $ACTIVE_WIN
    # Mouse move every 2 minutes
    xdotool mousemove_relative 10 10
    sleep 0.01
    xdotool mousemove_relative -- -10 -10
    xdotool key Shift
    
    xdotool windowactivate $ORIGINAL_ACTIVE_WIN
    sleep 90
    sleep 90

done

echo "Script ended at $(date)" | tee -a "$LOGFILE"
exit 0
