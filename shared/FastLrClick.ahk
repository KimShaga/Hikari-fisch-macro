; ============================================================================
;  Hikari's Edited Fisch Macro — window-use (fast L/R click) helper
; ============================================================================
#Requires AutoHotkey v2.0

; Same behavior as tools/fast_lr_click.ahk, but in-process so F1 is not stolen
; by a child script (which was showing "연타 OFF" ToolTip over our UI tip).
global g_WindowUseClickRunning := false
global g_WindowUseUseLeft := true
global g_WindowUseIntervalMs := 1
global g_WindowUseAlternate := true

EnsureWindowUseClickerExitHook() {
    static hooked := false
    if hooked
        return
    hooked := true
    OnExit(StopWindowUseClickerOnExit)
}

StopWindowUseClickerOnExit(*) {
    StopWindowUseClicker()
}

IsWindowUseEnabled() {
    global MAIN
    return MAIN.Has("window_use_enabled") && MAIN["window_use_enabled"]
}

IsWindowUseClickerRunning() {
    global g_WindowUseClickRunning
    return g_WindowUseClickRunning
}

StartWindowUseMacro() {
    global Macro

    EnsureWindowUseClickerExitHook()
    if !StartWindowUseClicker()
        return

    Macro.cycleEnabled := true
    Macro.phase := "WINDOW"
    Macro.powerPercent := ""
    Macro.progressPercent := ""
    UpdateMacroStatus("창 사용", "---", "---")
}

StopWindowUseMacro(clearTip := true) {
    global Macro

    StopWindowUseClicker()
    if (IsSet(Macro) && Macro) {
        Macro.cycleEnabled := false
        if (Macro.phase = "WINDOW")
            Macro.phase := "OFF"
        Macro.powerPercent := ""
        Macro.progressPercent := ""
    }
    try UpdateMacroStatus("OFF", "---", "---")
    if (clearTip)
        try StopMacroMouseTip()
}

StartWindowUseClicker() {
    global g_WindowUseClickRunning, g_WindowUseUseLeft, g_WindowUseIntervalMs

    if !IsWindowUseEnabled()
        return false

    ; Clear any leftover external helper from older builds.
    _KillFastLrClickOrphans()

    if g_WindowUseClickRunning
        return true

    g_WindowUseUseLeft := true
    g_WindowUseClickRunning := true
    SetTimer(WindowUseSpamClick, Max(1, g_WindowUseIntervalMs + 0))
    return true
}

StopWindowUseClicker() {
    global g_WindowUseClickRunning

    SetTimer(WindowUseSpamClick, 0)
    g_WindowUseClickRunning := false
    _KillFastLrClickOrphans()
}

WindowUseSpamClick() {
    global g_WindowUseAlternate, g_WindowUseUseLeft, g_WindowUseClickRunning

    if !g_WindowUseClickRunning {
        SetTimer(WindowUseSpamClick, 0)
        return
    }

    if g_WindowUseAlternate {
        if g_WindowUseUseLeft
            Click("Left")
        else
            Click("Right")
        g_WindowUseUseLeft := !g_WindowUseUseLeft
    } else {
        Click("Left")
        Click("Right")
    }
}

_KillPid(pid) {
    if !(pid && ProcessExist(pid))
        return
    DetectHiddenWindows(true)
    try WinClose("ahk_pid " pid)
    Sleep(30)
    if ProcessExist(pid) {
        try ProcessClose(pid)
        catch {
            try Run("taskkill /PID " pid " /F /T", , "Hide")
        }
    }
}

_KillFastLrClickOrphans() {
    needle := "fast_lr_click.ahk"
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery(
            "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name LIKE 'AutoHotkey%'") {
            cmd := proc.CommandLine
            if (cmd != "" && InStr(cmd, needle))
                _KillPid(proc.ProcessId + 0)
        }
    } catch {
    }
}
