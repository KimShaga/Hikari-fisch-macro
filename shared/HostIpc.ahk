; ============================================================================
;  Hikari — Python host bridge (status file + command file)
;  Python = app shell; AHK = macro engine (all realtime loops stay here).
; ============================================================================
#Requires AutoHotkey v2.0

global g_HostIpcStarted := false
global g_HostLastCmd := ""
global g_HostLastError := ""
global g_HostRequestedMode := ""

HostStatusPath() {
    global APPDATA_DIR
    return APPDATA_DIR "\host-status.json"
}

HostCmdPath() {
    global APPDATA_DIR
    return APPDATA_DIR "\host-cmd.json"
}

StartHostIpcBridge() {
    global g_HostIpcStarted
    if (g_HostIpcStarted)
        return
    g_HostIpcStarted := true
    try FileDelete(HostCmdPath())
    catch {
    }
    WriteHostStatusFile()
    SetTimer(WriteHostStatusFile, 750)
    SetTimer(PollHostCmdFile, 150)
}

; 호스트용 연결 문구 — GUI의 "접속 중 (20초)" 카운트다운과 분리
GetHostAttachText() {
    global ROD, g_BuildUnsupported, g_AttachFailReason

    if (!GetRobloxPID())
        return "로블록스 대기 중..."

    if (IsSet(g_BuildUnsupported) && g_BuildUnsupported)
        return GetUnsupportedBuildStatusText()

    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "offsets")
        return "오프셋 미대응 빌드"
    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "api")
        return "오프셋 서버 연결 실패"

    if (!IsMemoryReady())
        return "미연결 (첨부 대기)"

    if (!IsInFischGame())
        return "Fisch 서버 입장 필요"

    if (IsSet(ROD) && ROD != "")
        return "연결됨"

    ; 인게임인데 낚싯대 이름 아직 없음
    try {
        if (IsHotbarPopulated())
            return "핫바 읽는 중..."
    } catch {
    }
    return "인게임 · 핫바 대기"
}

WriteHostStatusFile() {
    global Macro, ROD, FULL_VER, g_HostHeadless, g_HostLastCmd, g_HostLastError, g_HostRequestedMode
    try {
        ; 인게임인데 ROD가 비어 있으면 가끔 강제 재시도
        if (IsMemoryReady() && IsInFischGame() && (!IsSet(ROD) || ROD = "")) {
            try {
                if (IsHotbarPopulated())
                    ReadHotbarRodNow()
            } catch {
            }
        }

        phase := ""
        enabled := 0
        display := ""
        if (IsSet(Macro) && Macro) {
            try phase := Macro.phase
            catch {
            }
            try enabled := Macro.cycleEnabled ? 1 : 0
            catch {
            }
            try display := GetMacroDisplayStatus()
            catch {
            }
        }
        rod := IsSet(ROD) ? ROD : ""
        try {
            if (rod = "" && IsMemoryReady() && IsInFischGame())
                rod := GetRodDisplayText()
        } catch {
        }
        attach := GetHostAttachText()
        ver := IsSet(FULL_VER) ? FULL_VER : ""
        minimizeOn := 1
        try minimizeOn := IsMinimizeOnMacroEnabled() ? 1 : 0
        catch {
        }
        headless := (IsSet(g_HostHeadless) && g_HostHeadless) ? 1 : 0

        power := "---"
        progress := "---"
        caught := 0
        lost := 0
        successRate := 0.0
        if (IsSet(Macro) && Macro) {
            try {
                if (Macro.powerPercent != "")
                    power := Macro.powerPercent
            } catch {
            }
            try {
                if (Macro.progressPercent != "")
                    progress := Macro.progressPercent
            } catch {
            }
            try caught := Macro.fishCaughtCount + 0
            catch {
            }
            try lost := Macro.fishLostCount + 0
            catch {
            }
            total := caught + lost
            successRate := total > 0 ? (caught / total) * 100.0 : 0.0
        }

        weatherLine := ""
        detailLine := ""
        buffs := ""
        hunts := ""
        try {
            global g_HostWeatherLine, g_HostClimateLine, g_HostBuffsText, g_HostHuntsText
            weatherLine := IsSet(g_HostWeatherLine) ? g_HostWeatherLine : ""
            detailLine := IsSet(g_HostClimateLine) ? g_HostClimateLine : ""
            buffs := IsSet(g_HostBuffsText) ? g_HostBuffsText : ""
            hunts := IsSet(g_HostHuntsText) ? g_HostHuntsText : ""
        } catch {
        }
        if (weatherLine = "") {
            try {
                climate := FormatWorldClimateDisplay()
                weatherLine := climate["weatherLine"]
                detailLine := climate["detailLine"]
            } catch {
            }
        }
        if (buffs = "") {
            try buffs := FormatActiveBuffsDisplay()
            catch {
            }
        }
        if (hunts = "") {
            try hunts := FormatActiveHuntsDisplay()
            catch {
            }
        }

        humpbackStatus := ""
        treasureStatus := ""
        appraiseStatus := ""
        enchantStatus := ""
        displayLocalized := display
        try {
            global g_HostHumpbackStatus, g_HostTreasureStatus, g_HostAppraiseStatus, g_HostEnchantStatus
            global g_HostStatusText, g_HostPowerText, g_HostProgressText
            humpbackStatus := IsSet(g_HostHumpbackStatus) ? g_HostHumpbackStatus : ""
            treasureStatus := IsSet(g_HostTreasureStatus) ? g_HostTreasureStatus : ""
            appraiseStatus := IsSet(g_HostAppraiseStatus) ? g_HostAppraiseStatus : ""
            enchantStatus := IsSet(g_HostEnchantStatus) ? g_HostEnchantStatus : ""
            if (IsSet(g_HostStatusText) && g_HostStatusText != "")
                displayLocalized := g_HostStatusText
            if (IsSet(g_HostPowerText) && g_HostPowerText != "")
                power := g_HostPowerText
            if (IsSet(g_HostProgressText) && g_HostProgressText != "")
                progress := g_HostProgressText
        } catch {
        }

        payload := Map(
            "event", "status",
            "phase", phase,
            "display", displayLocalized,
            "cycleEnabled", enabled,
            "rod", rod,
            "attach", attach,
            "mode", g_HostRequestedMode,
            "power", power,
            "progress", progress,
            "caught", caught,
            "lost", lost,
            "successRate", Round(successRate, 1),
            "weather", weatherLine,
            "climate", detailLine,
            "buffs", buffs,
            "hunts", hunts,
            "humpbackStatus", humpbackStatus,
            "treasureStatus", treasureStatus,
            "appraiseStatus", appraiseStatus,
            "enchantStatus", enchantStatus,
            "minimize_on_macro", minimizeOn,
            "headless", headless,
            "version", ver,
            "lastCmd", g_HostLastCmd,
            "lastError", g_HostLastError,
            "pid", DllCall("GetCurrentProcessId")
        )
        ; tick은 매번 바뀌므로 비교용 fingerprint에서는 제외 — 내용 같으면 디스크 스킵
        fingerprint := JSON.stringify(payload)
        global g_HostStatusFingerprint
        if (IsSet(g_HostStatusFingerprint) && g_HostStatusFingerprint = fingerprint)
            return
        g_HostStatusFingerprint := fingerprint
        payload["tick"] := A_TickCount
        text := JSON.stringify(payload)
        path := HostStatusPath()
        f := FileOpen(path, "w", "UTF-8-RAW")
        if (f) {
            f.Write(text)
            f.Close()
        }
    } catch {
    }
}

ReloadHostSettingsFromDisk() {
    global SETTINGS, ENV, HOTKEYS, UPDATE, MAIN, WEBHOOK, USERPREFS, APPEARANCE
    path := APPDATA_DIR "\settings.json"
    if !FileExist(path)
        return false
    try {
        fresh := JSON.parse(FileRead(path, "UTF-8-RAW"))
        if !(fresh is Map)
            return false
        SETTINGS := fresh
        if (SETTINGS.Has("env"))
            ENV := SETTINGS["env"]
        if (SETTINGS.Has("hotkeys"))
            HOTKEYS := SETTINGS["hotkeys"]
        if (SETTINGS.Has("update"))
            UPDATE := SETTINGS["update"]
        if (SETTINGS.Has("main"))
            MAIN := SETTINGS["main"]
        if (SETTINGS.Has("webhook"))
            WEBHOOK := SETTINGS["webhook"]
        if (SETTINGS.Has("user"))
            USERPREFS := SETTINGS["user"]
        if (SETTINGS.Has("appearance"))
            APPEARANCE := SETTINGS["appearance"]
        ApplyFixedAppearance()
        return true
    } catch {
        return false
    }
}

ApplyHostUserPatch(patch) {
    global USERPREFS, SETTINGS, g_HostHeadless
    if !(patch is Map)
        return false
    for key, value in patch {
        USERPREFS[key] := value
        if (SETTINGS.Has("user"))
            SETTINGS["user"][key] := value
    }
    ; headless: Python already wrote settings.json — disk write skip
    if !(IsSet(g_HostHeadless) && g_HostHeadless) {
        try SaveSettingsFile()
        catch {
            return false
        }
    }
    ApplyFixedAppearance()
    return true
}

ApplyHostMainPatch(patch) {
    global MAIN, SETTINGS, g_HostHeadless
    if !(patch is Map)
        return false
    for key, value in patch {
        MAIN[key] := value
        if (SETTINGS.Has("main"))
            SETTINGS["main"][key] := value
    }
    if !(IsSet(g_HostHeadless) && g_HostHeadless) {
        try SaveSettingsFile()
        catch {
            return false
        }
    }
    return true
}

PollHostCmdFile() {
    global g_HostLastCmd, g_HostLastError, g_HostRequestedMode
    path := HostCmdPath()
    if !FileExist(path)
        return

    raw := ""
    try raw := FileRead(path, "UTF-8-RAW")
    catch {
        return
    }
    try FileDelete(path)
    catch {
    }

    raw := Trim(raw)
    if (raw = "")
        return
    ; strip BOM if present
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)

    obj := ""
    try obj := JSON.parse(raw)
    catch {
        g_HostLastError := "cmd JSON 파싱 실패"
        WriteHostStatusFile()
        return
    }
    if !(obj is Map) || !obj.Has("cmd")
        return

    cmd := obj["cmd"]
    g_HostLastCmd := cmd
    g_HostLastError := ""

    if (cmd = "ping") {
        WriteHostStatusFile()
        return
    }
    if (cmd = "reload_settings") {
        if !ReloadHostSettingsFromDisk()
            g_HostLastError := "settings reload 실패"
        WriteHostStatusFile()
        return
    }
    if (cmd = "patch_user") {
        patch := obj.Has("user") ? obj["user"] : Map()
        if !ApplyHostUserPatch(patch)
            g_HostLastError := "user patch 실패"
        WriteHostStatusFile()
        return
    }
    if (cmd = "patch_main") {
        patch := obj.Has("main") ? obj["main"] : Map()
        if !ApplyHostMainPatch(patch)
            g_HostLastError := "main patch 실패"
        WriteHostStatusFile()
        return
    }
    if (cmd = "patch_webhook") {
        global WEBHOOK, SETTINGS, g_HostHeadless
        patch := obj.Has("webhook") ? obj["webhook"] : Map()
        if (patch is Map) {
            for key, value in patch {
                WEBHOOK[key] := value
                if (SETTINGS.Has("webhook"))
                    SETTINGS["webhook"][key] := value
            }
            if !(IsSet(g_HostHeadless) && g_HostHeadless) {
                try SaveSettingsFile()
                catch {
                    g_HostLastError := "webhook patch 실패"
                }
            }
        }
        WriteHostStatusFile()
        return
    }
    if (cmd = "patch_hotkeys") {
        global HOTKEYS, SETTINGS, g_HostHeadless
        patch := obj.Has("hotkeys") ? obj["hotkeys"] : Map()
        if (patch is Map) {
            for key, value in patch {
                HOTKEYS[key] := value
                if (SETTINGS.Has("hotkeys"))
                    SETTINGS["hotkeys"][key] := value
            }
            if !(IsSet(g_HostHeadless) && g_HostHeadless) {
                try SaveSettingsFile()
                catch {
                    g_HostLastError := "hotkeys patch 실패"
                }
                try HotkeyManager.RegisterAll(SETTINGS)
                catch {
                }
            }
        }
        WriteHostStatusFile()
        return
    }
    if (cmd = "fix_roblox") {
        try FixRoblox()
        catch as err {
            g_HostLastError := "로블록스 복구 실패: " err.Message
        }
        WriteHostStatusFile()
        return
    }
    if (cmd = "reload") {
        try ReloadMacro()
        catch {
            try Reload()
            catch {
                g_HostLastError := "reload 실패"
            }
        }
        return
    }
    if (cmd = "hunt_refresh") {
        try RefreshHuntDetectNow()
        catch as err {
            g_HostLastError := "헌트 검사 실패: " err.Message
        }
        WriteHostStatusFile()
        return
    }
    if (cmd = "set_mode") {
        mode := obj.Has("mode") ? obj["mode"] : "fish"
        g_HostRequestedMode := mode
        WriteHostStatusFile()
        return
    }
    if (cmd = "start") {
        mode := obj.Has("mode") ? obj["mode"] : "fish"
        g_HostRequestedMode := mode
        ; F1 토글: 이미 돌고 있으면 끄기만 하고 끝 (Stop→Start 재시작 금지)
        global Macro
        if (IsSet(Macro) && Macro && Macro.cycleEnabled) {
            try StopMacroForHost()
            catch as err {
                g_HostLastError := err.Message
            }
            WriteHostStatusFile()
            return
        }
        ok := false
        try ok := StartMacroWithMode(mode)
        catch as err {
            g_HostLastError := err.Message
            WriteHostStatusFile()
            return
        }
        if (!ok)
            g_HostLastError := "시작 실패 (로블록스/핫바/모드 조건 확인)"
        WriteHostStatusFile()
        return
    }
    if (cmd = "stop") {
        try StopMacroForHost()
        catch as err {
            g_HostLastError := err.Message
        }
        WriteHostStatusFile()
        return
    }
}
