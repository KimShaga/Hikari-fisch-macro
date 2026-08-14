; ============================================================================
;  Hikari's Edited Fisch Macro — Enchant (Keepers Altar / Enchant Anywhere)
; ============================================================================
#Requires AutoHotkey v2.0

ENCHANT_FIND_TIMEOUT_MS := 2500
ENCHANT_WALK_PER_GUI := 20000
ENCHANT_SPAM_MS := 500
ENCHANT_RESULT_WAIT_MS := 700

GetDefaultEnchantList() {
    return [
        ; Regular
        "Abyssal", "Blessed", "Breezed", "Chaotic", "Chronos", "Clever", "Controlled",
        "Divine", "Flashline", "Ghastly", "Hasty", "Hunter", "Insight", "Long", "Lucky",
        "Momentum", "Mutated", "Noir", "Quality", "Resilient", "Sacrificial", "Scavenger",
        "Scrapper", "Sea King", "Steady", "Storming", "Swift", "Unbreakable", "Wormhole",
        ; Exalted
        "Anomalous", "Ferocious", "Herculean", "Immortal", "Mystical", "Piercing",
        "Quantum", "Sea Overlord",
        ; Cosmic
        "Cryogenic", "Glittered", "Overclocked", "Sea Prince", "Tenacity", "Tryhard",
        "Vicious", "Wise",
        ; Twisted
        "Fractured", "Greed", "Putrid", "Pharaohs Curse", "Rage", "Weak", "Wobbly"
    ]
}

IsGamepassEnchantRuntimeEnabled() {
    global MAIN
    return MAIN.Has("gamepass_enchant_enabled") && MAIN["gamepass_enchant_enabled"] ? true : false
}

IsSovereignEnchantChargeEnabled() {
    global MAIN
    return MAIN.Has("sovereign_enchant_charge_enabled") && MAIN["sovereign_enchant_charge_enabled"] ? true : false
}

IsAutoSovereignEnchantChargeEnabled() {
    global MAIN, AutoSovereignEnchantCharge
    SyncAutoSovereignChargeSettingsFromUi()
    return MAIN.Has("auto_sovereign_enchant_charge_enabled") && MAIN["auto_sovereign_enchant_charge_enabled"] ? true : false
}

IsSovereignChargeModeActive() {
    global Macro
    if (IsSovereignEnchantChargeEnabled())
        return true
    return (IsSet(Macro) && Macro.HasOwnProp("enchantAutoCharge") && Macro.enchantAutoCharge) ? true : false
}

GetSovereignChargeTargetPercent() {
    global Macro
    if (IsSet(Macro) && Macro.HasOwnProp("enchantAutoCharge") && Macro.enchantAutoCharge) {
        if (Macro.HasOwnProp("enchantChargeUntil") && Macro.enchantChargeUntil > 0)
            return Max(1.0, Min(100.0, Macro.enchantChargeUntil + 0.0))
        return 100.0
    }
    return 99.0
}

GetAutoSovereignChargeBelowPercent() {
    return 95.0
}

; 체크박스만 UI에서 반영 (이하/목표는 95→100 고정)
SyncAutoSovereignChargeSettingsFromUi() {
    global MAIN, AutoSovereignEnchantCharge

    if (IsSet(AutoSovereignEnchantCharge) && AutoSovereignEnchantCharge)
        MAIN["auto_sovereign_enchant_charge_enabled"] := AutoSovereignEnchantCharge.Value ? 1 : 0

    MAIN["auto_sovereign_charge_below"] := 95
    MAIN["auto_sovereign_charge_until"] := 100
}

IsHoldingRelic() {
    name := GetEquippedToolName()
    if (name = "")
        return false
    n := StrLower(Trim(name))
    if (InStr(n, "relic"))
        return true
    return (n = "song of the deep")
}

IsRelicToolName(name) {
    n := StrLower(Trim(name))
    if (n = "")
        return false
    if (InStr(n, "relic"))
        return true
    return (n = "song of the deep")
}

HoldAutoChargeStatus(message, ms := 4000) {
    global Macro
    if (!IsSet(Macro) || !Macro)
        return
    Macro.autoChargeStatusHold := message
    Macro.autoChargeStatusHoldUntil := A_TickCount + ms
    SetEnchantStatus(message)
    UpdateMacroStatus(message, "---", "---")
}

; Just toggle inventory with ` — no GUI open-state probing.
; Start: press once to open. End: press once again to close (if we opened it).
SendInventoryToggleKey() {
    FocusRobloxWindow()
    Sleep(50)
    Send("``")
    Sleep(250)
}

EnsureGamepassInventoryOpen() {
    global Macro
    SendInventoryToggleKey()
    Macro.enchantOpenedInventory := true
    return true
}

EnsureGamepassInventoryClosed() {
    global Macro
    if (!(IsSet(Macro) && Macro.HasOwnProp("enchantOpenedInventory") && Macro.enchantOpenedInventory))
        return
    SendInventoryToggleKey()
    Macro.enchantOpenedInventory := false
}

ClearEnchantRuntimeCache() {
    global Macro

    Macro.enchantState := "IDLE"
    Macro.enchantLastError := ""
    Macro.enchantMode := ""
    Macro.enchantCachedX := 0
    Macro.enchantCachedY := 0
    Macro.enchantBaselineText := ""
    Macro.enchantSpamUntil := 0
    Macro.enchantLastClickAt := 0
    Macro.enchantWaitStartedAt := 0
    Macro.keeperPowerLabelAddr := 0
    Macro.keeperPowerBarAddr := 0
    Macro.keeperPowerFillAddr := 0
    Macro.enchantSundialAt := 0
    Macro.enchantOpenedInventory := false
}

ClearAutoSovereignChargeSession() {
    global Macro
    Macro.enchantResumeFishing := false
    Macro.enchantAutoCharge := false
    Macro.enchantChargeUntil := 0
}

KeeperboundChargeReached(p) {
    global Macro
    if (p = "")
        return false
    target := GetSovereignChargeTargetPercent()
    ; Auto-charge: honor configured target (tiny float slack only).
    if (IsSet(Macro) && Macro.HasOwnProp("enchantAutoCharge") && Macro.enchantAutoCharge)
        return (p + 0.0) + 0.05 >= target
    ; Manual altar charge: ~99% is treated as full when aiming for 100.
    threshold := (target >= 99.0) ? 99.0 : target
    return (p + 0.0) >= threshold
}

SetEnchantStatus(message) {
    global EnchantStatusText
    if (IsSet(EnchantStatusText) && EnchantStatusText)
        EnchantStatusText.Value := "상태: " message
}

; Dump path: backpack/hotbar/.../powerbar/bar/{fill, powerLabel="100% Power"}
; Prefer powerLabel text; fall back to fill Size.X (bar itself is not the fill %).
ResolveKeeperboundPowerNodes() {
    global Macro

    if (IsCachedAddrValid(Macro.keeperPowerLabelAddr, "powerLabel"))
        return true

    Macro.keeperPowerLabelAddr := 0
    Macro.keeperPowerBarAddr := 0
    Macro.keeperPowerFillAddr := 0

    hotbar := GetHotbarGui()
    if (!hotbar) {
        pg := FindPlayerGui()
        bp := pg ? FindChildByName(pg, "backpack") : 0
        hotbar := bp ? FindChildByName(bp, "hotbar") : 0
    }
    if (!hotbar)
        return false

    powerbar := FindGuiDescendantByName(hotbar, "powerbar", 12000)
    if (!powerbar)
        return false

    bar := FindChildByName(powerbar, "bar")
    label := bar ? FindChildByName(bar, "powerLabel") : 0
    if (!label)
        label := FindChildByName(powerbar, "powerLabel")
    fill := bar ? FindChildByName(bar, "fill") : 0

    if (!label && !fill)
        return false

    if (label)
        Macro.keeperPowerLabelAddr := label
    if (bar)
        Macro.keeperPowerBarAddr := bar
    if (fill)
        Macro.keeperPowerFillAddr := fill
    return true
}

ParsePowerPercentFromText(text) {
    text := Trim(RegExReplace(text, "<[^>]+>", " "))
    if (text = "")
        return ""
    if RegExMatch(text, "i)(\d+(?:\.\d+)?)\s*%", &m)
        return Max(0.0, Min(100.0, m[1] + 0.0))
    return ""
}

ReadKeeperboundFillPercent() {
    global Macro, OFFSETS
    if (!Macro.keeperPowerFillAddr || !OFFSETS.Has("FrameSizeX"))
        return ""
    try {
        base := OFFSETS["FrameSizeX"] + 0
        scaleX := ReadFloat(Macro.keeperPowerFillAddr + base + 0x0)
        scaleY := ReadFloat(Macro.keeperPowerFillAddr + base + 0x8)
        ; Horizontal fill uses Scale.X; some skins use Scale.Y.
        scale := scaleX
        if (scaleX < 0.02 && scaleY > scaleX)
            scale := scaleY
        if (scale != scale || scale < 0)
            return ""
        return Max(0.0, Min(100.0, scale * 100.0))
    } catch {
        return ""
    }
}

ReadKeeperboundPowerPercent() {
    global Macro

    if (!ResolveKeeperboundPowerNodes())
        return ""

    if (Macro.keeperPowerLabelAddr) {
        try {
            p := ParsePowerPercentFromText(ReadGuiText(Macro.keeperPowerLabelAddr))
            if (p != "")
                return p
        } catch {
        }
        ; Stale cache / unreadable label — force rediscover next call.
        Macro.keeperPowerLabelAddr := 0
    }

    p := ReadKeeperboundFillPercent()
    if (p != "")
        return p

    Macro.keeperPowerFillAddr := 0
    Macro.keeperPowerBarAddr := 0
    return ""
}

FormatEnchantProgressStatus(desired) {
    if (IsSovereignChargeModeActive()) {
        p := ReadKeeperboundPowerPercent()
        target := GetSovereignChargeTargetPercent()
        if (p = "")
            return Format("군주 파워 충전 중... (파워 UI 대기, 목표 {:.0f}%)", target)
        return Format("군주 파워 충전 중... {:.0f}% / 목표 {:.0f}%", p, target)
    }
    return desired " 찾는 중..."
}

; Keeperbound rods show hotbar powerbar / "N% Power" (dump). Enchanting then
; charges power instead of rolling a normal enchant.
IsRodSovereignEnchanted() {
    global Macro
    Macro.keeperPowerLabelAddr := 0
    Macro.keeperPowerFillAddr := 0
    if (ReadKeeperboundPowerPercent() != "")
        return true
    if (ResolveKeeperboundPowerNodes())
        return true

    ; Hotbar item name often prefixes the sovereign enchant (e.g. "Starforged Spirit ...").
    try {
        hay := CollectRodEnchantHaystack()
        if (hay != "" && RegExMatch(hay, "i)(starforged|menacing|glimmering|stonewake|propensity|keeperbound|steady crown|glimmering crown|stonewake crown|immortal might|swift might|magnitude might|menacing spirit|starforged spirit)"))
            return true
    } catch {
    }
    return false
}

; 군주 인챈트 낚싯대인데 충전 옵션이 꺼져 있으면 즉시 종료.
AbortIfSovereignWithoutCharge() {
    if (IsSovereignChargeModeActive())
        return false
    if (!IsRodSovereignEnchanted())
        return false
    StopEnchantCycle("OFF", "군주 인챈트 낚싯대입니다. '군주 인챈트 충전'을 켜세요.")
    return true
}

; Charge mode → stop at target Power. Normal mode → stop on desired enchant text.
; Altar dump (non-gamepass): powerLabel="100% Power" under hotbar powerbar.
TryCompleteEnchantGoal(desired) {
    global Macro
    if (AbortIfSovereignWithoutCharge())
        return true
    if (IsSovereignChargeModeActive()) {
        ; Always re-resolve — cached label can go stale while PromptConfirmation is up.
        Macro.keeperPowerLabelAddr := 0
        Macro.keeperPowerFillAddr := 0
        p := ReadKeeperboundPowerPercent()
        if (KeeperboundChargeReached(p)) {
            CompleteEnchantCycle(Format("군주 파워 충전 완료 ({:.0f}%).", p))
            return true
        }
        return false
    }
    if (desired != "" && HasDesiredEnchant(desired)) {
        CompleteEnchantCycle(desired " 발견.")
        return true
    }
    return false
}

IsKeepersAwaitPromptOpen() {
    return FindKeepersPromptClickTarget() ? true : false
}

FindPromptConfirmation() {
    playerGui := FindPlayerGui()
    if (!playerGui)
        return 0
    prompt := FindChildByName(playerGui, "PromptConfirmation")
    if (prompt)
        return prompt
    return FindChildByNameCI(playerGui, "PromptConfirmation")
}

GetPromptOptionButtonLabel(btnAddr) {
    try {
        for childAddr in ReadChildren(btnAddr) {
            try {
                cName := ReadInstanceName(childAddr)
                cClass := ReadClassName(childAddr)
                if (cName = "Label" || cClass = "TextLabel") {
                    t := Trim(ReadGuiText(childAddr))
                    if (t != "")
                        return t
                }
            } catch {
                continue
            }
        }
    } catch {
    }
    try {
        t := Trim(ReadGuiText(btnAddr))
        if (t != "")
            return t
    } catch {
    }
    return ""
}

KeepersPromptTargetHasRect(addr) {
    if (!addr)
        return false
    if (HasValidGuiClickRect(addr))
        return true
    try {
        for childAddr in ReadChildren(addr) {
            try {
                if (HasValidGuiClickRect(childAddr))
                    return true
            } catch {
                continue
            }
        }
    } catch {
    }
    return false
}

; PromptConfirmation Options: Label="[Enchant Fishing Rod]" / "[Cancel]"
; Button instance name is often just "Button". Require a real on-screen rect so a
; leftover hidden ScreenGui does not count as open.
FindKeepersPromptClickTarget() {
    prompt := FindPromptConfirmation()
    if (!prompt)
        return 0

    best := 0
    bestScore := -1
    stack := [prompt]
    visited := 0
    while (stack.Length > 0 && visited < 4000) {
        addr := stack.Pop()
        visited += 1
        try {
            className := ReadClassName(addr)
            if (className = "TextButton" || className = "ImageButton") {
                name := StrLower(Trim(ReadInstanceName(addr)))
                label := StrLower(GetPromptOptionButtonLabel(addr))
                if (InStr(label, "cancel") || name = "cancel" || InStr(name, "cancel")) {
                } else if (KeepersPromptTargetHasRect(addr)) {
                    score := 1
                    if (InStr(label, "enchant fishing rod"))
                        score := 100
                    else if (InStr(label, "enchant") && !InStr(label, "spear") && !InStr(label, "harpoon"))
                        score := 80
                    if (score > bestScore) {
                        bestScore := score
                        best := addr
                    }
                    if (score >= 100)
                        return addr
                }
            } else if (className = "TextLabel") {
                label := StrLower(Trim(ReadGuiText(addr)))
                if (InStr(label, "enchant fishing rod") && HasValidGuiClickRect(addr)) {
                    parent := 0
                    try parent := ReadParent(addr)
                    catch {
                        parent := 0
                    }
                    if (parent) {
                        try {
                            pClass := ReadClassName(parent)
                            if (pClass = "TextButton" || pClass = "ImageButton")
                                return parent
                        } catch {
                        }
                    }
                    return addr
                }
            }
            for childAddr in ReadChildren(addr)
                stack.Push(childAddr)
        } catch {
            continue
        }
    }
    return (bestScore >= 80) ? best : 0
}

ClickGuiInstanceNoCache(addr) {
    if (!addr)
        return false
    pos := 0
    if (HasValidGuiClickRect(addr))
        pos := GuiCenterToScreen(addr)
    if (!IsObject(pos)) {
        try {
            for childAddr in ReadChildren(addr) {
                if (HasValidGuiClickRect(childAddr)) {
                    pos := GuiCenterToScreen(childAddr)
                    if (IsObject(pos))
                        break
                }
            }
        } catch {
        }
    }
    if (!IsObject(pos))
        return false
    FocusRobloxWindow()
    ReliableScreenClick(pos.x, pos.y, 3, 5)
    return true
}

; First-enchant-on-server warning. Click [Enchant Fishing Rod] once — never again
; this session, and do not overwrite the altar/gamepass Enchant coordinate cache.
DismissKeepersAwaitPrompt() {
    global Macro
    if (Macro.HasOwnProp("keepersPromptClicked") && Macro.keepersPromptClicked)
        return false
    target := FindKeepersPromptClickTarget()
    if (!target)
        return false
    if (!ClickGuiInstanceNoCache(target))
        return false
    Macro.keepersPromptClicked := true
    Macro.keepersPromptClickedAt := A_TickCount
    Macro.enchantLastClickAt := A_TickCount
    ; Keepers prompt only: close leftover UI with ` twice.
    FocusRobloxWindow()
    Sleep(80)
    Send("``")
    Sleep(80)
    Send("``")
    return true
}

; True = caller should return this tick (goal done, or Keepers prompt handled).
HandleKeepersAwaitIfOpen(desired := "") {
    global Macro
    if (TryCompleteEnchantGoal(desired))
        return true

    already := Macro.HasOwnProp("keepersPromptClicked") && Macro.keepersPromptClicked
    if (already) {
        ; Dialog may still be on screen — wait briefly, but do not click it again.
        if (IsKeepersAwaitPromptOpen() && Macro.HasOwnProp("keepersPromptClickedAt")
            && (A_TickCount - Macro.keepersPromptClickedAt) < 1200)
            return true
        return false
    }

    if (!IsKeepersAwaitPromptOpen())
        return false

    if (IsSovereignChargeModeActive()) {
        p := ReadKeeperboundPowerPercent()
        if (KeeperboundChargeReached(p)) {
            CompleteEnchantCycle(Format("군주 파워 충전 완료 ({:.0f}%).", p))
            return true
        }
    }

    if (DismissKeepersAwaitPrompt())
        SetEnchantStatus("Keepers 확인창 — Enchant Fishing Rod")
    return true
}

; Altar (non-gamepass) charge: stop if already 100%; otherwise clear Keepers prompt then enchantButton.
HandleAltarChargeUi(desired) {
    return HandleKeepersAwaitIfOpen(desired)
}

NormalizeEnchantText(text) {
    text := StrReplace(text, "`r", "`n")
    text := RegExReplace(text, "<[^>]+>")
    text := RegExReplace(text, "\s+", " ")
    return StrLower(Trim(text))
}

CollectRodEnchantHaystack() {
    parts := []

    try {
        rodText := GetHotbarRodDisplayText()
        if (rodText != "")
            parts.Push(rodText)
    } catch {
    }

    try {
        tool := GetEquippedToolName()
        if (tool != "")
            parts.Push(tool)
    } catch {
    }

    out := ""
    for part in parts {
        if (out != "")
            out .= " "
        out .= part
    }
    return NormalizeEnchantText(out)
}

HasDesiredEnchant(desiredEnchant) {
    desired := NormalizeEnchantText(desiredEnchant)
    if (desired = "")
        return false
    haystack := CollectRodEnchantHaystack()
    if (haystack = "")
        return false
    return InStr(haystack, desired) ? true : false
}

NormalizeEnchantButtonKey(name) {
    n := StrLower(Trim(name))
    n := StrReplace(n, " ", "")
    n := StrReplace(n, "_", "")
    n := StrReplace(n, "-", "")
    return n
}

IsInventoryEnchantParent(parentName) {
    if (parentName = "")
        return false
    if (parentName = "TopButtons")
        return true
    pn := StrLower(parentName)
    return (InStr(pn, "backpack") || InStr(pn, "hotbar") || InStr(pn, "inventory") || InStr(pn, "toolbar"))
}

; 덤프 기준:
;  제단 = ImageButton "enchantButton" (parent EnchantConfirm)
;  게임패스 = TextButton "Enchant" (parent TopButtons)
IsAltarEnchantButtonName(name) {
    n := StrLower(Trim(name))
    return (n = "enchantbutton")
}

IsGamepassEnchantButtonName(name) {
    n := StrLower(Trim(name))
    return (n = "enchant" || n = "enchantrod" || n = "enchant rod")
}

FindEnchantConfirmRoot(playerGui) {
    ; EnchantConfirm 프레임을 먼저 찾으면 enchantButton이 바로 아래에 있음
    root := FindChildByName(playerGui, "EnchantConfirm")
    if (root)
        return root
    return FindGuiDescendantByName(playerGui, "EnchantConfirm", 40000)
}

FindAltarEnchantButtonUnder(rootAddr, walkLimit) {
    if (!rootAddr)
        return 0

    best := 0
    stack := [rootAddr]
    visited := 0

    while (stack.Length > 0 && visited < walkLimit) {
        addr := stack.Pop()
        visited += 1

        try {
            name := ReadInstanceName(addr)
            if (IsAltarEnchantButtonName(name)) {
                parent := ReadParent(addr)
                parentName := parent ? ReadInstanceName(parent) : ""
                if (!IsInventoryEnchantParent(parentName)) {
                    className := ReadClassName(addr)
                    sized := HasValidGuiClickRect(addr)
                    ; 덤프: ImageButton enchantButton
                    if (sized && (className = "ImageButton" || className = "TextButton"))
                        return addr
                    if (!best)
                        best := addr
                }
            }

            children := ReadChildren(addr)
            i := children.Length
            while (i >= 1) {
                stack.Push(children[i])
                i -= 1
            }
        } catch {
            continue
        }
    }
    return best
}

; 제단: enchantButton (EnchantConfirm) — TopButtons Enchant 절대 사용 안 함
FindEnchantButton() {
    global ENCHANT_WALK_PER_GUI, g_CachedPlayerGui

    playerGui := FindPlayerGui()
    if (!playerGui) {
        g_CachedPlayerGui := 0
        playerGui := FindPlayerGui()
    }
    if (!playerGui)
        return 0

    ; 1) EnchantConfirm 바로 아래 (가장 빠름)
    try {
        confirm := FindEnchantConfirmRoot(playerGui)
        if (confirm) {
            hit := FindAltarEnchantButtonUnder(confirm, 2000)
            if (hit)
                return hit
            ; Confirm 루트 자체가 버튼 부모일 수 있음
            for childAddr in ReadChildren(confirm) {
                try {
                    if (IsAltarEnchantButtonName(ReadInstanceName(childAddr)))
                        return childAddr
                } catch {
                }
            }
        }
    } catch {
    }

    ; 2) ScreenGui 단위 — backpack 스킵
    try {
        for childPtr in ReadChildren(playerGui) {
            try {
                childName := StrLower(ReadInstanceName(childPtr))
                if (childName = "backpack" || InStr(childName, "backpack"))
                    continue
            } catch {
            }
            hit := FindAltarEnchantButtonUnder(childPtr, ENCHANT_WALK_PER_GUI)
            if (hit)
                return hit
        }
    } catch {
    }

    return 0
}

; 게임패스: TopButtons / Enchant (Appraise와 동일)
FindEnchantRodButton() {
    global ENCHANT_WALK_PER_GUI, g_CachedPlayerGui

    playerGui := FindPlayerGui()
    if (!playerGui) {
        g_CachedPlayerGui := 0
        playerGui := FindPlayerGui()
    }
    if (!playerGui)
        return 0

    try {
        for childPtr in ReadChildren(playerGui) {
            topButtons := FindGuiDescendantByName(childPtr, "TopButtons", ENCHANT_WALK_PER_GUI)
            if (topButtons) {
                for btnAddr in ReadChildren(topButtons) {
                    try {
                        if (IsGamepassEnchantButtonName(ReadInstanceName(btnAddr))) {
                            className := ReadClassName(btnAddr)
                            if ((className = "TextButton" || className = "ImageButton") && HasValidGuiClickRect(btnAddr))
                                return btnAddr
                        }
                    } catch {
                    }
                }
            }
        }
    } catch {
    }

    ; 폴백: TopButtons 밖 Enchant (단 EnchantConfirm/enchantButton은 제단용이므로 제외)
    try {
        for childPtr in ReadChildren(playerGui) {
            hit := FindGamepassEnchantFallbackUnder(childPtr, ENCHANT_WALK_PER_GUI)
            if (hit)
                return hit
        }
    } catch {
    }
    return 0
}

FindGamepassEnchantFallbackUnder(rootAddr, walkLimit) {
    if (!rootAddr)
        return 0
    stack := [rootAddr]
    visited := 0
    while (stack.Length > 0 && visited < walkLimit) {
        addr := stack.Pop()
        visited += 1
        try {
            name := ReadInstanceName(addr)
            if (IsGamepassEnchantButtonName(name)) {
                parent := ReadParent(addr)
                parentName := parent ? ReadInstanceName(parent) : ""
                if (parentName = "EnchantConfirm" || IsAltarEnchantButtonName(name)) {
                    ; skip
                } else {
                    className := ReadClassName(addr)
                    if ((className = "TextButton" || className = "ImageButton") && HasValidGuiClickRect(addr))
                        return addr
                }
            }
            children := ReadChildren(addr)
            i := children.Length
            while (i >= 1) {
                stack.Push(children[i])
                i -= 1
            }
        } catch {
            continue
        }
    }
    return 0
}

ResolveEnchantButtonWithTimeout(finderFn, timeoutMs := unset) {
    global ENCHANT_FIND_TIMEOUT_MS

    if (!IsSet(timeoutMs))
        timeoutMs := ENCHANT_FIND_TIMEOUT_MS

    deadline := A_TickCount + timeoutMs
    loop {
        btn := finderFn()
        if (btn && HasValidGuiClickRect(btn))
            return btn
        if (btn)
            return btn
        if (A_TickCount >= deadline)
            break
        Sleep(15)
    }
    return 0
}

DumpEnchantGuiDebug(*) {
    global APPDATA_DIR, EnchantStatusText

    path := APPDATA_DIR "\enchant-gui-dump.txt"
    lines := []
    lines.Push("=== Enchant GUI dump " A_Now " ===")
    lines.Push("")
    lines.Push("")

    if (!IsMemoryReady() || !IsInFischGame()) {
        lines.Push("Roblox/Fisch 미연결")
        out := ""
        for line in lines {
            if (out != "")
                out .= "`n"
            out .= line
        }
        try FileDelete(path)
        catch {
        }
        FileAppend(out "`n", path, "UTF-8")
        try Run('notepad.exe "' path '"')
        SetEnchantStatus("덤프 실패: 미연결")
        return
    }

    playerGui := FindPlayerGui()
    if (!playerGui) {
        lines.Push("PlayerGui 없음")
    } else {
        lines.Push("========== PlayerGui children ==========")
        try {
            for childPtr in ReadChildren(playerGui) {
                try {
                    lines.Push("  [" ReadClassName(childPtr) "] " ReadInstanceName(childPtr))
                } catch {
                }
            }
        } catch as err {
            lines.Push("children error: " err.Message)
        }
        lines.Push("")

        for rootName in ["PromptConfirmation", "RelicsPlayer", "backpack", "ProximityPrompts", "hud", "EventAppraise", "quickAccess"] {
            lines.Push("========== " rootName " ==========")
            try {
                root := FindChildByName(playerGui, rootName)
                if (!root)
                    root := FindGuiDescendantByName(playerGui, rootName, 30000)
                if (root)
                    DumpGuiInstanceTree(root, rootName, lines, 0, 8, 1200)
                else
                    lines.Push("(없음)")
            } catch as err {
                lines.Push("error: " err.Message)
            }
            lines.Push("")
        }

        lines.Push("========== Enchant-like TextButtons (scan) ==========")
        try {
            stack := [playerGui]
            visited := 0
            found := 0
            while (stack.Length > 0 && visited < 120000 && found < 80) {
                addr := stack.Pop()
                visited += 1
                try {
                    className := ReadClassName(addr)
                    name := ReadInstanceName(addr)
                    n := NormalizeEnchantButtonKey(name)
                    interesting := (className = "TextButton" || className = "ImageButton")
                        && (InStr(n, "enchant") || n = "yes" || n = "confirm" || n = "ok"
                            || InStr(StrLower(name), "enchant") || name = "TopButtons")
                    if (interesting || name = "TopButtons") {
                        parent := ReadParent(addr)
                        parentName := parent ? ReadInstanceName(parent) : ""
                        rect := ReadAbsoluteRect(addr)
                        text := ""
                        try text := ReadGuiText(addr)
                        catch {
                        }
                        lines.Push(
                            "[" className "] name=" name
                            " parent=" parentName
                            " size=" Round(rect.w) "x" Round(rect.h)
                            " text=`"" RegExReplace(text, "[\r\n\t]+", " ") "`""
                        )
                        found += 1
                    }
                    for childAddr in ReadChildren(addr)
                        stack.Push(childAddr)
                } catch {
                    continue
                }
            }
            lines.Push("(scanned nodes=" visited ", listed=" found ")")
        } catch as err {
            lines.Push("scan error: " err.Message)
        }
    }

    out := ""
    for line in lines {
        if (out != "")
            out .= "`n"
        out .= line
    }
    try FileDelete(path)
    catch {
    }
    FileAppend(out "`n", path, "UTF-8")
    try A_Clipboard := path
    try Run('notepad.exe "' path '"')
    SetEnchantStatus("덤프 저장: " path)
}

ClickEnchantGuiButton(btn) {
    global Macro

    pos := GuiCenterToScreen(btn)
    if (!IsObject(pos))
        throw Error("인챈트 클릭 좌표 계산 실패")
    Macro.enchantCachedX := pos.x
    Macro.enchantCachedY := pos.y
    ReliableScreenClick(pos.x, pos.y, 3, 5)
    Macro.enchantLastClickAt := A_TickCount
}

; Altar (gamepass off) only works at night. Daytime → use hotbar Sundial Totem, else stop.
EnsureAltarEnchantNightOrAbort() {
    global Macro

    if (IsNightCycle())
        return true

    if (!IsDayCycle())
        return true  ; unknown cycle — don't block

    ; Throttle sundial attempts.
    if (Macro.enchantSundialAt && (A_TickCount - Macro.enchantSundialAt) < 4000)
        return false

    if (!FindHotbarItemByName("Sundial Totem")) {
        StopEnchantCycle("OFF", "낮입니다. 핫바에 Sundial Totem이 없어 종료합니다.")
        return false
    }

    FocusRobloxWindow()
    if (!TryUseHotbarItem("Sundial Totem")) {
        StopEnchantCycle("OFF", "낮입니다. Sundial Totem 사용에 실패해 종료합니다.")
        return false
    }

    Macro.enchantSundialAt := A_TickCount
    Macro.enchantState := "WAIT_NIGHT"
    SetEnchantStatus("Sundial Totem 사용 — 밤이 될 때까지 대기...")
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    return false
}

TryReequipEnchantRelic() {
    if (IsHoldingRelic())
        return true

    for name in ["Enchant Relic", "Song of the Deep", "Exalted Relic", "Cosmic Relic", "Sovereign Relic"] {
        if (FindHotbarItemByName(name)) {
            slotKey := GetHotbarItemSlotKey(name)
            if (slotKey != "" && SelectHotbarSlot(slotKey)) {
                Sleep(250)
                if (IsHoldingRelic() || IsRelicToolName(GetEquippedToolName()) || IsRelicToolName(name))
                    return true
                ; Hotbar select succeeded — Tool instance name can lag behind UI text.
                return true
            }
        }
    }

    ; Partial match: any hotbar ItemName containing "relic"
    hotbar := GetHotbarGui()
    if (!hotbar)
        return false
    for itemAddr in ReadChildren(hotbar) {
        try {
            if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
                continue
            itemName := ReadHotbarItemName(itemAddr)
            if (itemName = "" || !IsRelicToolName(itemName))
                continue
            slotKey := ReadHotbarItemSlotKey(itemAddr)
            if (slotKey = "")
                continue
            if (SelectHotbarSlot(slotKey)) {
                Sleep(250)
                return true
            }
        } catch {
            continue
        }
    }
    return false
}

StartEnchantCycle() {
    global Macro, MAIN

    if (!IsHoldingRelic()) {
        MsgBox("인챈트할 때 Relic(또는 Song of the Deep)을 들고 있어야 합니다.", "인챈트")
        return false
    }

    desired := Trim(MAIN["auto_enchant_name"])
    if (!IsSovereignChargeModeActive() && desired = "") {
        SetEnchantStatus("목표 인챈트를 선택하세요.")
        MsgBox("시작 전에 목표 인챈트를 선택하세요.", "인챈트")
        return false
    }

    ReleaseMouse(true)
    ClearEnchantRuntimeCache()

    if (AbortIfSovereignWithoutCharge())
        return false

    Macro.phase := "ENCHANT"
    Macro.enchantMode := "altar"
    Macro.cycleEnabled := true
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")

    ; Gamepass off = altar. Night required.
    if (IsDayCycle()) {
        if (!FindHotbarItemByName("Sundial Totem")) {
            StopEnchantCycle("OFF", "낮입니다. 핫바에 Sundial Totem이 없어 종료합니다.")
            return false
        }
        Macro.enchantState := "WAIT_NIGHT"
        SetEnchantStatus("낮 — Sundial Totem으로 밤 전환 시도...")
        EnsureAltarEnchantNightOrAbort()
        return Macro.phase = "ENCHANT"
    }

    Macro.enchantState := "RESOLVING"
    SetEnchantStatus(IsSovereignChargeModeActive() ? "군주 파워 충전 준비..." : "인챈트 준비 중...")

    try {
        if (TryCompleteEnchantGoal(desired))
            return true
        Macro.enchantState := "PRESS_E"
        SetEnchantStatus(IsSovereignChargeModeActive() ? FormatEnchantProgressStatus(desired) : "제단 상호작용(E)...")
        return true
    } catch as err {
        FailEnchantCycle(err.Message)
        return false
    }
}

StartGamepassEnchantCycle(silent := false) {
    global Macro, MAIN

    autoCharge := IsSet(Macro) && Macro.HasOwnProp("enchantAutoCharge") && Macro.enchantAutoCharge
    if (!IsHoldingRelic()) {
        Sleep(autoCharge ? 250 : 0)
        if (!IsHoldingRelic() && !autoCharge) {
            if (!silent)
                MsgBox("인챈트할 때 Relic(또는 Song of the Deep)을 들고 있어야 합니다.", "게임패스 인챈트")
            return false
        }
        ; Auto path: hotbar already switched to Relic; Tool name may lag.
    }

    desired := Trim(MAIN["auto_enchant_name"])
    if (!IsSovereignChargeModeActive() && desired = "") {
        SetEnchantStatus("목표 인챈트를 선택하세요.")
        if (!silent)
            MsgBox("시작 전에 목표 인챈트를 선택하세요.", "게임패스 인챈트")
        return false
    }

    ReleaseMouse(true)
    ClearEnchantRuntimeCache()

    if (AbortIfSovereignWithoutCharge())
        return false

    Macro.phase := "GP_ENCHANT"
    Macro.enchantMode := "gamepass"
    Macro.enchantState := "GP_RESOLVE"
    Macro.cycleEnabled := true
    EnsureGamepassInventoryOpen()
    SetEnchantStatus(IsSovereignChargeModeActive() ? "군주 파워 충전 시작..." : "게임패스 인챈트 시작...")
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    return true
}

StopEnchantCycle(nextPhase := "OFF", status := "중지됨.") {
    global Macro

    ReleaseMouse(true)
    EnsureGamepassInventoryClosed()
    Macro.cycleEnabled := false
    Macro.phase := nextPhase
    ClearAutoSovereignChargeSession()

    if (nextPhase = "OFF")
        ClearEnchantRuntimeCache()
    else
        Macro.enchantState := nextPhase

    SetEnchantStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

ResumeFishingAfterAutoSovereignCharge() {
    global Macro
    EnsureGamepassInventoryClosed()
    Macro.cycleEnabled := true
    try SelectHotbarSlot("1")
    catch {
    }
    Sleep(150)
    StartMacroCycle()
}

CompleteEnchantCycle(status) {
    global Macro
    resume := Macro.HasOwnProp("enchantResumeFishing") && Macro.enchantResumeFishing
    Macro.cycleEnabled := false
    Macro.phase := "DONE"
    Macro.enchantState := "DONE"
    EnsureGamepassInventoryClosed()
    ClearEnchantRuntimeCache()
    ClearAutoSovereignChargeSession()
    SetEnchantStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    if (resume) {
        Macro.cycleEnabled := true
        ResumeFishingAfterAutoSovereignCharge()
    }
}

FailEnchantCycle(message) {
    global Macro
    resume := Macro.HasOwnProp("enchantResumeFishing") && Macro.enchantResumeFishing
    Macro.cycleEnabled := false
    Macro.phase := "FAILED"
    Macro.enchantState := "FAILED"
    Macro.enchantLastError := message
    EnsureGamepassInventoryClosed()
    ClearAutoSovereignChargeSession()
    if (resume)
        Macro.autoSovereignChargeCooldownUntil := A_TickCount + 15000
    SetEnchantStatus(message)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    if (resume) {
        Macro.cycleEnabled := true
        ResumeFishingAfterAutoSovereignCharge()
    }
}

; Fishing cast start: if power <= below, switch to Relic and GP-charge until target.
MaybeStartAutoSovereignChargeFromFishing() {
    global Macro, MAIN

    if (!IsAutoSovereignEnchantChargeEnabled())
        return false
    if (!IsSet(Macro))
        return false
    if (Macro.phase = "ENCHANT" || Macro.phase = "GP_ENCHANT")
        return false
    if (Macro.HasOwnProp("autoSovereignChargeCooldownUntil") && Macro.autoSovereignChargeCooldownUntil > 0
        && A_TickCount < Macro.autoSovereignChargeCooldownUntil)
        return false

    below := GetAutoSovereignChargeBelowPercent()
    untilPct := 100.0

    Macro.keeperPowerLabelAddr := 0
    Macro.keeperPowerFillAddr := 0
    p := ReadKeeperboundPowerPercent()
    if (p = "") {
        HoldAutoChargeStatus("자동 충전: 군주 파워 UI 없음", 2500)
        return false
    }
    if ((p + 0.0) > below) {
        HoldAutoChargeStatus(Format("충전 안 함: 파워 {:.1f}% > 이하 {:.1f}% (낚시 계속)", p, below), 3500)
        return false
    }
    ; Do NOT treat 99% as "full" when target is 100 — that skipped real top-ups.
    if ((p + 0.0) + 0.05 >= untilPct) {
        HoldAutoChargeStatus(Format("충전 안 함: 이미 {:.1f}% (목표 {:.1f}%)", p, untilPct), 3500)
        return false
    }

    if (!TryReequipEnchantRelic()) {
        Macro.autoSovereignChargeCooldownUntil := A_TickCount + 15000
        HoldAutoChargeStatus(Format("자동 충전 실패: Relic 슬롯 선택 실패 (파워 {:.1f}%)", p), 5000)
        return false
    }

    Macro.enchantResumeFishing := true
    Macro.enchantAutoCharge := true
    Macro.enchantChargeUntil := untilPct
    Macro.autoSovereignChargeCooldownUntil := 0

    if (!StartGamepassEnchantCycle(true)) {
        ClearAutoSovereignChargeSession()
        Macro.autoSovereignChargeCooldownUntil := A_TickCount + 15000
        HoldAutoChargeStatus(Format("자동 충전 시작 실패 (파워 {:.1f}%)", p), 5000)
        try SelectHotbarSlot("1")
        catch {
        }
        return false
    }

    HoldAutoChargeStatus(Format("자동 군주 충전 중 ({:.1f}% → {:.0f}%)...", p, untilPct), 2000)
    return true
}

UpdateEnchantPhase() {
    global Macro, MAIN, ENCHANT_SPAM_MS

    desired := Trim(MAIN["auto_enchant_name"])
    delayMs := MAIN.Has("enchant_delay_ms") ? (MAIN["enchant_delay_ms"] + 0) : 0

    switch Macro.enchantState {
        case "WAIT_NIGHT":
            if (TryCompleteEnchantGoal(desired))
                return
            if (IsNightCycle()) {
                if (!TryReequipEnchantRelic()) {
                    Macro.enchantState := "WAIT_RELIC"
                    SetEnchantStatus("밤 확인. 릴릭을 다시 장착하세요...")
                    return
                }
                Macro.enchantState := "PRESS_E"
                SetEnchantStatus(IsSovereignChargeModeActive()
                    ? FormatEnchantProgressStatus(desired)
                    : "제단 상호작용(E)...")
                return
            }
            if (IsDayCycle()) {
                EnsureAltarEnchantNightOrAbort()
                return
            }
            ; Unknown cycle — keep waiting briefly
            SetEnchantStatus("시간대 확인 중...")

        case "PRESS_E":
            if (!IsHoldingRelic()) {
                Macro.enchantState := "WAIT_RELIC"
                SetEnchantStatus("릴릭을 다시 장착하세요...")
                return
            }
            try {
                if (HandleAltarChargeUi(desired))
                    return
                if (TryCompleteEnchantGoal(desired))
                    return
            } catch {
            }
            if (IsDayCycle()) {
                Macro.enchantState := "WAIT_NIGHT"
                SetEnchantStatus("낮 — Sundial Totem / 밤 대기...")
                EnsureAltarEnchantNightOrAbort()
                return
            }
            FocusRobloxWindow()
            Send("{e}")
            Macro.enchantLastClickAt := A_TickCount
            Macro.enchantState := "CLICK"
            SetEnchantStatus(Macro.enchantCachedX ? "Enchant 연타..." : "Enchant 버튼 찾는 중...")

        case "CLICK":
            if ((A_TickCount - Macro.enchantLastClickAt) < delayMs)
                return
            try {
                if (!IsHoldingRelic()) {
                    Macro.enchantState := "WAIT_RELIC"
                    SetEnchantStatus("릴릭을 다시 장착하세요...")
                    return
                }
                if (HandleAltarChargeUi(desired))
                    return
                if (TryCompleteEnchantGoal(desired))
                    return
                FocusRobloxWindow()
                ; 제단: EnchantConfirm.enchantButton (게임패스 TopButtons 아님)
                Send("{e}")
                if (Macro.enchantCachedX && Macro.enchantCachedY) {
                    ReliableScreenClick(Macro.enchantCachedX, Macro.enchantCachedY, 3, 5)
                    Macro.enchantLastClickAt := A_TickCount
                } else {
                    if (!FindPlayerGui())
                        throw Error("PlayerGui를 찾지 못했습니다.")
                    btn := ResolveEnchantButtonWithTimeout(FindEnchantButton)
                    if (!btn)
                        throw Error("Enchant 버튼을 찾지 못했습니다. E 후 Enchant UI가 떴는지 확인하세요.")
                    ClickEnchantGuiButton(btn)
                }
                try Macro.enchantBaselineText := CollectRodEnchantHaystack()
                catch {
                }
                Macro.enchantSpamUntil := A_TickCount + ENCHANT_SPAM_MS
                Macro.enchantState := "SPAM"
                SetEnchantStatus(IsSovereignChargeModeActive() ? FormatEnchantProgressStatus(desired) : "E + Enchant 연타 중...")
            } catch as err {
                ; 좌표 캐시는 유지 — 못 찾았을 때만 지움
                if (!Macro.enchantCachedX) {
                    Macro.enchantLastError := err.Message
                    if (!Macro.enchantLastClickAt || A_TickCount - Macro.enchantLastClickAt >= 250) {
                        Macro.enchantLastClickAt := A_TickCount
                        SetEnchantStatus(err.Message " — E 재시도...")
                    }
                    Macro.enchantState := "PRESS_E"
                } else {
                    Macro.enchantSpamUntil := A_TickCount + ENCHANT_SPAM_MS
                    Macro.enchantState := "SPAM"
                }
            }

        case "SPAM":
            try {
                if (HandleAltarChargeUi(desired))
                    return
                if (TryCompleteEnchantGoal(desired))
                    return
            } catch {
            }
            ; E + Enter + (캐시 있으면) Enchant 클릭
            Send("{e}")
            Send("{Enter}")
            if (Macro.enchantCachedX && Macro.enchantCachedY)
                ReliableScreenClick(Macro.enchantCachedX, Macro.enchantCachedY, 2, 3)

            try {
                if (TryCompleteEnchantGoal(desired))
                    return
                current := CollectRodEnchantHaystack()
                if (current != "" && Macro.enchantBaselineText != "" && current != Macro.enchantBaselineText) {
                    Macro.enchantBaselineText := current
                    if (TryCompleteEnchantGoal(desired))
                        return
                    if (!IsHoldingRelic()) {
                        Macro.enchantState := "WAIT_RELIC"
                        SetEnchantStatus(IsSovereignChargeModeActive()
                            ? "충전 진행. 릴릭을 다시 장착하세요..."
                            : desired " 아님. 릴릭을 다시 장착하세요...")
                        return
                    }
                    ; 좌표 유지한 채 바로 다시 연타
                    Macro.enchantState := "CLICK"
                    SetEnchantStatus(FormatEnchantProgressStatus(desired))
                    return
                }
            } catch {
            }

            if (A_TickCount >= Macro.enchantSpamUntil) {
                try {
                    if (TryCompleteEnchantGoal(desired))
                        return
                } catch {
                }
                if (!IsHoldingRelic()) {
                    Macro.enchantState := "WAIT_RELIC"
                    SetEnchantStatus("릴릭을 다시 장착하세요...")
                    return
                }
                Macro.enchantState := "CLICK"
                SetEnchantStatus(IsSovereignChargeModeActive()
                    ? FormatEnchantProgressStatus(desired)
                    : desired " E+Enchant 연타...")
            }

        case "WAIT_RELIC":
            try {
                if (TryCompleteEnchantGoal(desired))
                    return
            } catch {
            }
            if (IsHoldingRelic()) {
                Macro.enchantState := "CLICK"
                SetEnchantStatus("릴릭 확인됨. E + Enchant 연타 재개...")
            }
    }
}

UpdateGamepassEnchantPhase() {
    global Macro, MAIN, ENCHANT_SPAM_MS

    desired := Trim(MAIN["auto_enchant_name"])

    switch Macro.enchantState {
        case "GP_RESOLVE":
            try {
                if (TryCompleteEnchantGoal(desired))
                    return
                Macro.enchantBaselineText := CollectRodEnchantHaystack()
            } catch {
                Macro.enchantBaselineText := ""
            }
            if (!IsHoldingRelic()) {
                Macro.enchantState := "GP_WAIT_RELIC"
                SetEnchantStatus("릴릭을 들고 Enchant UI를 여세요...")
                return
            }
            Macro.enchantState := "GP_CLICK"
            SetEnchantStatus(Macro.enchantCachedX ? "Enchant 연타..." : "Enchant 버튼 찾는 중...")

        case "GP_WAIT_RELIC":
            try {
                if (TryCompleteEnchantGoal(desired))
                    return
            } catch {
            }
            if (IsHoldingRelic()) {
                Macro.enchantState := "GP_CLICK"
                SetEnchantStatus(Macro.enchantCachedX ? "Enchant 연타..." : "Enchant 버튼 찾는 중...")
            }

        case "GP_CLICK":
            try {
                if (!IsHoldingRelic()) {
                    Macro.enchantState := "GP_WAIT_RELIC"
                    SetEnchantStatus("릴릭을 다시 장착하세요...")
                    return
                }
                if (TryCompleteEnchantGoal(desired))
                    return
                ; 서버 첫 인챈트: Enchant 버튼 → Enter → [Enchant Fishing Rod]
                if (HandleKeepersAwaitIfOpen(desired))
                    return
                FocusRobloxWindow()
                if (Macro.enchantCachedX && Macro.enchantCachedY) {
                    ReliableScreenClick(Macro.enchantCachedX, Macro.enchantCachedY, 3, 5)
                } else {
                    if (!FindPlayerGui())
                        throw Error("PlayerGui를 찾지 못했습니다.")
                    btn := ResolveEnchantButtonWithTimeout(FindEnchantRodButton)
                    if (!btn)
                        throw Error("Enchant 버튼을 찾지 못했습니다. 인벤토리/TopButtons에 Enchant가 보이는지 확인하세요.")
                    ClickEnchantGuiButton(btn)
                }
                try Macro.enchantBaselineText := CollectRodEnchantHaystack()
                catch {
                }
                Macro.enchantSpamUntil := A_TickCount + ENCHANT_SPAM_MS
                Macro.enchantState := "GP_SPAM"
                SetEnchantStatus(IsSovereignChargeModeActive() ? FormatEnchantProgressStatus(desired) : "Enchant 연타 중...")
            } catch as err {
                if (!Macro.enchantCachedX) {
                    Macro.enchantLastError := err.Message
                    if (!Macro.enchantLastClickAt || A_TickCount - Macro.enchantLastClickAt >= 250) {
                        Macro.enchantLastClickAt := A_TickCount
                        SetEnchantStatus(err.Message " — 재시도...")
                        UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
                    }
                }
            }

        case "GP_SPAM":
            try {
                if (TryCompleteEnchantGoal(desired))
                    return
                ; After Enchant + Enter the Keepers prompt appears — click the rod button, never Cancel via Enter.
                if (HandleKeepersAwaitIfOpen(desired))
                    return
            } catch {
            }
            Send("{Enter}")
            try {
                if (TryCompleteEnchantGoal(desired))
                    return
                current := CollectRodEnchantHaystack()
                if (current != "" && Macro.enchantBaselineText != "" && current != Macro.enchantBaselineText) {
                    Macro.enchantBaselineText := current
                    if (TryCompleteEnchantGoal(desired))
                        return
                    if (!IsHoldingRelic()) {
                        Macro.enchantState := "GP_WAIT_RELIC"
                        SetEnchantStatus(IsSovereignChargeModeActive()
                            ? "충전 진행. 릴릭을 다시 장착하세요..."
                            : desired " 아님. 릴릭을 다시 장착하세요...")
                        return
                    }
                    Macro.enchantState := "GP_CLICK"
                    SetEnchantStatus(FormatEnchantProgressStatus(desired))
                    return
                }
            } catch {
            }

            if (A_TickCount >= Macro.enchantSpamUntil) {
                try {
                    if (TryCompleteEnchantGoal(desired))
                        return
                } catch {
                }
                if (!IsHoldingRelic()) {
                    Macro.enchantState := "GP_WAIT_RELIC"
                    SetEnchantStatus("릴릭을 다시 장착하세요...")
                    return
                }
                Macro.enchantState := "GP_CLICK"
                SetEnchantStatus(IsSovereignChargeModeActive()
                    ? FormatEnchantProgressStatus(desired)
                    : desired " 연타...")
            }
    }
}
