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
    if !(MAIN.Has("window_use_enabled"))
        return false
    return (MAIN["window_use_enabled"] + 0) ? true : false
}

IsWindowUseClickerRunning() {
    global g_WindowUseClickRunning
    return g_WindowUseClickRunning
}

StartWindowUseMacro() {
    global Macro

    if !IsWindowUseEnabled()
        return

    EnsureWindowUseClickerExitHook()
    ; Do not start clicking yet — MacroLoop waits for stab GUI + start delay.
    StopWindowUseClicker()

    Macro.cycleEnabled := true
    Macro.phase := "WINDOW"
    Macro.powerPercent := ""
    Macro.progressPercent := ""
    UpdateMacroStatus("창 사용", "대기", "---")
    try UpdateWindowHarpoonStatusUi()
    catch {
    }
}

StopWindowUseMacro(clearTip := true) {
    global Macro

    StopWindowUseClicker()
    try ResetStabMinigameStartWatch()
    catch {
    }
    if (IsSet(Macro) && Macro) {
        Macro.cycleEnabled := false
        if (Macro.phase = "WINDOW")
            Macro.phase := "OFF"
        Macro.powerPercent := ""
        Macro.progressPercent := ""
    }
    try UpdateMacroStatus("OFF", "---", "---")
    try UpdateWindowHarpoonStatusUi()
    catch {
    }
    if (clearTip)
        try StopMacroMouseTip()
}

StartWindowUseClicker() {
    global g_WindowUseClickRunning, g_WindowUseUseLeft, g_WindowUseIntervalMs

    if !IsWindowUseEnabled()
        return false

    _KillFastLrClickOrphans()

    if g_WindowUseClickRunning
        return true

    try ReleaseMouse(true)
    catch {
    }
    try ReleaseRightMouse(true)
    catch {
    }
    try Send("{LButton up}{RButton up}")
    catch {
    }

    g_WindowUseUseLeft := true
    g_WindowUseClickRunning := true
    SetTimer(WindowUseSpamClick, Max(1, g_WindowUseIntervalMs + 0))
    return true
}

StopWindowUseClicker() {
    global g_WindowUseClickRunning

    SetTimer(WindowUseSpamClick, 0)
    g_WindowUseClickRunning := false
    try Send("{LButton up}{RButton up}")
    catch {
    }
    _KillFastLrClickOrphans()
}

; Fast L/R alternate (original). No bar-direction reads.
SendStabMouseButton(side) {
    global RBLX_PID
    static lastActivateAt := 0

    hwnd := 0
    try {
        if (RBLX_PID)
            hwnd := WinExist("ahk_pid " RBLX_PID)
    } catch {
        hwnd := 0
    }

    if (hwnd) {
        try {
            if (!WinActive("ahk_id " hwnd) && (A_TickCount - lastActivateAt) >= 400) {
                WinActivate("ahk_id " hwnd)
                lastActivateAt := A_TickCount
            }
        } catch {
        }
    }

    try {
        if (side = "Right")
            Send("{RButton}")
        else
            Send("{LButton}")
    } catch {
    }
}

WindowUseSpamClick() {
    global g_WindowUseAlternate, g_WindowUseUseLeft, g_WindowUseClickRunning

    if !g_WindowUseClickRunning {
        SetTimer(WindowUseSpamClick, 0)
        return
    }

    ; Toggle / phase may turn off while the timer is still armed.
    if !IsWindowUseEnabled() {
        StopWindowUseClicker()
        return
    }

    if g_WindowUseAlternate {
        if g_WindowUseUseLeft
            SendStabMouseButton("Left")
        else
            SendStabMouseButton("Right")
        g_WindowUseUseLeft := !g_WindowUseUseLeft
    } else {
        SendStabMouseButton("Left")
        SendStabMouseButton("Right")
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

; ── 작살총 ───────────────────────────────────────────────
IsHarpoonUseEnabled() {
    global MAIN
    return MAIN.Has("harpoon_use_enabled") && MAIN["harpoon_use_enabled"]
}

StartHarpoonMacro() {
    global Macro

    if !IsHarpoonUseEnabled()
        return

    StopWindowUseClicker()

    Macro.cycleEnabled := true
    Macro.phase := "HARPOON"
    Macro.powerPercent := ""
    Macro.progressPercent := ""
    UpdateMacroStatus("작살총", "---", "---")
    try UpdateWindowHarpoonStatusUi()
    catch {
    }
}

StopHarpoonMacro(clearTip := true) {
    global Macro

    if (IsSet(Macro) && Macro) {
        Macro.cycleEnabled := false
        if (Macro.phase = "HARPOON")
            Macro.phase := "OFF"
        Macro.powerPercent := ""
        Macro.progressPercent := ""
    }
    try UpdateMacroStatus("OFF", "---", "---")
    try UpdateWindowHarpoonStatusUi()
    catch {
    }
    if (clearTip)
        try StopMacroMouseTip()
}
