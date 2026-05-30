# KeepItUp Workspace — Agent Guide

## Structure

```
keepitup/
  mac/keepitup.sh       # osascript + cliclick (optional)
  ubuntu/keepitup.sh    # xdotool
  windows/keepitup.vbs  # WScript + PowerShell helper
keepalive.log           # log written by all scripts
```

## Non-obvious details

- **Ubuntu PID file**: `/tmp/keeplive.pid` (note the typo — not `keepitup.pid`)
- **macOS PID file**: `/tmp/keepitup.pid`, **Windows PID file**: `%TEMP%\keepitup.pid`
- **Log path**: `../../keepalive.log` relative to each script, resolves to workspace root
- **macOS mouse move** (`cliclick`) is optional; script works without it
- **Break logic** is disabled by default (`BREAK_COUNT=0`) — edit scripts to enable
- No `.gitignore`, no CI, no tests, no package manifests
- Only concerns: keep the scripts executable (`chmod +x`) and don't break the `SCRIPT_DIR` path logic if moving files
