' Requirements: None (uses built-in Windows scripting)
' Run with: wscript keepitup.vbs
Option Explicit

Dim fso, shell, wmi
Set fso    = CreateObject("Scripting.FileSystemObject")
Set shell  = CreateObject("WScript.Shell")
Set wmi    = GetObject("winmgmts://./root/cimv2")

Const TARGET_WINDOW = "sunilbi-w11"

Dim LOGFILE, PIDFILE
LOGFILE  = fso.BuildPath(fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName)), "keepalive.log")
PIDFILE  = shell.ExpandEnvironmentStrings("%TEMP%") & "\keepitup.pid"

' Ensure log directory exists
If Not fso.FolderExists(fso.GetParentFolderName(LOGFILE)) Then
    fso.CreateFolder fso.GetParentFolderName(LOGFILE)
End If

' --- Single instance check ---
If fso.FileExists(PIDFILE) Then
    Dim existingPid
    existingPid = Trim(ReadFile(PIDFILE))
    Dim procs
    Set procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & existingPid)
    If procs.Count > 0 Then
        LogMsg "Script is already running with PID: " & existingPid
        WScript.Quit 1
    Else
        LogMsg "Removing stale PID file"
        fso.DeleteFile PIDFILE
    End If
End If

' Write current PID to lock file
WriteFile PIDFILE, CStr(WScript.ProcessID)

' --- Configuration ---
Randomize

Dim BREAK_COUNT, BREAK_MIN, BREAK_MAX, INTERVAL_MIN, INTERVAL_MAX, TOTAL_RUNTIME
BREAK_COUNT   = 0
BREAK_MIN     = 800    ' ~13 min
BREAK_MAX     = 999    ' ~16 min
INTERVAL_MIN  = 90 * 60    ' 1.5 hours in seconds
INTERVAL_MAX  = 150 * 60   ' 2.5 hours in seconds
TOTAL_RUNTIME = (9 * 3600) + Int(Rnd() * BREAK_MAX)   ' ~9 hours

LogMsg "Script started at " & Now()

Dim startDT, endDT
startDT = Now()
endDT   = DateAdd("s", TOTAL_RUNTIME, startDT)

Dim breaksDone
breaksDone = 0
Dim nextBreak
nextBreak = DateAdd("s", INTERVAL_MIN + Int(Rnd() * (INTERVAL_MAX - INTERVAL_MIN)), startDT)

' --- Check target window exists ---
If Not shell.AppActivate(TARGET_WINDOW) Then
    LogMsg "Window '" & TARGET_WINDOW & "' not found."
    fso.DeleteFile PIDFILE
    WScript.Quit 1
End If

' --- Main loop ---
Do While Now() < endDT

    ' Break handling
    If breaksDone < BREAK_COUNT And Now() >= nextBreak Then
        Dim breakDuration
        breakDuration = BREAK_MIN + Int(Rnd() * (BREAK_MAX - BREAK_MIN))
        LogMsg "Break " & (breaksDone + 1) & " started at " & Now()
        WScript.Sleep breakDuration * 1000
        LogMsg "Break " & (breaksDone + 1) & " ended at " & Now()
        breaksDone = breaksDone + 1
        nextBreak = DateAdd("s", INTERVAL_MIN + Int(Rnd() * (INTERVAL_MAX - INTERVAL_MIN)), Now())
    End If

    ' Save current foreground window title
    Dim originalTitle
    originalTitle = GetForegroundWindowTitle()

    ' Activate target window and send key presses
    shell.AppActivate TARGET_WINDOW
    WScript.Sleep 200
    shell.SendKeys "{LEFT}"
    WScript.Sleep 10
    shell.SendKeys "{RIGHT}"

    ' Mouse move (relative)
    MoveMouseRelative 10, 10
    WScript.Sleep 10
    MoveMouseRelative -10, -10

    shell.SendKeys "+"   ' Shift key

    ' Restore original window focus
    If originalTitle <> "" And InStr(1, originalTitle, TARGET_WINDOW, vbTextCompare) = 0 Then
        shell.AppActivate originalTitle
    End If

    WScript.Sleep 90000
    WScript.Sleep 90000

Loop

LogMsg "Script ended at " & Now()
fso.DeleteFile PIDFILE
WScript.Quit 0

' =============================================================================
' Helper functions
' =============================================================================

Sub LogMsg(msg)
    Dim logStream
    Set logStream = fso.OpenTextFile(LOGFILE, 8, True)   ' 8 = append, True = create
    logStream.WriteLine msg
    logStream.Close
    WScript.Echo msg
End Sub

Function ReadFile(path)
    Dim f
    Set f = fso.OpenTextFile(path, 1)
    ReadFile = f.ReadAll()
    f.Close
End Function

Sub WriteFile(path, content)
    Dim f
    Set f = fso.OpenTextFile(path, 2, True)   ' 2 = overwrite
    f.Write content
    f.Close
End Sub

' Returns the title of the current foreground window using a temp PowerShell script
Function GetForegroundWindowTitle()
    Dim psFile, outFile, f

    psFile = shell.ExpandEnvironmentStrings("%TEMP%") & "\keepitup_gfw.ps1"
    outFile = shell.ExpandEnvironmentStrings("%TEMP%") & "\keepitup_gfw.txt"

    Set f = fso.OpenTextFile(psFile, 2, True)
    f.WriteLine "try {"
    f.WriteLine "  Add-Type -Name WinAPI -Namespace KU -MemberDefinition '"
    f.WriteLine "    [DllImport(""user32.dll"")] public static extern IntPtr GetForegroundWindow();"
    f.WriteLine "    [DllImport(""user32.dll"")] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);'"
    f.WriteLine "  -ErrorAction Stop"
    f.WriteLine "} catch {}"
    f.WriteLine "$h = [KU.WinAPI]::GetForegroundWindow()"
    f.WriteLine "$s = New-Object System.Text.StringBuilder 256"
    f.WriteLine "[KU.WinAPI]::GetWindowText($h, $s, 256) | Out-Null"
    f.WriteLine "$s.ToString() | Out-File -FilePath '" & outFile & "' -Encoding UTF8 -NoNewline"
    f.Close

    shell.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & psFile & """", 0, True

    If fso.FileExists(outFile) Then
        Set f = fso.OpenTextFile(outFile, 1)
        GetForegroundWindowTitle = Trim(f.ReadAll())
        f.Close
        fso.DeleteFile outFile
    Else
        GetForegroundWindowTitle = ""
    End If
End Function

' Moves the mouse cursor by (dx, dy) pixels relative to its current position
Sub MoveMouseRelative(dx, dy)
    Dim psCmd
    psCmd = "powershell -NoProfile -Command """ & _
        "Add-Type -AssemblyName System.Windows.Forms; " & _
        "$p = [System.Windows.Forms.Cursor]::Position; " & _
        "[System.Windows.Forms.Cursor]::Position = " & _
        "New-Object System.Drawing.Point(($p.X + " & dx & "), ($p.Y + " & dy & "))"""
    shell.Run psCmd, 0, True
End Sub
