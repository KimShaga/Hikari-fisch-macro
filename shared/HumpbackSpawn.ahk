; ============================================================================
;  Hikari — Humpback Whale spawn helper (Clearcast / Smokescreen alternate)
; ============================================================================
#Requires AutoHotkey v2.0

SetHumpbackSpawnStatus(text) {
    global HumpbackStatusText, g_HostHumpbackStatus
    g_HostHumpbackStatus := text
    if (IsSet(HumpbackStatusText) && HumpbackStatusText) {
        try HumpbackStatusText.Text := text
        catch {
        }
    }
}

; 라이브 배너만 (sticky/풀 잔존 제외) — 재시작 시 즉시 완료되는 것 방지
IsHumpbackWhaleMigrationLiveBanner() {
    try {
        for key in FindHuntsInAnnouncements() {
            if (key = "Humpback Whale Migration")
                return true
        }
    } catch {
    }
    return false
}

IsHumpbackWhalePoolPresent() {
    try {
        fishing := GetFishingZonesFolder()
        if (fishing) {
            part := FindChildByNameCI(fishing, "Humpback Whale Pool")
            if (part)
                return true
        }
    } catch {
    }
    return false
}

; 들고 클릭 직후 다른 토템으로 바꿔도 사용이 취소되지 않음 → 교차 연타만 함
SpamUseHotbarItem(itemName) {
    slotKey := GetHotbarItemSlotKey(itemName)
    if (slotKey = "")
        return false
    if !SelectHotbarSlot(slotKey)
        return false
    Sleep(25)
    Click()
    Sleep(20)
    return true
}

ClearHumpbackSpawnRuntime() {
    global Macro
    Macro.humpbackSpawnState := "IDLE"
    Macro.humpbackSpawnNext := "Clearcast Totem"
    Macro.humpbackSpawnWaitUntil := 0
    Macro.humpbackSpawnUsedAt := 0
    Macro.humpbackSpawnAttempt := 0
    Macro.humpbackSpawnHadBanner := false
    Macro.humpbackSpawnHadPool := false
}

StartHumpbackSpawnCycle() {
    global Macro

    if !EnsureRobloxReady(true, true)
        return false

    if (!FindHotbarItemByName("Clearcast Totem") || !FindHotbarItemByName("Smokescreen Totem")) {
        MsgBox("핫바에 Clearcast Totem과 Smokescreen Totem을 모두 올려두세요.", "Humpback Whale Spawn")
        return false
    }

    FocusRobloxWindow()
    ClearHumpbackSpawnRuntime()
    Macro.phase := "HUMPBACK_SPAWN"
    Macro.cycleEnabled := true
    Macro.humpbackSpawnState := "SPAM"
    Macro.humpbackSpawnNext := "Clearcast Totem"
    Macro.humpbackSpawnWaitUntil := 0
    ; 이미 떠 있는 배너/풀은 무시하고, 새로 뜰 때만 완료
    Macro.humpbackSpawnHadBanner := IsHumpbackWhaleMigrationLiveBanner()
    Macro.humpbackSpawnHadPool := IsHumpbackWhalePoolPresent()
    status := "시작 — Clearcast ↔ Smokescreen 연타`n새 Humpback Whale Migration 대기"
    if (Macro.humpbackSpawnHadBanner || Macro.humpbackSpawnHadPool)
        status .= "`n(기존 소환은 무시 — 다음 소환까지 연타)"
    SetHumpbackSpawnStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    return true
}

StopHumpbackSpawnCycle(nextPhase := "OFF", status := "중지됨.") {
    global Macro
    ReleaseMouse(true)
    try EnsureRodEquipped()
    catch {
    }
    Macro.cycleEnabled := false
    Macro.phase := nextPhase
    ClearHumpbackSpawnRuntime()
    SetHumpbackSpawnStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    try StopMacroMouseTip(nextPhase = "FAILED" ? "혹등 스폰 실패" : "혹등 스폰 OFF")
    catch {
    }
}

CompleteHumpbackSpawnCycle(status := "완료.") {
    global Macro
    try EnsureRodEquipped()
    catch {
    }
    Macro.cycleEnabled := false
    Macro.phase := "DONE"
    ClearHumpbackSpawnRuntime()
    SetHumpbackSpawnStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    try StopMacroMouseTip("혹등 스폰 완료")
    catch {
    }
    try {
        SoundBeep(880, 120)
        SoundBeep(1175, 160)
    } catch {
    }
}

UpdateHumpbackSpawnPhase() {
    global Macro

    if (!Macro.cycleEnabled || Macro.phase != "HUMPBACK_SPAWN")
        return

    if (Macro.humpbackSpawnWaitUntil && A_TickCount < Macro.humpbackSpawnWaitUntil)
        return

    banner := IsHumpbackWhaleMigrationLiveBanner()
    pool := IsHumpbackWhalePoolPresent()

    ; 없어지면 다시 감지 가능하도록 무장
    if (!banner)
        Macro.humpbackSpawnHadBanner := false
    if (!pool)
        Macro.humpbackSpawnHadPool := false

    ; rising edge: 시작 시점엔 없다가 새로 생김
    newBanner := banner && !Macro.humpbackSpawnHadBanner
    newPool := pool && !Macro.humpbackSpawnHadPool
    if (newBanner || newPool) {
        Macro.humpbackSpawnHadBanner := banner
        Macro.humpbackSpawnHadPool := pool
        loc := ""
        try loc := ResolveHumpbackWhaleLocation()
        catch {
        }
        msg := "Humpback Whale Migration 감지!"
        if (loc != "")
            msg .= "`n위치: " loc
        CompleteHumpbackSpawnCycle(msg)
        return
    }

    if (banner)
        Macro.humpbackSpawnHadBanner := true
    if (pool)
        Macro.humpbackSpawnHadPool := true

    name := Macro.humpbackSpawnNext
    if (name = "")
        name := "Clearcast Totem"

    if (!FindHotbarItemByName(name)) {
        StopHumpbackSpawnCycle("FAILED", name " 을(를) 핫바에서 찾지 못했습니다.")
        return
    }

    FocusRobloxWindow()
    Macro.humpbackSpawnAttempt += 1
    SetHumpbackSpawnStatus(
        "연타 #" Macro.humpbackSpawnAttempt "`n"
        . name " 클릭 → 즉시 교차`n"
        . "목표: 새 Humpback Whale Migration"
    )

    SpamUseHotbarItem(name)

    if (name = "Clearcast Totem")
        Macro.humpbackSpawnNext := "Smokescreen Totem"
    else
        Macro.humpbackSpawnNext := "Clearcast Totem"

    Macro.humpbackSpawnState := "SPAM"
    Macro.humpbackSpawnWaitUntil := A_TickCount + 40
}
