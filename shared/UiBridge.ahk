; ============================================================================
;  Hikari — headless UI bridge (no AHK window)
;  Status mirrors for Python host; replaces ui\Gui.ahk engine-facing API.
; ============================================================================
#Requires AutoHotkey v2.0

global g_HostStatusText := "---"
global g_HostPowerText := "---"
global g_HostProgressText := "---"
global g_HostAppraiseStatus := ""
global g_HostTreasureStatus := ""
global g_HostEnchantStatus := ""
global g_HostHumpbackStatus := ""
global g_HostBuffsText := ""
global g_HostHuntsText := ""
global g_HostWeatherLine := ""
global g_HostClimateLine := ""
global g_HostTotemSelection := ""

GetRodDisplayText() {
    global ROD
    base := (ROD != "" ? ROD : GetAttachStatusText())
    if (ROD = "")
        return base
    try {
        p := ReadKeeperboundPowerPercent()
        if (p != "")
            return base " · " Format("{:.1f}%", p)
    } catch {
    }
    return base
}

GetAttachStatusText() {
    global g_BuildUnsupported, g_AttachFailReason, _ConnectingSince, ATTACH_CONNECTING_TIMEOUT_MS

    if (!GetRobloxPID())
        return "로블록스 대기 중..."

    if (IsSet(g_BuildUnsupported) && g_BuildUnsupported)
        return GetUnsupportedBuildStatusText()

    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "offsets")
        return "이 빌드에 오프셋이 아직 맞지 않음"
    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "api")
        return "OpenMacro 서버에 연결할 수 없음"

    if (IsMemoryReady() && IsInFischGame()) {
        global ROD
        if (IsSet(ROD) && ROD != "")
            return "연결됨"
        if (!_ConnectingSince)
            _ConnectingSince := A_TickCount
        leftMs := ATTACH_CONNECTING_TIMEOUT_MS - (A_TickCount - _ConnectingSince)
        leftSec := Max(0, Ceil(leftMs / 1000))
        return "핫바/낚싯대 대기 (" leftSec "초)"
    }

    return "Fisch 서버에 입장하세요"
}

FormatLullabyModeDisplay(mode) {
    switch StrLower(Trim(mode)) {
        case "quickening":
            return "Symphony"
        case "fortuitous":
            return "Harmony"
        case "strenghtening", "strengthening":
            return "Melody"
        case "resistant":
            return "Composition"
        case "prismatic", "prismatic/serenity", "serenity":
            return "Prismatic/Serenity"
        default:
            return mode
    }
}

LocalizeStatus(status) {
    if (status = "")
        return "---"
    statusMap := Map(
        "OFF", "꺼짐",
        "CASTING", "캐스팅",
        "CASTED", "캐스트 완료",
        "SHAKE", "흔들기",
        "FISHING", "낚시",
        "TRANQUILITY", "평온",
        "LULLABY", "감지 대기",
        "BELLONA", "벨로나",
        "APPRAISE", "감정",
        "GP_APPRAISE", "게임패스 감정",
        "ENCHANT", "인챈트",
        "GP_ENCHANT", "게임패스 인챈트",
        "DONE", "완료",
        "FAILED", "실패",
        "IDLE", "대기",
        "TOTEM_SETTLE", "토템 준비",
        "TOTEM_WAIT_AURORA", "효과 대기",
        "TOTEM_WAIT_EFFECT", "효과 대기",
        "TOTEM_WAIT_NIGHT", "시간 대기",
        "TOTEM_WAIT_CYCLE", "시간 대기",
        "RESOLVING", "확인 중",
        "CLICK_FIRST", "첫 클릭",
        "CLICK_SECOND", "둘째 클릭",
        "WAIT_RESULT", "결과 대기",
        "WAIT_RETRY", "재시도 대기",
        "WAIT_RELIC", "릴릭 대기",
        "PRESS_E", "E 키",
        "CLICK", "Enchant 클릭",
        "SPAM", "Enchant 연타",
        "FIND_CLICK", "Enchant 클릭",
        "GP_RESOLVE", "확인 중",
        "GP_CLICK", "Enchant 클릭",
        "GP_SPAM", "Enchant 연타",
        "GP_WAIT_RELIC", "릴릭 대기",
        "창 사용", "창 사용"
    )
    if RegExMatch(status, "^LULLABY_MODE:(.+)$", &m)
        return FormatLullabyModeDisplay(m[1])
    if RegExMatch(status, "^APPRAISE\s+(.+)$", &m) {
        st := statusMap.Has(m[1]) ? statusMap[m[1]] : m[1]
        return "감정 " st
    }
    if RegExMatch(status, "^GP_ENCHANT\s+(.+)$", &m) {
        st := statusMap.Has(m[1]) ? statusMap[m[1]] : m[1]
        return "게임패스 인챈트 " st
    }
    if RegExMatch(status, "^ENCHANT\s+(.+)$", &m) {
        st := statusMap.Has(m[1]) ? statusMap[m[1]] : m[1]
        return "인챈트 " st
    }
    if RegExMatch(status, "^GP\s+(.+)$", &m) {
        st := statusMap.Has(m[1]) ? statusMap[m[1]] : m[1]
        return "게임패스 감정 " st
    }
    if RegExMatch(status, "^HUMPBACK\s+(.+)$", &m)
        return "혹등 " m[1]
    if RegExMatch(status, "^TREASURE\s+(.+)$", &m)
        return "보물섬 " m[1]
    return statusMap.Has(status) ? statusMap[status] : status
}

UpdateMacroStatus(status := "", power := "", progress := "") {
    global Macro, g_HostStatusText, g_HostPowerText, g_HostProgressText

    displayStatus := status
    if (IsSet(Macro) && Macro && Macro.HasOwnProp("autoChargeStatusHold")
        && Macro.autoChargeStatusHold != ""
        && Macro.HasOwnProp("autoChargeStatusHoldUntil")
        && A_TickCount < Macro.autoChargeStatusHoldUntil) {
        displayStatus := Macro.autoChargeStatusHold
    }

    g_HostStatusText := (displayStatus = "") ? "---" : LocalizeStatus(displayStatus)
    if (power != "")
        g_HostPowerText := power
    if (progress != "")
        g_HostProgressText := progress
}

UpdateRobloxUiState() {
    global g_GuiSizing, g_HostWeatherLine, g_HostClimateLine, g_HostTotemSelection

    if (IsSet(g_GuiSizing) && g_GuiSizing)
        return

    try {
        climate := FormatWorldClimateDisplay()
        g_HostWeatherLine := climate["weatherLine"]
        g_HostClimateLine := climate["detailLine"]
    } catch {
    }

    try UpdateBuffStatusUi(false)
    catch {
    }
    try UpdateHuntStatusUi()
    catch {
    }
    try g_HostTotemSelection := FormatAutoTotemSelectionDisplay()
    catch {
    }

    ; Lullaby status refresh without GUI controls
    global Macro
    if (IsSet(Macro) && Macro && Macro.phase = "LULLABY") {
        global g_HostPowerText, g_HostProgressText
        UpdateMacroStatus(GetMacroDisplayStatus(), g_HostPowerText, g_HostProgressText)
    }
}

FormatAutoTotemSelectionDisplay() {
    global MAIN, Macro
    EnsureAutoTotemToggles()
    EnsureBuffItemToggles()

    if !(MAIN.Has("auto_totem_enabled") && MAIN["auto_totem_enabled"])
        return "선택 아이템: (사용 꺼짐)"

    parts := []
    for name in GetEnabledAutoTotems() {
        short := RegExReplace(name, "i)\s*Totem$", "")
        parts.Push(short)
    }
    for name in GetEnabledBuffItems() {
        short := name
        short := StrReplace(short, "Luck Potion ", "Luck ")
        short := StrReplace(short, "Lure Speed Potion ", "Lure ")
        short := StrReplace(short, "Shell of ", "Shell ")
        parts.Push(short)
    }

    if (parts.Length = 0)
        return "선택 아이템: (없음)"

    line := "선택 아이템: "
    for i, p in parts {
        if (i > 1)
            line .= ", "
        line .= p
    }

    active := ""
    if (IsSet(Macro) && Macro && Macro.HasOwnProp("activeTotemName") && Macro.activeTotemName != "")
        active := RegExReplace(Macro.activeTotemName, "i)\s*Totem$", "")
    else if (IsSet(Macro) && Macro && Macro.HasOwnProp("totemPendingName") && Macro.totemPendingName != "")
        active := RegExReplace(Macro.totemPendingName, "i)\s*Totem$", "") " (예약)"

    if (active != "")
        line .= "  · 사용 중: " active
    return line
}

UpdateAutoTotemSelectionUi() {
    global g_HostTotemSelection
    try g_HostTotemSelection := FormatAutoTotemSelectionDisplay()
    catch {
    }
}
