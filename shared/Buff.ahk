; ============================================================================
;  Hikari's Edited Fisch Macro — Buff detect + other item auto-use
; ============================================================================
#Requires AutoHotkey v2.0

global BUFF_SCAN_INTERVAL_MS := 2000
global g_ActiveBuffs := Map()
global g_ActiveBuffsAt := 0
global g_LastBuffStatusUiText := ""
global g_BuffItemPending := false
global g_BuffItemPendingName := ""
global g_LastBuffItemSuccessAt := Map()
global g_LastBuffItemAttemptAt := Map()
global g_BuffItemDurationCoverUntil := Map()

GetSupportedBuffItemList() {
    return [
        "Luck Potion I",
        "Luck Potion II",
        "Luck Potion III",
        "Lure Speed Potion I",
        "Lure Speed Potion II",
        "Lure Speed Potion III",
        "Shell of Depth",
        "Shell of Endurance",
        "Shell of Fortune",
        "Shell of Swiftness",
        "Shell of Wrath"
    ]
}

IsSupportedBuffItem(name) {
    static supported := Map(
        "Luck Potion I", true,
        "Luck Potion II", true,
        "Luck Potion III", true,
        "Lure Speed Potion I", true,
        "Lure Speed Potion II", true,
        "Lure Speed Potion III", true,
        "Shell of Depth", true,
        "Shell of Endurance", true,
        "Shell of Fortune", true,
        "Shell of Swiftness", true,
        "Shell of Wrath", true
    )
    return supported.Has(name)
}

; luck / lure mutually exclusive within type; shells stack independently
GetBuffItemType(name) {
    switch name {
        case "Luck Potion I", "Luck Potion II", "Luck Potion III":
            return "luck"
        case "Lure Speed Potion I", "Lure Speed Potion II", "Lure Speed Potion III":
            return "lure"
        case "Shell of Depth", "Shell of Endurance", "Shell of Fortune", "Shell of Swiftness", "Shell of Wrath":
            return "shell:" name
        default:
            return ""
    }
}

GetBuffItemHotbarAliases(name) {
    switch name {
        case "Luck Potion I":
            return ["Luck Potion I", "Luck Potion 1", "Luck Potion Tier 1", "T1 Luck Potion", "Lucky Potion I", "Luck Potion"]
        case "Luck Potion II":
            return ["Luck Potion II", "Luck Potion 2", "Luck Potion Tier 2", "T2 Luck Potion", "Lucky Potion II", "Luck Potion"]
        case "Luck Potion III":
            return ["Luck Potion III", "Luck Potion 3", "Luck Potion Tier 3", "T3 Luck Potion", "Lucky Potion III", "Luck Potion"]
        case "Lure Speed Potion I":
            return ["Lure Speed Potion I", "Lure Speed Potion 1", "Lure Speed Potion Tier 1", "T1 Lure Speed Potion", "Lure Potion I", "Lure Potion 1", "Lure Speed Potion"]
        case "Lure Speed Potion II":
            return ["Lure Speed Potion II", "Lure Speed Potion 2", "Lure Speed Potion Tier 2", "T2 Lure Speed Potion", "Lure Potion II", "Lure Potion 2", "Lure Speed Potion"]
        case "Lure Speed Potion III":
            return ["Lure Speed Potion III", "Lure Speed Potion 3", "Lure Speed Potion Tier 3", "T3 Lure Speed Potion", "Lure Potion III", "Lure Potion 3", "Lure Speed Potion"]
        case "Shell of Depth", "Shell of Endurance", "Shell of Fortune", "Shell of Swiftness", "Shell of Wrath":
            return [name]
        default:
            return [name]
    }
}

; Wiki: potion item tier → HUD status name. All Season (All Seasons + Lure IV) is ignored.
GetPotionHudEffectSpec(name) {
    switch name {
        case "Luck Potion I":
            return Map("kind", "luck", "minHudTier", 2, "label", "Lucky+ II")
        case "Luck Potion II":
            return Map("kind", "luck", "minHudTier", 3, "label", "Lucky+ III")
        case "Luck Potion III":
            return Map("kind", "luck", "minHudTier", 4, "label", "Lucky+ IV")
        case "Lure Speed Potion I":
            return Map("kind", "lure", "minHudTier", 5, "label", "Lure V")
        case "Lure Speed Potion II":
            return Map("kind", "lure", "minHudTier", 7, "label", "Lure VII")
        case "Lure Speed Potion III":
            return Map("kind", "lure", "minHudTier", 9, "label", "Lure IX")
        default:
            return Map("kind", "", "minHudTier", 0, "label", "")
    }
}

GetPotionDurationMs(name) {
    switch name {
        case "Luck Potion I", "Lure Speed Potion I":
            return 15 * 60 * 1000
        case "Luck Potion II", "Lure Speed Potion II":
            return 30 * 60 * 1000
        case "Luck Potion III", "Lure Speed Potion III":
            return 60 * 60 * 1000
        case "Shell of Depth", "Shell of Endurance", "Shell of Fortune", "Shell of Swiftness", "Shell of Wrath":
            return 30 * 60 * 1000
        default:
            return 15 * 60 * 1000
    }
}

IsAllSeasonText(text) {
    t := StrLower(text)
    return InStr(t, "all season") || InStr(t, "allseason") ? true : false
}

IsLureSpeedPotionHudTier(tier) {
    return (tier = 5 || tier = 7 || tier = 9)
}

GetDefaultBuffItemToggles() {
    toggles := Map()
    for name in GetSupportedBuffItemList()
        toggles[name] := 0
    return toggles
}

EnsureBuffItemToggles() {
    global MAIN, SETTINGS
    NormalizeBuffItemToggleSettings(MAIN)
    if (SETTINGS.Has("main"))
        SETTINGS["main"]["auto_buff_item_toggles"] := MAIN["auto_buff_item_toggles"]
}

NormalizeBuffItemToggleSettings(mainSettings) {
    changed := false
    if !(mainSettings is Map)
        return false

    if (!mainSettings.Has("auto_buff_item_toggles") || !(mainSettings["auto_buff_item_toggles"] is Map)) {
        mainSettings["auto_buff_item_toggles"] := GetDefaultBuffItemToggles()
        changed := true
    }

    defaults := GetDefaultBuffItemToggles()
    for name, _ in defaults {
        if !mainSettings["auto_buff_item_toggles"].Has(name) {
            mainSettings["auto_buff_item_toggles"][name] := 0
            changed := true
        } else {
            normalized := mainSettings["auto_buff_item_toggles"][name] ? 1 : 0
            if (normalized != mainSettings["auto_buff_item_toggles"][name]) {
                mainSettings["auto_buff_item_toggles"][name] := normalized
                changed := true
            }
        }
    }

    ; Keep at most one luck / one lure enabled
    seenType := Map()
    for name in GetSupportedBuffItemList() {
        if !(mainSettings["auto_buff_item_toggles"].Has(name) && mainSettings["auto_buff_item_toggles"][name])
            continue
        typeName := GetBuffItemType(name)
        if (typeName = "" || InStr(typeName, "shell:"))
            continue
        if (seenType.Has(typeName)) {
            mainSettings["auto_buff_item_toggles"][name] := 0
            changed := true
            continue
        }
        seenType[typeName] := name
    }
    return changed
}

IsBuffItemToggleEnabled(name) {
    global MAIN
    EnsureBuffItemToggles()
    return MAIN["auto_buff_item_toggles"].Has(name) && MAIN["auto_buff_item_toggles"][name]
}

SetBuffItemToggle(name, enabled) {
    global MAIN, SETTINGS
    if !IsSupportedBuffItem(name)
        return

    EnsureBuffItemToggles()
    enabled := enabled ? 1 : 0
    MAIN["auto_buff_item_toggles"][name] := enabled

    if (enabled) {
        typeName := GetBuffItemType(name)
        if (typeName != "" && !InStr(typeName, "shell:")) {
            for other in GetSupportedBuffItemList() {
                if (other = name)
                    continue
                if (GetBuffItemType(other) = typeName)
                    MAIN["auto_buff_item_toggles"][other] := 0
            }
        }
    }

    if (SETTINGS.Has("main"))
        SETTINGS["main"]["auto_buff_item_toggles"] := MAIN["auto_buff_item_toggles"]
}

GetEnabledBuffItems() {
    global MAIN
    EnsureBuffItemToggles()
    enabled := []
    for name in GetSupportedBuffItemList() {
        if (MAIN["auto_buff_item_toggles"].Has(name) && MAIN["auto_buff_item_toggles"][name])
            enabled.Push(name)
    }
    return enabled
}

ParseRomanOrDigitTier(text) {
    t := StrLower(Trim(text))
    if RegExMatch(t, "(?:^|[^a-z])(i{1,3}|iv|v|vi{0,3}|[1-9])(?:$|[^a-z0-9])", &m) {
        r := m[1]
        switch r {
            case "i", "1":
                return 1
            case "ii", "2":
                return 2
            case "iii", "3":
                return 3
            case "iv", "4":
                return 4
            case "v", "5":
                return 5
            case "vi", "6":
                return 6
            case "vii", "7":
                return 7
            case "viii", "8":
                return 8
            case "ix", "9":
                return 9
        }
        if RegExMatch(r, "^\d+$")
            return r + 0
    }
    return 0
}

ParseItemPotionTier(text) {
    t := StrLower(Trim(text))
    if (t = "")
        return 0
    if RegExMatch(t, "tier\s*(iii|ii|i|[123])", &m)
        return RomanTokenToInt(m[1])
    if RegExMatch(t, "(?:^|[^a-z])t\s*([123])(?:$|[^0-9])", &m)
        return m[1] + 0
    if RegExMatch(t, "(?:^|[^a-z])(iii|ii|i|[123])(?:$|[^a-z0-9])", &m)
        return RomanTokenToInt(m[1])
    return 0
}

RomanTokenToInt(r) {
    r := StrLower(Trim(r))
    switch r {
        case "i", "1":
            return 1
        case "ii", "2":
            return 2
        case "iii", "3":
            return 3
        case "iv", "4":
            return 4
        case "v", "5":
            return 5
        case "vi", "6":
            return 6
        case "vii", "7":
            return 7
        case "viii", "8":
            return 8
        case "ix", "9":
            return 9
    }
    if RegExMatch(r, "^\d+$")
        return r + 0
    return 0
}

HudTierLabel(kind, tier) {
    static romans := Map(1, "I", 2, "II", 3, "III", 4, "IV", 5, "V", 6, "VI", 7, "VII", 8, "VIII", 9, "IX")
    roman := romans.Has(tier) ? romans[tier] : tier
    if (kind = "luck")
        return "Lucky+ " roman
    if (kind = "lure")
        return "Lure " roman
    return roman
}

FindHudStatusesRoot() {
    playerGui := FindPlayerGui()
    if (!playerGui)
        return 0
    hud := FindChildByNameCI(playerGui, "hud")
    if (!hud)
        return 0
    safezone := FindChildByNameCI(hud, "safezone")
    if (!safezone)
        return 0
    root := FindChildByNameCI(safezone, "statuses")
    if (root)
        return root
    return FindChildByNameCI(safezone, "worldstatuses")
}

CollectStatusFrameBlob(childAddr) {
    blob := ""
    try {
        for label in CollectTextLabelsUnder(childAddr, 24) {
            if (label != "")
                blob .= " " label
        }
    } catch {
    }
    return Trim(blob)
}

; Hidden templates live in statuses with empty timers. Active buffs have a timer.
CollectActiveBuffSnapshots() {
    snaps := []
    root := FindHudStatusesRoot()
    if (!root)
        return snaps

    try {
        for childAddr in ReadChildren(root) {
            try {
                className := ReadClassName(childAddr)
                if (className != "Frame" && className != "ImageButton")
                    continue
                try {
                    if (!ReadGuiObjectVisible(childAddr))
                        continue
                } catch {
                }
                frameName := ReadInstanceName(childAddr)
                if (frameName != "" && RegExMatch(frameName, "i)^Lullaby"))
                    continue

                displayName := ""
                tooltip := ""
                timer := ""
                timerFound := false

                label := FindChildByName(childAddr, "displayName")
                if (!label)
                    label := FindGuiDescendantByName(childAddr, "displayName", 800)
                if (label) {
                    try displayName := Trim(ReadGuiText(label))
                    catch {
                    }
                }
                tip := FindChildByName(childAddr, "tooltip")
                if (!tip)
                    tip := FindGuiDescendantByName(childAddr, "tooltip", 800)
                if (tip) {
                    try tooltip := Trim(ReadGuiText(tip))
                    catch {
                    }
                }
                tim := FindChildByName(childAddr, "timer")
                if (!tim)
                    tim := FindGuiDescendantByName(childAddr, "timer", 800)
                if (tim) {
                    timerFound := true
                    try timer := Trim(ReadGuiText(tim))
                    catch {
                    }
                }
                extra := CollectStatusFrameBlob(childAddr)
                hay := Trim(displayName " " frameName " " tooltip " " extra)
                if (IsAllSeasonText(hay))
                    continue
                if (timerFound && timer = "")
                    continue
                if (displayName = "" && tooltip = "" && frameName = "")
                    continue
                snaps.Push(Map(
                    "frame", frameName,
                    "display", displayName,
                    "tooltip", tooltip,
                    "timer", timer,
                    "hay", hay
                ))
            } catch {
                continue
            }
        }
    } catch {
    }
    return snaps
}

; luckPlusTier: Lucky+ II/III/IV from Luck Potion. lurePotionTier: Lure V/VII/IX only (not All Season Lure IV).
ScanActiveBuffState(force := false) {
    global g_ActiveBuffs, g_ActiveBuffsAt, BUFF_SCAN_INTERVAL_MS

    if (!force && g_ActiveBuffsAt && (A_TickCount - g_ActiveBuffsAt) < BUFF_SCAN_INTERVAL_MS)
        return g_ActiveBuffs

    state := Map(
        "luckTier", 0,
        "luckPlusTier", 0,
        "lureTier", 0,
        "lurePotionTier", 0,
        "shells", []
    )
    shellSeen := Map()

    for snap in CollectActiveBuffSnapshots() {
        display := snap["display"]
        frame := snap["frame"]
        hay := snap.Has("hay") ? snap["hay"] : (display " " frame " " snap["tooltip"])
        hayLower := StrLower(hay)
        displayLower := StrLower(display)

        isLuckPlus := InStr(hayLower, "lucky+") || InStr(hayLower, "lucky +")
            || InStr(frame, "LuckPotion")
            || (RegExMatch(displayLower, "^lucky\+") || RegExMatch(displayLower, "^lucky\s*\+"))
        if (isLuckPlus && !InStr(frame, "LuckMerlin")) {
            tier := ParseRomanOrDigitTier(display)
            if (!tier)
                tier := ParseRomanOrDigitTier(hay)
            if (!tier)
                tier := ParseRomanOrDigitTier(frame)
            if (tier > state["luckPlusTier"])
                state["luckPlusTier"] := tier
            if (tier > state["luckTier"])
                state["luckTier"] := tier
        }

        isLurePotion := InStr(frame, "LurePotion")
            || RegExMatch(displayLower, "^lure(\s|\+|$)")
            || RegExMatch(hayLower, "\blure\s*\+?\s*(ix|viii|vii|vi|iv|v|iii|ii|i|[1-9])\b")
        if (isLurePotion && !IsAllSeasonText(hay) && !InStr(frame, "LureMerlin")) {
            tier := ParseRomanOrDigitTier(display)
            if (!tier)
                tier := ParseRomanOrDigitTier(hay)
            if (!tier)
                tier := ParseRomanOrDigitTier(frame)
            if (InStr(frame, "LurePotion") || IsLureSpeedPotionHudTier(tier)) {
                if (tier > state["lurePotionTier"])
                    state["lurePotionTier"] := tier
                if (tier > state["lureTier"])
                    state["lureTier"] := tier
            }
        }

        for shellKey in ["Depth", "Endurance", "Fortune", "Swiftness", "Wrath"] {
            shellLower := StrLower(shellKey)
            exactDisplay := (display = shellKey || displayLower = shellLower
                || InStr(displayLower, "shell of " shellLower))
            frameHit := InStr(frame, "Shell" shellKey) || InStr(frame, "ShellOf" shellKey)
            if (exactDisplay || (frameHit && InStr(hayLower, "shell"))) {
                if !shellSeen.Has(shellKey) {
                    shellSeen[shellKey] := true
                    state["shells"].Push(shellKey)
                }
            }
        }
    }

    g_ActiveBuffs := state
    g_ActiveBuffsAt := A_TickCount
    return state
}

FormatActiveBuffsDisplay(state := unset) {
    if (!IsSet(state))
        state := ScanActiveBuffState(false)
    if !(state is Map)
        return "버프: (없음)"

    parts := []
    luckTier := 0
    if (state.Has("luckPlusTier") && state["luckPlusTier"] > 0)
        luckTier := state["luckPlusTier"]
    else if (state.Has("luckTier") && state["luckTier"] > 0)
        luckTier := state["luckTier"]
    if (luckTier > 0)
        parts.Push(HudTierLabel("luck", luckTier))

    lureTier := 0
    if (state.Has("lurePotionTier") && state["lurePotionTier"] > 0)
        lureTier := state["lurePotionTier"]
    else if (state.Has("lureTier") && state["lureTier"] > 0)
        lureTier := state["lureTier"]
    if (lureTier > 0)
        parts.Push(HudTierLabel("lure", lureTier))

    if (state.Has("shells") && state["shells"] is Array && state["shells"].Length) {
        shellLine := ""
        for i, s in state["shells"] {
            if (i > 1)
                shellLine .= ", "
            shellLine .= s
        }
        parts.Push("Shell " shellLine)
    }

    if (!parts.Length)
        return "버프: (없음)"

    line := "버프: "
    for i, p in parts {
        if (i > 1)
            line .= " · "
        line .= p
    }
    return line
}

UpdateBuffStatusUi(forceScan := false) {
    global BuffStatusText, g_LastBuffStatusUiText, g_HostBuffsText
    try {
        text := FormatActiveBuffsDisplay(ScanActiveBuffState(forceScan))
        g_HostBuffsText := text
        if (!IsSet(BuffStatusText) || !BuffStatusText)
            return
        if (text = g_LastBuffStatusUiText)
            return
        g_LastBuffStatusUiText := text
        BuffStatusText.Value := text
    } catch {
    }
}

IsLuckPotionBuffActive(minHudTier := 2) {
    state := ScanActiveBuffState(false)
    tier := 0
    if (state.Has("luckPlusTier"))
        tier := state["luckPlusTier"]
    else if (state.Has("luckTier"))
        tier := state["luckTier"]
    return tier >= minHudTier
}

IsLureSpeedPotionBuffActive(minHudTier := 5) {
    state := ScanActiveBuffState(false)
    tier := 0
    if (state.Has("lurePotionTier"))
        tier := state["lurePotionTier"]
    else if (state.Has("lureTier") && IsLureSpeedPotionHudTier(state["lureTier"]))
        tier := state["lureTier"]
    return tier >= minHudTier
}

IsShellBuffActive(shellKey) {
    state := ScanActiveBuffState(false)
    if !(state.Has("shells") && state["shells"] is Array)
        return false
    key := shellKey
    if InStr(shellKey, "Shell of ")
        key := SubStr(shellKey, StrLen("Shell of ") + 1)
    for s in state["shells"] {
        if (s = key)
            return true
    }
    return false
}

IsHudBuffActiveForItem(name) {
    spec := GetPotionHudEffectSpec(name)
    if (spec["kind"] = "luck")
        return IsLuckPotionBuffActive(spec["minHudTier"])
    if (spec["kind"] = "lure")
        return IsLureSpeedPotionBuffActive(spec["minHudTier"])
    switch name {
        case "Shell of Depth":
            return IsShellBuffActive("Depth")
        case "Shell of Endurance":
            return IsShellBuffActive("Endurance")
        case "Shell of Fortune":
            return IsShellBuffActive("Fortune")
        case "Shell of Swiftness":
            return IsShellBuffActive("Swiftness")
        case "Shell of Wrath":
            return IsShellBuffActive("Wrath")
        default:
            return false
    }
}

IsDurationCoverActive(name) {
    global g_BuffItemDurationCoverUntil
    if !(g_BuffItemDurationCoverUntil is Map)
        return false
    if !g_BuffItemDurationCoverUntil.Has(name)
        return false
    return (A_TickCount < g_BuffItemDurationCoverUntil[name])
}

MarkBuffItemUsed(name) {
    global g_LastBuffItemSuccessAt, g_BuffItemDurationCoverUntil
    if !(g_LastBuffItemSuccessAt is Map)
        g_LastBuffItemSuccessAt := Map()
    if !(g_BuffItemDurationCoverUntil is Map)
        g_BuffItemDurationCoverUntil := Map()
    g_LastBuffItemSuccessAt[name] := A_TickCount
    ; HUD 반영 지연용. 긴 지속시간은 HUD Lucky+/Lure V·VII·IX 감지가 담당.
    g_BuffItemDurationCoverUntil[name] := A_TickCount + 12000
}

IsBuffItemCovered(name) {
    if IsHudBuffActiveForItem(name)
        return true
    return IsDurationCoverActive(name)
}

CollectHotbarSlotText(itemAddr) {
    text := ReadHotbarItemName(itemAddr)
    try {
        for childAddr in ReadChildren(itemAddr) {
            try {
                className := ReadClassName(childAddr)
                childName := ReadInstanceName(childAddr)
                if (className != "TextLabel" && className != "TextButton")
                    continue
                if (childName = "TextLabel")
                    continue
                extra := Trim(ReadGuiText(childAddr))
                if (extra != "")
                    text .= " " extra
            } catch {
            }
        }
    } catch {
    }
    return Trim(text)
}

IsLuckPotionHotbarText(text) {
    lower := StrLower(text)
    if IsAllSeasonText(lower)
        return false
    return (InStr(lower, "luck") && InStr(lower, "potion")) ? true : false
}

IsLurePotionHotbarText(text) {
    lower := StrLower(text)
    if IsAllSeasonText(lower)
        return false
    return (InStr(lower, "lure") && (InStr(lower, "potion") || InStr(lower, "speed"))) ? true : false
}

IsEquippedBuffItem(name) {
    eq := GetEquippedToolName()
    if (eq = "")
        return false
    typeName := GetBuffItemType(name)
    if (typeName = "luck")
        return IsLuckPotionHotbarText(eq)
    if (typeName = "lure")
        return IsLurePotionHotbarText(eq)
    return (eq = name || InStr(StrLower(eq), StrLower(name)))
}

FindHotbarItemForBuffItem(name) {
    for alias in GetBuffItemHotbarAliases(name) {
        if (alias = "Luck Potion" || alias = "Lure Speed Potion")
            continue
        hit := FindHotbarItemByName(alias)
        if (hit)
            return hit
    }

    wantKind := GetBuffItemType(name)
    wantTier := ParseItemPotionTier(name)
    if (wantKind != "luck" && wantKind != "lure")
        return 0

    hotbar := GetHotbarGui()
    if !hotbar
        return 0

    fallback := 0
    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue
        slotText := CollectHotbarSlotText(itemAddr)
        if (wantKind = "luck") {
            if !IsLuckPotionHotbarText(slotText)
                continue
        } else {
            if !IsLurePotionHotbarText(slotText)
                continue
        }
        tier := ParseItemPotionTier(slotText)
        if (wantTier && tier && tier = wantTier)
            return itemAddr
        if (!tier && !fallback)
            fallback := itemAddr
        else if (tier && !fallback)
            fallback := itemAddr
    }
    return fallback
}

; Potions/shells are consumed on click — do not use TryUseHotbarItem (that waits for the tool to stay equipped).
TryUseBuffItem(name) {
    itemAddr := FindHotbarItemForBuffItem(name)
    if (!itemAddr)
        return false
    slotKey := ReadHotbarItemSlotKey(itemAddr)
    if (slotKey = "")
        return false

    Loop 2 {
        if !IsEquippedBuffItem(name) {
            if !SelectHotbarSlot(slotKey)
                return false
            waited := 0
            while (waited < 700 && !IsEquippedBuffItem(name)) {
                Sleep(50)
                waited += 50
            }
        }

        if !IsEquippedBuffItem(name)
            continue

        Click()
        Sleep(250)

        waited := 0
        while (waited < 900) {
            ScanActiveBuffState(true)
            if IsHudBuffActiveForItem(name)
                return true
            Sleep(150)
            waited += 150
        }

        ScanActiveBuffState(true)
        if IsHudBuffActiveForItem(name)
            return true
        ; Stacked potions may stay equipped after drinking one.
        return true
    }
    return false
}

GetBuffItemIntervalMs() {
    global MAIN
    sec := MAIN.Has("auto_totem_interval_sec") ? (MAIN["auto_totem_interval_sec"] + 0) : 900
    if (sec < 1)
        sec := 900
    return sec * 1000
}

IsBuffItemDueFor(name) {
    global MAIN, g_LastBuffItemSuccessAt, g_LastBuffItemAttemptAt

    if !IsSupportedBuffItem(name) || !IsBuffItemToggleEnabled(name)
        return false
    if (IsBuffItemCovered(name))
        return false

    if !(g_LastBuffItemSuccessAt is Map)
        g_LastBuffItemSuccessAt := Map()
    if !(g_LastBuffItemAttemptAt is Map)
        g_LastBuffItemAttemptAt := Map()

    if (MAIN.Has("auto_totem_mode") && MAIN["auto_totem_mode"] = "interval") {
        referenceAt := g_LastBuffItemSuccessAt.Has(name) ? g_LastBuffItemSuccessAt[name] : 0
        attemptAt := g_LastBuffItemAttemptAt.Has(name) ? g_LastBuffItemAttemptAt[name] : 0
        if (attemptAt > referenceAt)
            referenceAt := attemptAt
        return (!referenceAt || (A_TickCount - referenceAt) >= GetBuffItemIntervalMs())
    }

    attemptAt := g_LastBuffItemAttemptAt.Has(name) ? g_LastBuffItemAttemptAt[name] : 0
    if (attemptAt && (A_TickCount - attemptAt) < 4000)
        return false

    return true
}

GetNextDueBuffItem() {
    for name in GetEnabledBuffItems() {
        if (IsBuffItemDueFor(name))
            return name
    }
    return ""
}

IsAutoBuffItemRuntimeEnabled() {
    global MAIN
    return MAIN.Has("auto_totem_enabled") && MAIN["auto_totem_enabled"] && GetEnabledBuffItems().Length > 0
}

; Lightweight auto-use at cast boundary (shares 아이템 사용 master + totem interval/expire mode)
UpdateAutoBuffItems() {
    global Macro, g_BuffItemPending, g_BuffItemPendingName
    global g_LastBuffItemAttemptAt

    if !IsAutoBuffItemRuntimeEnabled() {
        g_BuffItemPending := false
        g_BuffItemPendingName := ""
        return false
    }

    if (IsSet(Macro) && Macro && (Macro.totemState != "IDLE" || Macro.totemPending))
        return false

    if (IsPublicServerEnabled() && IsTotemBlocked())
        return false

    if !Macro.cycleEnabled
        return false

    dueName := g_BuffItemPending ? g_BuffItemPendingName : GetNextDueBuffItem()
    if (dueName = "") {
        g_BuffItemPending := false
        g_BuffItemPendingName := ""
        return false
    }

    if !IsAutoTotemBoundary() {
        g_BuffItemPending := true
        g_BuffItemPendingName := dueName
        return false
    }

    g_BuffItemPending := false
    g_BuffItemPendingName := ""
    if !(g_LastBuffItemAttemptAt is Map)
        g_LastBuffItemAttemptAt := Map()
    g_LastBuffItemAttemptAt[dueName] := A_TickCount

    FocusRobloxWindow()
    ok := TryUseBuffItem(dueName)
    Sleep(150)
    try SelectHotbarSlot("1")
    catch {
    }

    if (ok) {
        MarkBuffItemUsed(dueName)
        ScanActiveBuffState(true)
        UpdateBuffStatusUi(true)
    }
    return ok
}
