; ============================================================================
;  Hikari — Treasure Appraise (EventAppraise / 보물섬 감정) helper
; ============================================================================
#Requires AutoHotkey v2.0

TREASURE_APPRAISE_COLS := 3
TREASURE_APPRAISE_ROWS := 7

ClearTreasureAppraiseRuntime() {
    global Macro
    Macro.treasureState := "IDLE"
    Macro.treasureRow := 0
    Macro.treasurePicks := []
    Macro.treasureResults := []
    Macro.treasureSlots := []
    Macro.treasureLastClickAt := 0
    Macro.treasureWaitUntil := 0
    Macro.treasureRound := 0
    Macro.treasureForceAppraise := false
    Macro.treasureClickRetry := 0
    Macro.treasureBusted := false
    Macro.treasureResetWaitStarted := 0
    Macro.treasurePostResetArmed := false
    ; 좌표 캐시는 라운드 중 유지 — Clear 시 비우지 않음(중지만 비움은 Stop에서)
    ClearTreasureRevealWait()
}

ClearTreasurePositionCache() {
    global Macro
    Macro.treasurePosCache := Map(
        "mids", [],
        "cells", [],
        "reappraise", 0,
        "appraise", 0,
        "takeNow", 0,
        "capturedAt", 0
    )
}

HasTreasurePositionCache() {
    global Macro
    cache := Macro.treasurePosCache
    if !(cache is Map)
        return false
    mids := cache.Has("mids") ? cache["mids"] : 0
    return (mids is Array) && mids.Length > 0
}

RememberTreasureScreenPos(addr) {
    if (!addr)
        return 0
    pos := GuiCenterToScreenSafe(addr)
    if IsObject(pos)
        return Map("x", pos.x + 0, "y", pos.y + 0)
    try {
        rect := ReadAbsoluteRect(addr)
        if (rect.w > 8 && rect.h > 8)
            return Map("x", Round(rect.x + rect.w / 2), "y", Round(rect.y + rect.h / 2))
    } catch {
    }
    return 0
}

; 시작 시 3×7 + Reappraise/Appraise/TakeNow 좌표를 전부 기억
CaptureTreasurePositionCache() {
    global Macro
    if (RefreshTreasureAppraiseGrid() < 1)
        return false

    grid := Macro.treasureSlots
    mids := []
    cells := []
    for rowIdx, row in grid {
        rowCells := []
        if !(row is Array)
            continue
        midCol := Min(row.Length, Max(1, Ceil(row.Length / 2)))
        for colIdx, slot in row {
            entry := Map("x", Round(slot["cx"]), "y", Round(slot["cy"]), "addr", slot["addr"])
            live := RememberTreasureScreenPos(slot["addr"])
            if (live is Map) {
                entry["x"] := live["x"]
                entry["y"] := live["y"]
            }
            rowCells.Push(entry)
            if (colIdx = midCol)
                mids.Push(Map("x", entry["x"], "y", entry["y"], "addr", entry["addr"], "row", rowIdx, "col", colIdx))
        }
        cells.Push(rowCells)
    }

    rePos := 0
    btn := FindTreasureReappraiseButtonStrict()
    if (btn)
        rePos := RememberTreasureScreenPos(btn)

    apPos := 0
    btn := FindTreasureAppraiseButton("Appraise")
    if (btn)
        apPos := RememberTreasureScreenPos(btn)

    ; Reappraise 전용 좌표가 없으면 Appraise를 재감정용으로도 기억
    ; (실제 클릭은 allowAppraiseFallback=true 일 때만)
    if !(rePos is Map) && (apPos is Map)
        rePos := apPos

    tnPos := 0
    btn := FindTreasureAppraiseButton("TakeNow")
    if (btn)
        tnPos := RememberTreasureScreenPos(btn)

    Macro.treasurePosCache := Map(
        "mids", mids,
        "cells", cells,
        "reappraise", rePos,
        "appraise", apPos,
        "takeNow", tnPos,
        "capturedAt", A_TickCount
    )
    return mids.Length > 0
}

GetTreasureCachedPoint(key) {
    global Macro
    cache := Macro.treasurePosCache
    if !(cache is Map) || !cache.Has(key)
        return 0
    p := cache[key]
    if !(p is Map) || !p.Has("x") || !p.Has("y")
        return 0
    return {x: Round(p["x"]), y: Round(p["y"])}
}

; 가운데 세로줄 rowIdx(1-based) 화면좌표: 라이브 우선, 실패 시 캐시
GetTreasureMidClickPos(rowIdx) {
    global Macro
    grid := Macro.treasureSlots
    if (grid is Array) && rowIdx >= 1 && rowIdx <= grid.Length {
        row := grid[rowIdx]
        if (row is Array) && row.Length {
            colIdx := Min(row.Length, Max(1, Ceil(row.Length / 2)))
            slot := row[colIdx]
            pos := GetTreasureSlotScreenPos(slot)
            if IsObject(pos)
                return pos
        }
    }

    cache := Macro.treasurePosCache
    if (cache is Map) && cache.Has("mids") {
        mids := cache["mids"]
        if (mids is Array) && rowIdx >= 1 && rowIdx <= mids.Length {
            p := mids[rowIdx]
            if (p is Map) && p.Has("x") && p.Has("y")
                return {x: Round(p["x"]), y: Round(p["y"])}
        }
    }
    return 0
}

ClickTreasureCachedPoint(pos, heavy := false) {
    if !IsObject(pos)
        return false
    FocusRobloxWindow()
    TreasureShakeClick(pos.x, pos.y, heavy)
    return true
}

; 캐시 → 라이브 찾기 순으로 버튼 클릭. 성공 시 캐시 갱신
; allowAppraiseFallback: reappraise 없을 때 Appraise 좌표 사용 (꽝/라운드 종료 시에만)
ClickTreasureButtonCached(kind, heavy := true, allowAppraiseFallback := false) {
    global Macro
    key := StrLower(kind)
    if (key = "reappraise" || key = "re")
        key := "reappraise"
    else if (key = "appraise")
        key := "appraise"
    else if (key = "takenow" || key = "take")
        key := "takeNow"
    else
        return false

    cached := GetTreasureCachedPoint(key)
    if (key = "reappraise" && !IsObject(cached) && allowAppraiseFallback)
        cached := GetTreasureCachedPoint("appraise")
    if IsObject(cached) {
        if ClickTreasureCachedPoint(cached, heavy)
            return true
    }

    btn := 0
    if (key = "reappraise") {
        btn := FindTreasureReappraiseButtonStrict()
        if (!btn && allowAppraiseFallback)
            btn := FindTreasureAppraiseButton("Appraise")
    } else if (key = "appraise") {
        btn := FindTreasureAppraiseButton("Appraise")
    } else {
        btn := FindTreasureAppraiseButton("TakeNow")
    }

    if (!btn)
        return false
    posMap := RememberTreasureScreenPos(btn)
    if !(posMap is Map)
        return false

    if !(Macro.treasurePosCache is Map)
        ClearTreasurePositionCache()
    storeKey := key
    if (key = "reappraise" && allowAppraiseFallback && !FindTreasureReappraiseButtonStrict())
        storeKey := "appraise"
    Macro.treasurePosCache[storeKey] := posMap
    if (key = "reappraise")
        Macro.treasurePosCache["reappraise"] := posMap

    return ClickTreasureCachedPoint({x: posMap["x"], y: posMap["y"]}, heavy)
}

GetTreasureSpamDelayMs() {
    return Max(0, GetTreasureAppraiseClickDelayMs())
}

GetTreasurePostReappraiseSettleMs() {
    return 40
}

ArmTreasurePostReappraiseSettle() {
    global Macro
    Macro.treasureWaitUntil := A_TickCount + GetTreasurePostReappraiseSettleMs()
    Macro.treasureLastClickAt := 0
    Macro.treasureClickRetry := 0
    ClearTreasureRevealWait()
    try FocusRobloxWindow()
    catch {
    }
}

GetTreasureFirstClickSettleMs() {
    return 40
}

ArmTreasureFirstClickSettle() {
    global Macro
    Macro.treasureWaitUntil := A_TickCount + GetTreasureFirstClickSettleMs()
    Macro.treasureLastClickAt := 0
    Macro.treasureClickRetry := 0
    try FocusRobloxWindow()
    catch {
    }
}

; 빠른 연타 — FastScreenClick과 동일하게 미세 이동 후 좌표 클릭
TreasureShakeClick(x, y, heavy := false) {
    TreasureSpamClick(x, y, heavy ? 4 : 3)
}

TreasureClickFirstSlot(x, y) {
    TreasureSpamClick(x, y, 4)
}

TreasureSpamClick(x, y, taps := 3) {
    previousMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    x := Round(x + 0)
    y := Round(y + 0)
    taps := Max(2, Round(taps + 0))
    try {
        Loop taps {
            ; Roblox는 단순 MouseMove+Click()만으로는 이동이 무시되는 경우가 많음
            MouseMove(x + 2, y, 0)
            MouseMove(x - 1, y + 1, 0)
            MouseMove(x, y, 0)
            Click(x, y)
            if (A_Index < taps)
                Sleep(12)
        }
    } finally {
        CoordMode("Mouse", previousMode)
    }
}

ClearTreasureRevealWait() {
    global Macro
    Macro.treasureRevealAddr := 0
    Macro.treasureRevealRow := 0
    Macro.treasureRevealCol := 0
    Macro.treasureRevealUntil := 0
    Macro.treasureRevealReclicks := 0
    Macro.treasureRevealExtended := false
    Macro.treasureRevealLoops := 0
}

; 매 클릭마다 라이브 AbsolutePosition → 화면좌표 (캐시 좌표 드리프트 방지)
GetTreasureSlotScreenPos(slot) {
    if !IsObject(slot)
        return 0
    if (slot.Has("addr") && slot["addr"]) {
        pos := GuiCenterToScreenSafe(slot["addr"])
        if IsObject(pos)
            return pos
        ; Safe가 거절해도 변환은 시도 (클라이언트 오프셋 포함)
        pos := GuiCenterToScreen(slot["addr"])
        if IsObject(pos)
            return pos
    }
    if (slot.Has("cx") && slot.Has("cy")) {
        left := 0, top := 0, clientW := 0, clientH := 0
        if GetRobloxClientScreenRect(&left, &top, &clientW, &clientH)
            return {x: Round(left + slot["cx"]), y: Round(top + slot["cy"])}
        return {x: Round(slot["cx"]), y: Round(slot["cy"])}
    }
    return 0
}

IsTreasureSlotUnopened(mult) {
    t := Trim(mult)
    return (t = "" || InStr(t, "?"))
}

; 클릭 후 짧게만 폴링 — 안 열리면 호출측에서 바로 연타
WaitTreasureSlotReveal(rowIdx, addr := 0, timeoutMs := 180) {
    global Macro
    deadline := A_TickCount + timeoutMs
    last := "?"
    lastRefresh := 0
    while (A_TickCount < deadline) {
        if (IsTreasureBustNow(""))
            return "x0.5"
        if (!lastRefresh || (A_TickCount - lastRefresh) >= 60) {
            RefreshTreasureAppraiseGrid()
            lastRefresh := A_TickCount
            bust := ScanTreasureMiddleBustSlot()
            if (bust != "")
                return bust
            grid := Macro.treasureSlots
            if ((grid is Array) && rowIdx >= 1 && rowIdx <= grid.Length) {
                row := grid[rowIdx]
                if ((row is Array) && row.Length) {
                    colIdx := Min(row.Length, Max(1, Ceil(row.Length / 2)))
                    slot := row[colIdx]
                    if IsObject(slot)
                        addr := slot["addr"]
                }
            }
        }
        last := addr ? ReadTreasureSlotMultiplier(addr) : ""
        if (last = "")
            last := "?"
        if (IsTreasureBustMultiplier(last))
            return last
        if (!IsTreasureSlotUnopened(last))
            return last
        Sleep(12)
    }
    RefreshTreasureAppraiseGrid()
    bust := ScanTreasureMiddleBustSlot()
    if (bust != "")
        return bust
    if (IsTreasureBustNow(""))
        return "x0.5"
    if (addr)
        last := ReadTreasureSlotMultiplier(addr)
    if (last = "")
        last := "?"
    return last
}

; 가운데 세로줄에 x0.5가 하나라도 있으면 꽝 (항상 최신 그리드)
ScanTreasureMiddleBustSlot() {
    global Macro
    if (RefreshTreasureAppraiseGrid() < 1)
        return ""
    grid := Macro.treasureSlots
    if !(grid is Array)
        return ""
    for row in grid {
        if !(row is Array) || !row.Length
            continue
        colIdx := Min(row.Length, Max(1, Ceil(row.Length / 2)))
        slot := row[colIdx]
        if !IsObject(slot)
            continue
        m := ReadTreasureSlotMultiplier(slot["addr"])
        if (m != "" && IsTreasureBustMultiplier(m))
            return m
    }
    return ""
}

IsTreasureRoundFailedNow() {
    if (IsTreasureBustNow(""))
        return true
    return ScanTreasureMiddleBustSlot() != ""
}

; 가운데 세로줄이 전부 ? 이고 헤더가 꽝이 아니면 새 라운드 준비 완료
AreTreasureSlotsResetForNewRound() {
    if (RefreshTreasureAppraiseGrid() < 1)
        return false
    if (IsTreasureBustNow())
        return false
    global Macro
    grid := Macro.treasureSlots
    if !(grid is Array) || !grid.Length
        return false
    for row in grid {
        if !(row is Array) || !row.Length
            continue
        colIdx := Min(row.Length, Max(1, Ceil(row.Length / 2)))
        slot := row[colIdx]
        if !IsObject(slot)
            continue
        m := ReadTreasureSlotMultiplier(slot["addr"])
        if !IsTreasureSlotUnopened(m)
            return false
    }
    return true
}

AcceptTreasureSlotResult(rowIdx, colIdx, mult, gridLength) {
    global Macro
    ClearTreasureRevealWait()
    Macro.treasureClickRetry := 0

    ; 미개봉(?)을 성공으로 넘기면 4행+ 꽝을 건너뜀 — 같은 행 유지
    if (IsTreasureSlotUnopened(mult)) {
        if (IsTreasureRoundFailedNow()) {
            mult := "x0.5"
        } else {
            Macro.treasureRow := rowIdx
            Macro.treasureWaitUntil := A_TickCount + 40
            SetTreasureAppraiseStatus(
                "R" Macro.treasureRound " 행 " rowIdx " 개봉 미확인 — 연타 재시도..."
            )
            return
        }
    }

    ; 꽝이면 절대 다음 행으로 가지 않음
    if (IsTreasureBustMultiplier(mult) || IsTreasureRoundFailedNow()) {
        if (IsTreasureSlotUnopened(mult))
            mult := "x0.5"
        Macro.treasurePicks.Push(Map("row", rowIdx, "col", colIdx, "mult", mult))
        Macro.treasureResults.Push(mult)
        HandleTreasureBustFail(rowIdx, colIdx, mult)
        return
    }

    Macro.treasurePicks.Push(Map("row", rowIdx, "col", colIdx, "mult", mult))
    Macro.treasureResults.Push(mult)

    SetTreasureAppraiseStatus(
        "R" Macro.treasureRound " 행 " rowIdx "/" gridLength
        " → 칸 " colIdx " (" mult ")`n"
        . FormatTreasureGoalStatusLine() "`n"
        . FormatTreasureResultsSummary()
    )
    Macro.treasureRow := rowIdx + 1
}

; ReliableScreenClick과 같은 십자 흔들기 (클릭 없이 포커스만)
TreasureWiggleOnly(x, y, wigglePixels := 5, stepDelayMs := 12) {
    previousMode := A_CoordModeMouse
    CoordMode("Mouse", "Screen")
    x := Round(x + 0)
    y := Round(y + 0)
    wigglePixels := Max(1, Round(wigglePixels + 0))
    stepDelayMs := Max(0, Round(stepDelayMs + 0))
    try {
        MouseMove(x, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x + wigglePixels, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x - wigglePixels, y, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y + wigglePixels, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y - wigglePixels, 0)
        Sleep(stepDelayMs)
        MouseMove(x, y, 0)
    } finally {
        CoordMode("Mouse", previousMode)
    }
}

WakeTreasureMouseToFirstSlot() {
    global Macro
    FocusRobloxWindow()
    pos := GetTreasureMidClickPos(1)
    if !IsObject(pos)
        return
    TreasureWiggleOnly(pos.x, pos.y, 5, 12)
}

IsTreasureAppraiseEnabled() {
    global MAIN
    return MAIN.Has("treasure_appraise_enabled") && MAIN["treasure_appraise_enabled"] ? true : false
}

GetTreasureAppraiseClickDelayMs() {
    global MAIN
    if !(MAIN.Has("treasure_appraise_click_delay_ms"))
        return 0
    return Max(0, MAIN["treasure_appraise_click_delay_ms"] + 0)
}

IsTreasureAppraiseAutoTakeEnabled() {
    global MAIN
    return MAIN.Has("treasure_appraise_auto_take") && MAIN["treasure_appraise_auto_take"] ? true : false
}

IsTreasureGoalMultEnabled() {
    global MAIN
    return MAIN.Has("treasure_goal_mult_enabled") && MAIN["treasure_goal_mult_enabled"] ? true : false
}

GetTreasureGoalMult() {
    global MAIN
    if !(MAIN.Has("treasure_goal_mult"))
        return 1.1
    return Max(0.01, MAIN["treasure_goal_mult"] + 0.0)
}

IsTreasureGoalTotalKgEnabled() {
    global MAIN
    return MAIN.Has("treasure_goal_total_kg_enabled") && MAIN["treasure_goal_total_kg_enabled"] ? true : false
}

GetTreasureGoalTotalKg() {
    global MAIN
    if !(MAIN.Has("treasure_goal_total_kg"))
        return 500.0
    return Max(0.0, MAIN["treasure_goal_total_kg"] + 0.0)
}

IsTreasureGoalBigGiantEnabled() {
    global MAIN
    return MAIN.Has("treasure_goal_big_giant_enabled") && MAIN["treasure_goal_big_giant_enabled"] ? true : false
}

HasAnyTreasureGoalEnabled() {
    return IsTreasureGoalMultEnabled() || IsTreasureGoalTotalKgEnabled() || IsTreasureGoalBigGiantEnabled()
}

SetTreasureAppraiseStatus(text) {
    global TreasureStatusText, AppraiseStatusText
    if IsSet(TreasureStatusText) && TreasureStatusText
        TreasureStatusText.Value := "상태: " text
    else if IsSet(AppraiseStatusText) && AppraiseStatusText
        AppraiseStatusText.Value := "상태: " text
}

FindEventAppraiseRoot() {
    playerGui := FindPlayerGui()
    if (!playerGui)
        return 0
    root := FindChildByNameCI(playerGui, "EventAppraise")
    if (root)
        return root
    return FindGuiDescendantByName(playerGui, "EventAppraise", 40000)
}

FindTreasureAppraiseFrame(root := 0) {
    if (!root)
        root := FindEventAppraiseRoot()
    if (!root)
        return 0
    frame := FindChildByNameCI(root, "EventAppraise")
    return frame ? frame : root
}

FindTreasureAppraiseList(root := 0) {
    frame := FindTreasureAppraiseFrame(root)
    if (!frame)
        return 0
    list := FindChildByNameCI(frame, "List")
    if (list)
        return list
    return FindGuiDescendantByName(frame, "List", 20000)
}

FindTreasureAppraiseButton(name) {
    frame := FindTreasureAppraiseFrame()
    if (!frame)
        return 0
    btn := FindChildByNameCI(frame, name)
    if (btn)
        return btn
    return FindGuiDescendantByName(frame, name, 20000)
}

IsTreasureButtonReady(btn) {
    if (!btn)
        return false
    try {
        if !ReadGuiObjectVisible(btn)
            return false
    } catch {
    }
    rect := ReadAbsoluteRect(btn)
    if (rect.w < 12 || rect.h < 12)
        return false
    pos := GuiCenterToScreenSafe(btn)
    return IsObject(pos) ? true : false
}

; Reappraise 이름만 (Appraise 폴백 없음 — 매 틱 오클릭 방지)
FindTreasureReappraiseButtonStrict() {
    frame := FindTreasureAppraiseFrame()
    if (!frame)
        return 0
    for name in ["Reappraise", "ReAppraise", "reappraise", "Re-Appraise"] {
        btn := FindChildByNameCI(frame, name)
        if (btn && IsTreasureButtonReady(btn))
            return btn
        btn := FindGuiDescendantByName(frame, name, 25000)
        if (btn && IsTreasureButtonReady(btn))
            return btn
    }
    return 0
}

; Reappraise가 나타나 Visible 되면 반환 (이름 우선, Appraise 텍스트 보조)
FindTreasureReappraiseButton() {
    btn := FindTreasureReappraiseButtonStrict()
    if (btn)
        return btn

    frame := FindTreasureAppraiseFrame()
    if (!frame)
        return 0

    ; 버튼 Name은 Appraise인데 표시가 Reappraise인 경우
    btn := FindTreasureAppraiseButton("Appraise")
    if (btn && IsTreasureButtonReady(btn)) {
        try {
            t := StrLower(Trim(ReadGuiText(btn)))
            if (InStr(t, "reappraise") || InStr(t, "re-appraise") || InStr(t, "다시"))
                return btn
        } catch {
        }
    }
    return 0
}

ClickTreasureButtonAddr(btn, heavy := true) {
    if (!btn)
        return false
    pos := GuiCenterToScreenSafe(btn)
    if !IsObject(pos)
        return false
    FocusRobloxWindow()
    TreasureShakeClick(pos.x, pos.y, heavy)
    return true
}

; 의도된 재감정일 때만 호출. allowAppraiseFallback=false 면 절대 캐시로 Appraise를 누르지 않음
TryTreasureReappraiseAndReset(allowAppraiseFallback := false) {
    global Macro

    ; 슬롯 선택 중(false)에는 재감정 클릭 금지 — 매 틱 루프 방지
    if (!allowAppraiseFallback)
        return false

    clicked := false
    if (ClickTreasureButtonCached("reappraise", true, true))
        clicked := true
    else if (ClickTreasureButtonCached("appraise", true, false))
        clicked := true

    if (!clicked) {
        btn := FindTreasureReappraiseButtonStrict()
        if (!btn)
            btn := FindTreasureAppraiseButton("Appraise")
        if (btn && IsTreasureButtonReady(btn) && ClickTreasureButtonAddr(btn)) {
            clicked := true
            posMap := RememberTreasureScreenPos(btn)
            if (posMap is Map) {
                if !(Macro.treasurePosCache is Map)
                    ClearTreasurePositionCache()
                Macro.treasurePosCache["reappraise"] := posMap
                Macro.treasurePosCache["appraise"] := posMap
            }
        }
    }

    if (!clicked)
        return false

    Macro.treasureForceAppraise := false
    Macro.treasureClickRetry := 0
    Macro.treasureBusted := false
    ClearTreasureRevealWait()
    Macro.treasurePicks := []
    Macro.treasureResults := []
    Macro.treasureRow := 1
    Macro.treasureState := "WAIT_REFRESH"
    Macro.treasureWaitUntil := A_TickCount + 80
    Macro.treasureResetWaitStarted := A_TickCount
    Macro.treasurePostResetArmed := false
    SetTreasureAppraiseStatus("Reappraise 클릭 — 바로 연타 재개...")
    return true
}

; Header 안 Weight = "1x kg" / "1.15x kg"
FindTreasureHeaderWeightLabel() {
    frame := FindTreasureAppraiseFrame()
    if (!frame)
        return 0
    header := FindChildByNameCI(frame, "Header")
    if (header) {
        w := FindChildByNameCI(header, "Weight")
        if (w)
            return w
    }
    return 0
}

; 하단 Total: "Total: 312.90 kg"
FindTreasureTotalWeightLabel() {
    frame := FindTreasureAppraiseFrame()
    if (!frame)
        return 0
    try {
        for childAddr in ReadChildren(frame) {
            try {
                if (ReadClassName(childAddr) != "TextLabel")
                    continue
                if (StrLower(ReadInstanceName(childAddr)) != "weight")
                    continue
                text := Trim(ReadGuiText(childAddr))
                if InStr(StrLower(text), "total")
                    return childAddr
            } catch {
            }
        }
    } catch {
    }
    return 0
}

ReadTreasureSlotMultiplier(slotAddr) {
    if (!slotAddr)
        return ""
    label := FindChildByNameCI(slotAddr, "Multiplier")
    if (!label)
        label := FindGuiDescendantByName(slotAddr, "Multiplier", 4000)
    if (!label)
        return ""
    try return Trim(RegExReplace(ReadGuiText(label), "[\r\n\t]+", " "))
    catch {
        return ""
    }
}

ReadTreasureHeaderMultiplier() {
    label := FindTreasureHeaderWeightLabel()
    if (!label)
        return 0.0
    try text := Trim(ReadGuiText(label))
    catch {
        return 0.0
    }
    ; "1x kg", "1.15x kg", "x1.2"
    if RegExMatch(text, "i)([0-9]*\.?[0-9]+)\s*x", &m)
        return m[1] + 0.0
    if RegExMatch(text, "i)x\s*([0-9]*\.?[0-9]+)", &m)
        return m[1] + 0.0
    return 0.0
}

ReadTreasureTotalKg() {
    label := FindTreasureTotalWeightLabel()
    if (!label)
        return 0.0
    try text := Trim(ReadGuiText(label))
    catch {
        return 0.0
    }
    ; Total: 312.90 kg | Total: 1.16T (희귀)
    if RegExMatch(text, "i)([0-9]*\.?[0-9]+)\s*([kKmMtTbB]?)", &m) {
        val := m[1] + 0.0
        suf := StrLower(m[2])
        if (suf = "k")
            val *= 1000.0
        else if (suf = "m")
            val *= 1000000.0
        else if (suf = "b")
            val *= 1000000000.0
        else if (suf = "t")
            val *= 1000000000000.0
        return val
    }
    return 0.0
}

IsTreasureFishBigOrGiant() {
    name := GetEquippedToolName()
    if (name = "")
        return false
    ; 단어 경계에 가깝게: Big / Giant 수식어
    if RegExMatch(name, "i)(^|[^A-Za-z])Big([^A-Za-z]|$)")
        return true
    if RegExMatch(name, "i)(^|[^A-Za-z])Giant([^A-Za-z]|$)")
        return true
    return false
}

; 꽝: 슬롯 "x0.5" / 헤더 "0.50x kg" (형식 다양)
IsTreasureBustMultiplier(text) {
    t := StrLower(Trim(text))
    if (t = "")
        return false
    t := StrReplace(t, "×", "x")
    t := StrReplace(t, ",", ".")
    ; x0.5 / x0.50 — 숫자 값이 0.5 이하만
    if RegExMatch(t, "i)x\s*(0\.\d+)", &m) {
        if ((m[1] + 0.0) > 0 && (m[1] + 0.0) <= 0.50001)
            return true
    }
    ; 0.5x / 0.50x kg (10.50x 오탐 방지)
    if RegExMatch(t, "i)(?<![0-9.])(0\.\d+)\s*x", &m) {
        if ((m[1] + 0.0) > 0 && (m[1] + 0.0) <= 0.50001)
            return true
    }
    if RegExMatch(t, "i)^0\.5\d*$")
        return true
    return false
}

IsTreasureBustNow(slotMult := "") {
    if (slotMult != "" && IsTreasureBustMultiplier(slotMult))
        return true
    header := ""
    try {
        label := FindTreasureHeaderWeightLabel()
        if (label)
            header := Trim(ReadGuiText(label))
    } catch {
    }
    if (header != "" && IsTreasureBustMultiplier(header))
        return true
    ; 헤더 배수가 0.5 이하면 꽝 (누적 성공 후 실패 시)
    mult := ReadTreasureHeaderMultiplier()
    if (mult > 0 && mult <= 0.50001)
        return true
    return false
}

; 최신 그리드에서 가운데 칸 슬롯 맵 반환
GetTreasureMidSlot(rowIdx) {
    global Macro
    if (RefreshTreasureAppraiseGrid() < 1)
        return 0
    grid := Macro.treasureSlots
    if !(grid is Array) || rowIdx < 1 || rowIdx > grid.Length
        return 0
    row := grid[rowIdx]
    if !(row is Array) || !row.Length
        return 0
    colIdx := Min(row.Length, Max(1, Ceil(row.Length / 2)))
    slot := row[colIdx]
    return IsObject(slot) ? slot : 0
}

ReadTreasureMidMultiplier(rowIdx) {
    slot := GetTreasureMidSlot(rowIdx)
    if !IsObject(slot)
        return ""
    return ReadTreasureSlotMultiplier(slot["addr"])
}

HandleTreasureBustFail(rowIdx, colIdx, mult) {
    global Macro
    Macro.treasureBusted := true
    Macro.treasureClickRetry := 0
    Macro.treasureWaitUntil := 0
    Macro.treasureLastClickAt := 0
    ClearTreasureRevealWait()

    if (!HasAnyTreasureGoalEnabled()) {
        CompleteTreasureAppraiseCycle("꽝(x0.5) — 실패.")
        return
    }

    ; 목표 반복: 슬롯 클릭 완전 중단 → Reappraise만
    Macro.treasureForceAppraise := true
    Macro.treasureState := "WAIT_REAPPRAISE"
    SetTreasureAppraiseStatus(
        "꽝! (" mult ") — 슬롯 선택 잠금`n"
        . "행 " rowIdx " 칸 " colIdx "`n"
        . "Reappraise 클릭..."
    )
    if (TryTreasureReappraiseAndReset(true))
        return
    Macro.treasureWaitUntil := A_TickCount + 120
}

FormatTreasureGoalStatusLine() {
    parts := []
    mult := ReadTreasureHeaderMultiplier()
    total := ReadTreasureTotalKg()
    if (IsTreasureGoalMultEnabled())
        parts.Push(Format("배수 {1:.2f}/{2:.2f}", mult, GetTreasureGoalMult()))
    if (IsTreasureGoalTotalKgEnabled())
        parts.Push(Format("Total {1:.1f}/{2:.1f}kg", total, GetTreasureGoalTotalKg()))
    if (IsTreasureGoalBigGiantEnabled())
        parts.Push(IsTreasureFishBigOrGiant() ? "Big/Giant ✓" : "Big/Giant …")
    if (!parts.Length)
        return ""
    out := ""
    for p in parts {
        if (out != "")
            out .= " | "
        out .= p
    }
    return out
}

; 켜진 목표 중 하나라도 충족하면 true. 목표가 하나도 없으면 false(한 라운드만).
AreTreasureGoalsMet() {
    if !HasAnyTreasureGoalEnabled()
        return false

    if (IsTreasureGoalMultEnabled() && ReadTreasureHeaderMultiplier() + 0.0 >= GetTreasureGoalMult())
        return true
    if (IsTreasureGoalTotalKgEnabled() && ReadTreasureTotalKg() + 0.0 >= GetTreasureGoalTotalKg())
        return true
    if (IsTreasureGoalBigGiantEnabled() && IsTreasureFishBigOrGiant())
        return true
    return false
}

CollectTreasureAppraiseSlots() {
    list := FindTreasureAppraiseList()
    if (!list)
        return []

    slots := []
    try {
        for childAddr in ReadChildren(list) {
            try {
                if (ReadClassName(childAddr) != "ImageButton")
                    continue
                ; List 자식은 Template 만 (다른 ImageButton 혼입 방지)
                nm := StrLower(Trim(ReadInstanceName(childAddr)))
                if (nm != "" && nm != "template")
                    continue
                rect := ReadAbsoluteRect(childAddr)
                if !IsObject(rect)
                    continue
                if (rect.w < 24 || rect.h < 24)
                    continue
                slots.Push(Map(
                    "addr", childAddr,
                    "x", rect.x + 0.0,
                    "y", rect.y + 0.0,
                    "w", rect.w + 0.0,
                    "h", rect.h + 0.0,
                    "cx", rect.x + rect.w / 2.0,
                    "cy", rect.y + rect.h / 2.0,
                    "mult", ReadTreasureSlotMultiplier(childAddr)
                ))
            } catch {
            }
        }
    } catch {
    }

    n := slots.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            a := slots[j]
            b := slots[j + 1]
            if (a["cy"] > b["cy"] + 8 || (Abs(a["cy"] - b["cy"]) <= 8 && a["cx"] > b["cx"])) {
                slots[j] := b
                slots[j + 1] := a
            }
        }
    }
    return slots
}

BuildTreasureAppraiseGrid(slots) {
    global TREASURE_APPRAISE_COLS, TREASURE_APPRAISE_ROWS

    rows := []
    if !(slots is Array) || !slots.Length
        return rows

    ; Y→X 정렬 후 고정 3열 청크 (cy 임계값 묶음은 하단 행이 합쳐져 꽝 오판 남)
    sorted := []
    for slot in slots
        sorted.Push(slot)
    n := sorted.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            a := sorted[j]
            b := sorted[j + 1]
            if (a["cy"] > b["cy"] + 6 || (Abs(a["cy"] - b["cy"]) <= 6 && a["cx"] > b["cx"])) {
                sorted[j] := b
                sorted[j + 1] := a
            }
        }
    }

    maxSlots := TREASURE_APPRAISE_COLS * TREASURE_APPRAISE_ROWS
    if (sorted.Length > maxSlots) {
        trimmed := []
        Loop maxSlots
            trimmed.Push(sorted[A_Index])
        sorted := trimmed
    }

    i := 1
    while (i <= sorted.Length && rows.Length < TREASURE_APPRAISE_ROWS) {
        row := []
        Loop TREASURE_APPRAISE_COLS {
            if (i > sorted.Length)
                break
            row.Push(sorted[i])
            i += 1
        }
        if (row.Length) {
            SortTreasureRowByX(row)
            rows.Push(row)
        }
    }
    return rows
}

SortTreasureRowByX(row) {
    n := row.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (row[j]["cx"] > row[j + 1]["cx"]) {
                tmp := row[j]
                row[j] := row[j + 1]
                row[j + 1] := tmp
            }
        }
    }
}

RefreshTreasureAppraiseGrid() {
    global Macro
    slots := CollectTreasureAppraiseSlots()
    grid := BuildTreasureAppraiseGrid(slots)
    Macro.treasureSlots := grid
    return grid.Length
}

StartTreasureAppraiseCycle() {
    global Macro

    root := FindEventAppraiseRoot()
    if (!root) {
        MsgBox("Treasure Appraise 창(EventAppraise)을 연 뒤 시작하세요.", "보물섬 감정")
        return false
    }

    if (RefreshTreasureAppraiseGrid() < 1) {
        MsgBox("보물섬 감정 슬롯(3×7)을 찾지 못했습니다. 창이 열려 있는지 확인하세요.", "보물섬 감정")
        return false
    }

    ReleaseMouse(true)
    ClearTreasureAppraiseRuntime()
    RefreshTreasureAppraiseGrid()
    if !CaptureTreasurePositionCache() {
        MsgBox("슬롯 좌표를 기억하지 못했습니다. 창을 연 뒤 다시 시도하세요.", "보물섬 감정")
        return false
    }

    Macro.phase := "TREASURE_APPRAISE"
    Macro.treasureState := "CLICK_ROWS"
    Macro.treasureRow := 1
    Macro.treasureRound := 1
    Macro.cycleEnabled := true
    ArmTreasureFirstClickSettle()
    FocusRobloxWindow()
    midN := Macro.treasurePosCache["mids"].Length
    goalLine := FormatTreasureGoalStatusLine()
    SetTreasureAppraiseStatus(
        "보물섬 감정 시작 — " Macro.treasureSlots.Length "행 / 캐시 " midN "칸`n"
        . "연타 모드 (간격 " GetTreasureSpamDelayMs() "ms)`n"
        . (goalLine != "" ? goalLine : "목표 없음(1라운드)")
    )
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
    return true
}

StopTreasureAppraiseCycle(nextPhase := "OFF", status := "중지됨.") {
    global Macro
    ReleaseMouse(true)
    Macro.cycleEnabled := false
    Macro.phase := nextPhase
    Macro.treasureState := nextPhase = "OFF" ? "IDLE" : nextPhase
    ClearTreasurePositionCache()
    SetTreasureAppraiseStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

CompleteTreasureAppraiseCycle(status := "완료.") {
    global Macro
    Macro.cycleEnabled := false
    Macro.phase := "DONE"
    Macro.treasureState := "DONE"
    SetTreasureAppraiseStatus(status)
    UpdateMacroStatus(GetMacroDisplayStatus(), "---", "---")
}

ClickTreasureNamedButton(name, heavy := true) {
    btn := FindTreasureAppraiseButton(name)
    if (!btn)
        return false
    pos := GuiCenterToScreenSafe(btn)
    if !IsObject(pos)
        return false
    FocusRobloxWindow()
    TreasureShakeClick(pos.x, pos.y, heavy)
    return true
}

UpdateTreasureAppraisePhase() {
    global Macro

    ; 재감정은 WAIT_REAPPRAISE / Force 일 때만 (CLICK_ROWS에서 매 틱 누르면 루프 남)
    if (Macro.treasureState = "WAIT_REAPPRAISE" || Macro.treasureForceAppraise) {
        if (TryTreasureReappraiseAndReset(true))
            return
    }

    switch Macro.treasureState {
        case "CLICK_ROWS":
            if (Macro.treasureWaitUntil && A_TickCount < Macro.treasureWaitUntil)
                return

            ; 꽝/실패면 아래칸 진행 금지 → 재감정만
            if (Macro.treasureBusted) {
                ClearTreasureRevealWait()
                HandleTreasureBustFail(Macro.treasureRow + 0, 0, "locked")
                return
            }
            ; 이번 라운드에서 클릭을 한 번이라도 했으면 헤더/슬롯 꽝 즉시 감지
            roundActive := ((Macro.treasurePicks is Array) && Macro.treasurePicks.Length > 0)
                || Macro.treasureRevealAddr
                || (Macro.treasureRow > 1)
            if (roundActive && IsTreasureRoundFailedNow()) {
                ClearTreasureRevealWait()
                bustMult := ScanTreasureMiddleBustSlot()
                if (bustMult = "")
                    bustMult := "x0.5"
                HandleTreasureBustFail(Macro.treasureRow + 0, 0, bustMult)
                return
            }

            grid := Macro.treasureSlots
            if !(grid is Array) || !grid.Length {
                RefreshTreasureAppraiseGrid()
                grid := Macro.treasureSlots
            }
            rowCount := (grid is Array) ? grid.Length : 0
            if (rowCount < 1 && HasTreasurePositionCache())
                rowCount := Macro.treasurePosCache["mids"].Length
            if (rowCount < 1) {
                StopTreasureAppraiseCycle("FAILED", "슬롯 그리드가 비었습니다.")
                return
            }

            ; 클릭은 됐는데 텍스트만 늦은 경우: 대기하지 말고 같은 칸 연타
            if (Macro.treasureRevealAddr) {
                addr := Macro.treasureRevealAddr
                rowIdx := Macro.treasureRevealRow + 0
                colIdx := Macro.treasureRevealCol + 0

                if (IsTreasureRoundFailedNow()) {
                    bustMult := ScanTreasureMiddleBustSlot()
                    if (bustMult = "")
                        bustMult := "x0.5"
                    AcceptTreasureSlotResult(rowIdx, colIdx, bustMult, rowCount)
                    return
                }

                fresh := GetTreasureMidSlot(rowIdx)
                if IsObject(fresh) {
                    addr := fresh["addr"]
                    Macro.treasureRevealAddr := addr
                }
                mult := addr ? ReadTreasureSlotMultiplier(addr) : "?"
                if (mult = "")
                    mult := "?"

                if (IsTreasureBustMultiplier(mult) || !IsTreasureSlotUnopened(mult)) {
                    AcceptTreasureSlotResult(rowIdx, colIdx, mult, rowCount)
                    return
                }

                Macro.treasureRevealLoops := (Macro.treasureRevealLoops + 0) + 1
                if (Macro.treasureRevealLoops > 40) {
                    midNow := ReadTreasureMidMultiplier(rowIdx)
                    if (IsTreasureBustMultiplier(midNow) || IsTreasureRoundFailedNow())
                        AcceptTreasureSlotResult(rowIdx, colIdx, midNow != "" ? midNow : "x0.5", rowCount)
                    else if (!IsTreasureSlotUnopened(midNow))
                        AcceptTreasureSlotResult(rowIdx, colIdx, midNow, rowCount)
                    else if (FindTreasureReappraiseButtonStrict())
                        AcceptTreasureSlotResult(rowIdx, colIdx, "x0.5", rowCount)
                    else {
                        ClearTreasureRevealWait()
                        Macro.treasureRow := rowIdx
                        Macro.treasureWaitUntil := A_TickCount + 40
                    }
                    return
                }

                if (Macro.treasureLastClickAt && (A_TickCount - Macro.treasureLastClickAt) < GetTreasureSpamDelayMs())
                    return

                pos := GetTreasureMidClickPos(rowIdx)
                if IsObject(pos) {
                    FocusRobloxWindow()
                    TreasureSpamClick(pos.x, pos.y, 3)
                    Macro.treasureLastClickAt := A_TickCount
                    Macro.treasureRevealReclicks += 1
                    Macro.treasureRevealUntil := A_TickCount + 120
                    SetTreasureAppraiseStatus("R" Macro.treasureRound " 행 " rowIdx " 개봉 연타...")
                }
                return
            }

            ; 클릭 중에도 목표 조기 달성 가능
            if (HasAnyTreasureGoalEnabled() && AreTreasureGoalsMet()) {
                Macro.treasureState := "FINISH"
                Macro.treasureWaitUntil := A_TickCount + 50
                SetTreasureAppraiseStatus("목표 달성!`n" FormatTreasureGoalStatusLine())
                return
            }

            rowIdx := Macro.treasureRow + 0
            if (rowIdx < 1 || rowIdx > rowCount) {
                Macro.treasureState := "AFTER_ROUND"
                Macro.treasureWaitUntil := A_TickCount + 50
                SetTreasureAppraiseStatus("라운드 " Macro.treasureRound " 선택 완료`n" FormatTreasureGoalStatusLine())
                return
            }

            if (Macro.treasureLastClickAt && (A_TickCount - Macro.treasureLastClickAt) < GetTreasureSpamDelayMs())
                return

            colIdx := 2
            RefreshTreasureAppraiseGrid()
            grid := Macro.treasureSlots
            if ((grid is Array) && grid.Length)
                rowCount := grid.Length
            slot := GetTreasureMidSlot(rowIdx)
            if IsObject(slot) && ((grid is Array) && rowIdx <= grid.Length && (grid[rowIdx] is Array) && grid[rowIdx].Length)
                colIdx := Min(grid[rowIdx].Length, Max(1, Ceil(grid[rowIdx].Length / 2)))

            ; 이미 개봉된 칸이면 재클릭하지 말고 결과만 반영
            if IsObject(slot) {
                existing := ReadTreasureSlotMultiplier(slot["addr"])
                if (!IsTreasureSlotUnopened(existing)) {
                    AcceptTreasureSlotResult(rowIdx, colIdx, existing, rowCount)
                    return
                }
            }

            pos := GetTreasureMidClickPos(rowIdx)
            if !IsObject(pos) {
                Macro.treasureClickRetry += 1
                if (Macro.treasureClickRetry > 3) {
                    StopTreasureAppraiseCycle("FAILED", "슬롯 좌표를 읽지 못했습니다.")
                    return
                }
                Macro.treasureWaitUntil := A_TickCount + 40
                return
            }

            FocusRobloxWindow()
            TreasureSpamClick(pos.x, pos.y, (rowIdx = 1) ? 4 : 3)
            Macro.treasureLastClickAt := A_TickCount

            addr := IsObject(slot) ? slot["addr"] : 0
            mult := WaitTreasureSlotReveal(rowIdx, addr, 160)
            if (mult = "")
                mult := "?"

            if (!IsTreasureSlotUnopened(mult) || IsTreasureBustMultiplier(mult) || IsTreasureRoundFailedNow()) {
                if (IsTreasureSlotUnopened(mult) && IsTreasureRoundFailedNow())
                    mult := "x0.5"
                AcceptTreasureSlotResult(rowIdx, colIdx, mult, rowCount)
                return
            }

            ; 미개봉이면 바로 연타 모드로
            Macro.treasureRevealAddr := addr
            Macro.treasureRevealRow := rowIdx
            Macro.treasureRevealCol := colIdx
            Macro.treasureRevealUntil := A_TickCount + 80
            Macro.treasureRevealReclicks := 0
            Macro.treasureRevealExtended := false
            Macro.treasureRevealLoops := 0
            SetTreasureAppraiseStatus(
                "R" Macro.treasureRound " 행 " rowIdx " 연타 중..."
            )

        case "AFTER_ROUND":
            if (Macro.treasureWaitUntil && A_TickCount < Macro.treasureWaitUntil)
                return

            if (AreTreasureGoalsMet() || !HasAnyTreasureGoalEnabled()) {
                Macro.treasureState := "FINISH"
                Macro.treasureWaitUntil := A_TickCount + 40
                return
            }

            ; 목표 미달 → Reappraise 대기/클릭
            Macro.treasureState := "WAIT_REAPPRAISE"
            Macro.treasureForceAppraise := true
            Macro.treasureWaitUntil := A_TickCount + 30
            SetTreasureAppraiseStatus("목표 미달 — Reappraise 연타`n" FormatTreasureGoalStatusLine())

        case "WAIT_REAPPRAISE":
            if (Macro.treasureWaitUntil && A_TickCount < Macro.treasureWaitUntil)
                return

            if (TryTreasureReappraiseAndReset(true))
                return

            ; Reappraise 이름 없어도 Appraise로 강제 초기화 (캐시 우선)
            if (ClickTreasureButtonCached("appraise", true) || ClickTreasureNamedButton("Appraise")) {
                Macro.treasureForceAppraise := false
                Macro.treasureBusted := false
                Macro.treasureClickRetry := 0
                ClearTreasureRevealWait()
                Macro.treasurePicks := []
                Macro.treasureResults := []
                Macro.treasureRow := 1
                Macro.treasureState := "WAIT_REFRESH"
                Macro.treasureWaitUntil := A_TickCount + 80
                Macro.treasureResetWaitStarted := A_TickCount
                Macro.treasurePostResetArmed := false
                SetTreasureAppraiseStatus("Appraise 클릭 — 바로 연타 재개...")
                return
            }

            SetTreasureAppraiseStatus("Reappraise/Appraise 연타 대기...")
            Macro.treasureWaitUntil := A_TickCount + 40

        case "NEXT_ROUND":
            ; 하위 호환: WAIT_REAPPRAISE로 전환
            Macro.treasureForceAppraise := true
            Macro.treasureState := "WAIT_REAPPRAISE"
            Macro.treasureWaitUntil := A_TickCount + 20

        case "WAIT_REFRESH":
            if (Macro.treasureWaitUntil && A_TickCount < Macro.treasureWaitUntil)
                return

            if (HasAnyTreasureGoalEnabled() && AreTreasureGoalsMet()) {
                Macro.treasureState := "FINISH"
                return
            }

            ; 리셋 안 됐어도 너무 오래 안 기다림 — 짧게 보고 바로 1행 연타
            if (!AreTreasureSlotsResetForNewRound()) {
                if !(Macro.treasureResetWaitStarted)
                    Macro.treasureResetWaitStarted := A_TickCount
                if ((A_TickCount - Macro.treasureResetWaitStarted) < 1200) {
                    SetTreasureAppraiseStatus("판 리셋 확인 중(짧게)...")
                    Macro.treasureWaitUntil := A_TickCount + 50
                    return
                }
                RefreshTreasureAppraiseGrid()
            }
            Macro.treasurePostResetArmed := false
            Macro.treasureResetWaitStarted := 0

            Macro.treasureRound += 1
            Macro.treasureRow := 1
            Macro.treasurePicks := []
            Macro.treasureResults := []
            Macro.treasureBusted := false
            Macro.treasureClickRetry := 0
            ClearTreasureRevealWait()
            Macro.treasureState := "CLICK_ROWS"
            ArmTreasurePostReappraiseSettle()
            FocusRobloxWindow()
            SetTreasureAppraiseStatus(
                "라운드 " Macro.treasureRound " — 1행 연타 시작`n"
                . FormatTreasureGoalStatusLine()
            )

        case "FINISH":
            if (Macro.treasureWaitUntil && A_TickCount < Macro.treasureWaitUntil)
                return
            if (IsTreasureAppraiseAutoTakeEnabled()) {
                if !ClickTreasureButtonCached("takeNow", true)
                    ClickTreasureNamedButton("TakeNow")
            }
            summary := FormatTreasureResultsSummary()
            goalLine := FormatTreasureGoalStatusLine()
            CompleteTreasureAppraiseCycle(
                (HasAnyTreasureGoalEnabled() && AreTreasureGoalsMet() ? "목표 달성. " : "완료. ")
                . goalLine
                . (summary != "" ? "`n" summary : "")
            )

        default:
    }
}

FormatTreasureResultsSummary() {
    global Macro
    if !(Macro.treasureResults is Array) || !Macro.treasureResults.Length
        return ""
    out := ""
    for i, m in Macro.treasureResults {
        if (out != "")
            out .= " "
        out .= m
    }
    return out
}
