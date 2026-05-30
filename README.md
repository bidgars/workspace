# KeepItUp Workspace

This workspace contains cross-platform keepalive scripts that periodically send small keyboard and mouse activity to keep a remote desktop session active.

## Folder Layout

- keepitup/mac/keepitup.sh
- keepitup/ubuntu/keepitup.sh
- keepitup/windows/keepitup.vbs

## Shared Behavior

- Single-instance protection using a PID file.
- Runtime logging to one common file path resolved from each script location.
- Randomized total runtime (about 9 hours).
- Optional randomized break logic (currently disabled with BREAK_COUNT=0).
- Every cycle sends left/right keys, a small mouse move, and shift key activity.
- Tries to restore focus to the previously active app/window after activity.

## Log File Location

All three scripts write logs to:

- workspace/keepalive.log

How this is computed:

- The log path is set to two levels above the script file, then keepalive.log.
- Example: keepitup/mac/keepitup.sh -> ../../keepalive.log -> workspace/keepalive.log.

## macOS

Script:

- keepitup/mac/keepitup.sh

Requirements:

- Omnissa Horizon Client running.
- Optional mouse movement support: install cliclick.

Install optional dependency:

```bash
brew install cliclick
```

Run:

```bash
chmod +x keepitup/mac/keepitup.sh
./keepitup/mac/keepitup.sh
```

## Ubuntu

Script:

- keepitup/ubuntu/keepitup.sh

Requirements:

- xdotool installed.
- Target window name currently matches sunilbi-w11.

Install dependency:

```bash
sudo apt update
sudo apt install -y xdotool
```

Run:

```bash
chmod +x keepitup/ubuntu/keepitup.sh
./keepitup/ubuntu/keepitup.sh
```

## Windows

Script:

- keepitup/windows/keepitup.vbs

Requirements:

- Windows Script Host enabled.
- PowerShell available (used internally by the script).
- Target window title currently matches sunilbi-w11.

Run from Command Prompt:

```bat
cscript //nologo keepitup\windows\keepitup.vbs
```

Run in background-style host:

```bat
wscript keepitup\windows\keepitup.vbs
```

## Tuning

Edit these values in each script if needed:

- BREAK_COUNT
- BREAK_MIN / BREAK_MAX
- INTERVAL_MIN / INTERVAL_MAX
- TOTAL_RUNTIME
- Target app/window title

## Stop or Recover

- If a script is already running, it exits and reports the PID in logs.
- PID files:
	- macOS: /tmp/keepitup.pid
	- Ubuntu: /tmp/keeplive.pid
	- Windows: %TEMP%\\keepitup.pid
- If a stale PID file remains after a crash, remove it and rerun.
