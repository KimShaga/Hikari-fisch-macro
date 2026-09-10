; ============================================================================
;  OpenMacro XTernal
;  SPDX-License-Identifier: AGPL-3.0-only
;  SPDX-FileCopyrightText: (c) 2026 OpenMacro XTernal (@anorexc)
; ============================================================================
#Requires AutoHotkey v2.0
#Include Components\Border.ahk
#Include Components\Button.ahk
#Include Components\InfoPopup.ahk
#Include Components\PromoBanner.ahk
#Include Dialogs\AddMutationDialog.ahk
#Include Dialogs\ConfigDialogs.ahk

GetGui() {
    global FULL_VER, UPSTREAM_VER, APP_NAME, RBLX_BASE, RBLX_PID, ENV, ROD, APPEARANCE, USERPREFS
    global StatusText, PowerText, ProgressText, CaughtText, LostText, SuccessRateText
    global LullabyFishCb, LullabyFishLabel

    Accent     := APPEARANCE["accent_color"]
    BgColor    := APPEARANCE["bg_color"]
    TextColor  := APPEARANCE["text_color"]
    BorderColor := APPEARANCE["border_color"]
    SubColor   := DimHex(TextColor, 0.6)
    ; Promo strip pinned above the tabs. While the offer is live this reserves
    ; HEIGHT px at the top; once it expires bannerH is 0 and the layout below is
    ; byte-for-byte the original (the tab + its children + status just shift down).
    bannerH    := PromoBanner.IsActive() ? PromoBanner.HEIGHT : 0

    Border.DefaultColor := "0x" BorderColor

    button.DefaultTextColor := "0x" TextColor
    button.DefaultBg := "0x" Accent
    
    Accent := APPEARANCE["accent_color"]
    
    DCLogoPath := A_ScriptDir "\images\DiscordLogo.png"

    mg := Gui("AlwaysOnTop +Border")
    mg.BackColor := "0x" BgColor
    mg.Title := APP_NAME " (" FULL_VER ")"
    mg.SetFont(, "Segoe UI")

    ; App icon: the black logo in the title bar (small icon) so it stays visible on
    ; the light Windows title bar, and the normal white logo in the taskbar / Alt-Tab
    ; switcher (big icon). Per-window small vs big icons require WM_SETICON. The Gui
    ; isn't shown yet here, so DetectHiddenWindows must be on for ahk_id to find it.
    TitleIconPath := A_ScriptDir "\images\OpenMacroBlack.png"
    TaskIconPath  := A_ScriptDir "\images\OpenMacro.png"
    prevDHW := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    if FileExist(TitleIconPath)
        SendMessage(0x0080, 0, LoadHQIcon(TitleIconPath, 16), , "ahk_id " mg.Hwnd)  ; WM_SETICON, ICON_SMALL
    if FileExist(TaskIconPath)
        SendMessage(0x0080, 1, LoadHQIcon(TaskIconPath, 32), , "ahk_id " mg.Hwnd)   ; WM_SETICON, ICON_BIG
    DetectHiddenWindows(prevDHW)

    global g_MainTab
    MainTab := mg.AddTab3("x0 y0 w880 h700 c" Accent, ["낚시", "창&작살", "감정", "인챈트", "아이템", "헌트", "기타", "단축키", "설정", "크레딧"])
    MainTab.SetFont("bold")
    g_MainTab := MainTab

    MainTab.UseTab(1)

    ; ---- Left: 상태 / 캐스팅 / 낚시 ----
    mg.AddGroupBox("x10 y30 w425 h245 c" TextColor, "상태").SetFont("s9 bold")

    mg.AddText("x20 y48 w150 h20 c" TextColor, "장착 낚싯대").SetFont("s10")
    global RodEquipped := mg.AddText("x20 y68 w400 h28 c" TextColor, GetRodDisplayText())
    RodEquipped.SetFont("s11 underline")

    StatusText := mg.AddText("x20 y100 w200 h20 c" TextColor, "상태: ---")
    StatusText.SetFont("s11")
    global LullabyFishCb := mg.AddCheckbox("x230 y99 h20 w20")
    LullabyFishCb.Value := USERPREFS.Has("lullaby_fishing") ? USERPREFS["lullaby_fishing"] : 0
    LullabyFishCb.Visible := false
    global LullabyFishLabel := mg.AddText("x250 y100 w160 h20 c" TextColor, "낚시 수행")
    LullabyFishLabel.SetFont("s10")
    LullabyFishLabel.Visible := false
    PersistLullabyFishing(*) {
        global USERPREFS, SETTINGS
        USERPREFS["lullaby_fishing"] := LullabyFishCb.Value ? 1 : 0
        SETTINGS["user"]["lullaby_fishing"] := USERPREFS["lullaby_fishing"]
        SaveSettingsFile()
        if (!USERPREFS["lullaby_fishing"])
            ReleaseMouse(true)
    }
    LullabyFishCb.OnEvent("Click", PersistLullabyFishing)

    PowerText := mg.AddText("x20 y122 w190 h20 c" TextColor, "파워: ---")
    PowerText.SetFont("s10")
    ProgressText := mg.AddText("x220 y122 w190 h20 c" TextColor, "진행: ---")
    ProgressText.SetFont("s10")

    CaughtText := mg.AddText("x20 y144 w120 h20 c" TextColor, "낚음: 0")
    CaughtText.SetFont("s10")
    LostText := mg.AddText("x150 y144 w120 h20 c" TextColor, "놓침: 0")
    LostText.SetFont("s10")
    SuccessRateText := mg.AddText("x280 y144 w140 h20 c" TextColor, "성공률: 0.0%")
    SuccessRateText.SetFont("s10")

    climate := FormatWorldClimateDisplay()
    global WeatherText := mg.AddText("x20 y166 w400 h18 c" TextColor, climate["weatherLine"])
    WeatherText.SetFont("s9")
    global ClimateDetailText := mg.AddText("x20 y186 w400 h18 c" TextColor, climate["detailLine"])
    ClimateDetailText.SetFont("s9")
    global BuffStatusText := mg.AddText("x20 y206 w400 h36 c" TextColor, FormatActiveBuffsDisplay())
    BuffStatusText.SetFont("s9")

    ; Keep the advanced controls alive so existing save/validation callbacks
    ; retain their references when the window is hidden and reopened.
    FishingSettingsGui := Gui("+Owner" mg.Hwnd " +AlwaysOnTop +Border", "고급 낚시 설정")
    FishingSettingsGui.BackColor := "0x" BgColor
    FishingSettingsGui.SetFont(, "Segoe UI")
    FishingSettingsGui.OnEvent("Close", (*) => FishingSettingsGui.Hide())
    FishingSettingsGui.OnEvent("Escape", (*) => FishingSettingsGui.Hide())

    FishingSettingsGui.AddGroupBox("x10 y30 w425 h200 c" TextColor, "캐스팅").SetFont("s9 bold")

    FishingSettingsGui.AddText("x20 y50 w100 h20 c" TextColor, "캐스트 모드").SetFont("s10")
    CastMode := FishingSettingsGui.AddDDL("x305 y50 w110", ["퍼펙트", "숏", "사용자 지정"])
    CastModeHelp := FishingSettingsGui.AddText("x210 y50 w50 h20 c" Accent, "설명")
    CastModeHelp.SetFont("underline")
    CastModeHelp.OnEvent("Click", (*) => InfoPopup.Show("캐스트 모드", "캐스트를 놓는 목표 파워입니다. 퍼펙트는 풀 캐스트용 고정 고임계값, 숏은 빠른 캐스트용 저임계값, 사용자 지정은 직접 설정한 캐스트 파워 임계값을 사용합니다."))

    FishingSettingsGui.AddText("x20 y73 w150 h20 c" TextColor, "캐스트 파워 임계값").SetFont("s10")
    CastPowerThreshold := FishingSettingsGui.AddEdit("x305 y73 w110 h20")
    CastPowerThresholdHelp := FishingSettingsGui.AddText("x210 y73 w50 h20 c" Accent, "설명")
    CastPowerThresholdHelp.SetFont("underline")
    CastPowerThresholdHelp.OnEvent("Click", (*) => InfoPopup.Show("캐스트 파워 임계값", "사용자 지정 캐스트 모드에서만 사용합니다. 캐스트 파워가 이 퍼센트에 도달할 때까지 좌클릭을 유지한 뒤 뗍니다. 높을수록 멀리, 낮을수록 빨리 던집니다."))

    FishingSettingsGui.AddText("x20 y96 w150 h20 c" TextColor, "캐스트 타임아웃").SetFont("s10")
    CastTimeout := FishingSettingsGui.AddEdit("x305 y96 w110 h20")
    CastTimeoutHelp := FishingSettingsGui.AddText("x210 y96 w50 h20 c" Accent, "설명")
    CastTimeoutHelp.SetFont("underline")
    CastTimeoutHelp.OnEvent("Click", (*) => InfoPopup.Show("캐스트 타임아웃", "캐스트 시도를 포기하기까지 기다리는 시간입니다. 최소 5초입니다. 캐스트 바 대기와 해제 후 낚시 UI 대기에도 쓰입니다. 타임아웃 시 '타임아웃 시 재캐스트' 설정에 따라 재시도하거나 멈춥니다."))

    FishingSettingsGui.AddText("x20 y119 w150 h20 c" TextColor, "사이클 시작 딜레이").SetFont("s10")
    PreCastDelay := FishingSettingsGui.AddEdit("x305 y119 w110 h20")
    PreCastDelayHelp := FishingSettingsGui.AddText("x210 y119 w50 h20 c" Accent, "설명")
    PreCastDelayHelp.SetFont("underline")
    PreCastDelayHelp.OnEvent("Click", (*) => InfoPopup.Show("사이클 시작 딜레이", "각 사이클 시작 후 캐스트 전 추가 대기입니다. 예약된 자동 토템/아이템도 핫바를 만지기 전에 이만큼 기다립니다."))

    FishingSettingsGui.AddText("x20 y142 w150 h20 c" TextColor, "캐스트 후 딜레이").SetFont("s10")
    PostCastDelay := FishingSettingsGui.AddEdit("x305 y142 w110 h20")
    PostCastDelayHelp := FishingSettingsGui.AddText("x210 y142 w50 h20 c" Accent, "설명")
    PostCastDelayHelp.SetFont("underline")
    PostCastDelayHelp.OnEvent("Click", (*) => InfoPopup.Show("캐스트 후 딜레이", "캐스트를 놓은 뒤 흔들기 단계까지 대기입니다. 캐스트 해제와 훅/흔들기 사이에 여유가 필요하면 올리세요."))

    Border(FishingSettingsGui, 20, 167, 395, 1)

    FishingSettingsGui.AddText("x40 y178 w140 h20 c" TextColor, "타임아웃 시 재캐스트").SetFont("s10")
    CastOnTimeout := FishingSettingsGui.AddCheckbox("x20 y178 h20 w20")
    SaveCastBtn := button(FishingSettingsGui, "저장", 305, 175, {w: 110, h: 23, bg: BgColor, fontSize: 10})

    FishingSettingsGui.AddGroupBox("x10 y245 w425 h135 c" TextColor, "낚시").SetFont("s9 bold")

    FishingSettingsGui.AddText("x20 y265 w140 h20 c" TextColor, "낚시 조작 딜레이").SetFont("s10")
    FishingActionDelay := FishingSettingsGui.AddEdit("x305 y265 w110 h20")
    FishingActionDelayHelp := FishingSettingsGui.AddText("x210 y265 w50 h20 c" Accent, "설명")
    FishingActionDelayHelp.SetFont("underline")
    FishingActionDelayHelp.OnEvent("Click", (*) => InfoPopup.Show("낚시 조작 딜레이", "물고기 바 밸런싱 중 좌클릭 누름/뗌 사이 최소 간격입니다. 입력이 씹히거나 추적이 불안정하면 올리세요."))

    FishingSettingsGui.AddText("x20 y288 w140 h20 c" TextColor, "완료 임계값").SetFont("s10")
    CompletionThreshold := FishingSettingsGui.AddEdit("x305 y288 w110 h20")
    CompletionThresholdHelp := FishingSettingsGui.AddText("x210 y288 w50 h20 c" Accent, "설명")
    CompletionThresholdHelp.SetFont("underline")
    CompletionThresholdHelp.OnEvent("Click", (*) => InfoPopup.Show("완료 임계값", "낚시를 완료로 보고 낚시 단계를 끝내는 진행률(%)입니다. 게임이 시각적으로 먼저 가득 차면 100%보다 약간 낮게 두면 더 빨리 끝납니다."))

    FishingSettingsGui.AddText("x20 y311 w140 h20 c" TextColor, "흔들기 간격").SetFont("s10")
    ShakeInterval := FishingSettingsGui.AddEdit("x305 y311 w110 h20")
    ShakeIntervalHelp := FishingSettingsGui.AddText("x210 y311 w50 h20 c" Accent, "설명")
    ShakeIntervalHelp.SetFont("underline")
    ShakeIntervalHelp.OnEvent("Click", (*) => InfoPopup.Show("흔들기 간격", "낚시 UI가 뜰 때까지 흔들기 단계에서 Enter를 보내는 간격입니다. 낮을수록 더 자주, 높을수록 덜 흔듭니다."))

    SaveFishBtn := button(FishingSettingsGui, "저장", 305, 337, {w: 110, h: 23, bg: BgColor, fontSize: 10})

    ; ---- Right: 조정 ----
    FishingSettingsGui.AddGroupBox("x450 y30 w420 h425 c" TextColor, "조정").SetFont("s9 bold")

    FishingSettingsGui.AddText("x465 y48 w60 h20 c" TextColor, "프리셋").SetFont("s10")
    TuningPresetDdl := FishingSettingsGui.AddDDL("x530 y45 w200 h120", ["엄격", "느슨", "범용", "직접 설정"])
    TuningPresetHelp := FishingSettingsGui.AddText("x740 y48 w50 h20 c" Accent, "설명")
    TuningPresetHelp.SetFont("underline")
    TuningPresetHelp.OnEvent("Click", (*) => InfoPopup.Show("조정 프리셋",
        "엄격: 물고기가 극단적으로 빠르고 컨트롤이 낮은 낚싯대 (예: Trihard, Castbound).`n"
        . "정확도·빠른 복귀·빠른 판단이 중심이고, 부족한 부분을 약간의 예측으로 보완합니다.`n`n"
        . "느슨: 물고기는 극단적으로 빠르지만 컨트롤이 높은 낚싯대 (예: Onirifalx).`n"
        . "빠른 판단과 예측을 중심으로 맞춥니다.`n`n"
        . "범용: 기본 권장값.`n`n"
        . "직접 설정: 아래 수치를 직접 수정합니다. 값을 바꾸면 자동으로 이 모드로 전환됩니다."))
    savedPreset := MAIN.Has("tuning_preset") ? MAIN["tuning_preset"] : "general"
    TuningPresetDdl.Choose(GetFishingTuningPresetIndex(savedPreset))

    FishingSettingsGui.AddText("x465 y82 w160 h20 c" TextColor, "갱신 주기").SetFont("s10")
    UpdateRateHelp := FishingSettingsGui.AddText("x620 y83 w50 h20 c" Accent, "설명")
    UpdateRateHelp.SetFont("underline")
    UpdateRateHelp.OnEvent("Click", (*) => InfoPopup.Show("갱신 주기", "매크로가 밸런싱 판단을 갱신하는 주기(밀리초)입니다. 낮을수록 반응이 빠르지만 클릭이 잦아질 수 있고, 높을수록 부드럽지만 반응이 느려질 수 있습니다."))
    UpdateRate := FishingSettingsGui.AddEdit("x700 y82 w45 h20", MAIN["update_rate"])
    FishingSettingsGui.AddText("x750 y82 w100 h20 c" TextColor, "1 - 35").SetFont("s9")

    FishingSettingsGui.AddText("x465 y112 w160 h20 c" TextColor, "예측 강도").SetFont("s10")
    PredictionStrengthHelp := FishingSettingsGui.AddText("x620 y113 w50 h20 c" Accent, "설명")
    PredictionStrengthHelp.SetFont("underline")
    PredictionStrengthHelp.OnEvent("Click", (*) => InfoPopup.Show("예측 강도", "플레이어 바의 움직임을 얼마나 앞서 예측할지 정합니다. 높을수록 더 앞서 보고 빨리 반응하고, 낮을수록 직접적이지만 빠른 변화에 뒤처질 수 있습니다."))
    PredictionStrength := FishingSettingsGui.AddEdit("x700 y112 w45 h20", Format("{:.1f}", MAIN["prediction_strength"]))
    FishingSettingsGui.AddText("x750 y112 w100 h20 c" TextColor, "1.0 - 20.0").SetFont("s9")

    FishingSettingsGui.AddText("x465 y142 w160 h20 c" TextColor, "중립 듀티 사이클").SetFont("s10")
    NDCycleHelp := FishingSettingsGui.AddText("x620 y143 w50 h20 c" Accent, "설명")
    NDCycleHelp.SetFont("underline")
    NDCycleHelp.OnEvent("Click", (*) => InfoPopup.Show("중립 듀티 사이클", "밸런싱 중 클릭 유지/해제 기본 비율입니다. 높을수록 유지를 더 자주 하고, 낮을수록 해제를 더 자주 합니다."))
    NDCycle := FishingSettingsGui.AddEdit("x700 y142 w45 h20", Format("{:.1f}", MAIN["neutral_duty_cycle"]))
    FishingSettingsGui.AddText("x750 y142 w100 h20 c" TextColor, "0.20 - 0.60").SetFont("s9")

    FishingSettingsGui.AddText("x465 y172 w160 h20 c" TextColor, "근접 임계값").SetFont("s10")
    CloseThresholdHelp := FishingSettingsGui.AddText("x620 y173 w50 h20 c" Accent, "설명")
    CloseThresholdHelp.SetFont("underline")
    CloseThresholdHelp.OnEvent("Click", (*) => InfoPopup.Show("근접 임계값", "물고기와 플레이어 바가 얼마나 가까워져야 미세 밸런싱으로 전환할지입니다. 낮을수록 더 맞춰야 하고, 높을수록 더 일찍 미세 조절을 시작합니다."))
    CloseThreshold := FishingSettingsGui.AddEdit("x700 y172 w45 h20", Format("{:.2f}", MAIN["close_threshold"]))
    FishingSettingsGui.AddText("x750 y172 w100 h20 c" TextColor, "0.01 - 0.10").SetFont("s9")

    FishingSettingsGui.AddText("x465 y202 w160 h20 c" TextColor, "속도 감쇠").SetFont("s10")
    VelocityDampingHelp := FishingSettingsGui.AddText("x620 y203 w50 h20 c" Accent, "설명")
    VelocityDampingHelp.SetFont("underline")
    VelocityDampingHelp.OnEvent("Click", (*) => InfoPopup.Show("속도 감쇠", "플레이어 바가 얼마나 빠르게 움직일 때 미세 밸런싱을 멈추고 강한 보정으로 돌아갈지입니다. 낮을수록 빨리 반응하고, 높을수록 더 오래 미세 조절을 유지합니다."))
    VelocityDamping := FishingSettingsGui.AddEdit("x700 y202 w45 h20", MAIN["velocity_damping"])
    FishingSettingsGui.AddText("x750 y202 w100 h20 c" TextColor, "10 - 60").SetFont("s9")

    FishingSettingsGui.AddText("x465 y232 w160 h20 c" TextColor, "비례 게인").SetFont("s10")
    ProportionalGainHelp := FishingSettingsGui.AddText("x620 y233 w50 h20 c" Accent, "설명")
    ProportionalGainHelp.SetFont("underline")
    ProportionalGainHelp.OnEvent("Click", (*) => InfoPopup.Show("비례 게인", "위치 오차에 얼마나 강하게 반응할지입니다. 높을수록 강하게 보정하고, 낮을수록 부드럽지만 더 쉽게 밀릴 수 있습니다."))
    ProportionalGain := FishingSettingsGui.AddEdit("x700 y232 w45 h20", Format("{:.2f}", MAIN["proportional_gain"]))
    FishingSettingsGui.AddText("x750 y232 w100 h20 c" TextColor, "0.10 - 1.50").SetFont("s9")

    FishingSettingsGui.AddText("x465 y262 w160 h20 c" TextColor, "미분 게인").SetFont("s10")
    DerivativeGainHelp := FishingSettingsGui.AddText("x620 y263 w50 h20 c" Accent, "설명")
    DerivativeGainHelp.SetFont("underline")
    DerivativeGainHelp.OnEvent("Click", (*) => InfoPopup.Show("미분 게인", "이동 속도에 얼마나 강하게 반응할지입니다. 높을수록 흔들림을 더 잡지만, 너무 높으면 조작이 튀게 느껴질 수 있습니다."))
    DerivativeGain := FishingSettingsGui.AddEdit("x700 y262 w45 h20", Format("{:.2f}", MAIN["derivative_gain"]))
    FishingSettingsGui.AddText("x750 y262 w100 h20 c" TextColor, "0.00 - 1.00").SetFont("s9")

    FishingSettingsGui.AddText("x465 y292 w160 h20 c" TextColor, "가장자리 경계").SetFont("s10")
    EdgeBoundaryHelp := FishingSettingsGui.AddText("x620 y293 w50 h20 c" Accent, "설명")
    EdgeBoundaryHelp.SetFont("underline")
    EdgeBoundaryHelp.OnEvent("Click", (*) => InfoPopup.Show("가장자리 경계", "바가 가장자리에 얼마나 가까워지면 밸런싱을 멈추고 복구로 전환할지입니다. 높을수록 안전하게, 낮을수록 가장자리에 더 가깝게 허용합니다."))
    EdgeBoundary := FishingSettingsGui.AddEdit("x700 y292 w45 h20", Format("{:.2f}", MAIN["edge_boundary"]))
    FishingSettingsGui.AddText("x750 y292 w100 h20 c" TextColor, "0.02 - 0.30").SetFont("s9")

    TuningFieldCtrls := [
        UpdateRate, PredictionStrength, NDCycle, CloseThreshold,
        VelocityDamping, ProportionalGain, DerivativeGain, EdgeBoundary
    ]

    SetTuningFieldsEnabled(enabled) {
        for ctrl in TuningFieldCtrls
            ctrl.Enabled := enabled
    }

    SyncTuningFieldsFromMain() {
        global MAIN
        UpdateRate.Value := MAIN["update_rate"]
        PredictionStrength.Value := Format("{:.1f}", MAIN["prediction_strength"])
        NDCycle.Value := Format("{:.2f}", MAIN["neutral_duty_cycle"])
        CloseThreshold.Value := Format("{:.2f}", MAIN["close_threshold"])
        VelocityDamping.Value := MAIN["velocity_damping"]
        ProportionalGain.Value := Format("{:.2f}", MAIN["proportional_gain"])
        DerivativeGain.Value := Format("{:.2f}", MAIN["derivative_gain"])
        EdgeBoundary.Value := Format("{:.2f}", MAIN["edge_boundary"])
    }

    ApplyTuningPreset(presetId, doSave := true) {
        global MAIN, SETTINGS
        presetId := StrLower(Trim(presetId))
        MAIN["tuning_preset"] := presetId
        SETTINGS["main"]["tuning_preset"] := presetId

        if (presetId != "custom") {
            values := GetFishingTuningPresetValues(presetId)
            for key, value in values {
                MAIN[key] := value
                SETTINGS["main"][key] := value
            }
            SyncTuningFieldsFromMain()
            SetTimer(MacroLoop, MAIN["update_rate"])
            SetTuningFieldsEnabled(false)
        } else {
            SetTuningFieldsEnabled(true)
        }

        TuningPresetDdl.Choose(GetFishingTuningPresetIndex(presetId))
        if (doSave)
            SaveSettingsFile()
    }

    MarkTuningPresetCustom(*) {
        global MAIN, SETTINGS
        if ((MAIN.Has("tuning_preset") ? MAIN["tuning_preset"] : "") = "custom")
            return
        MAIN["tuning_preset"] := "custom"
        SETTINGS["main"]["tuning_preset"] := "custom"
        TuningPresetDdl.Choose(4)
        SetTuningFieldsEnabled(true)
        SaveSettingsFile()
    }

    OnTuningPresetChange(*) {
        ApplyTuningPreset(GetFishingTuningPresetIdByIndex(TuningPresetDdl.Value), true)
    }

    TuningPresetDdl.OnEvent("Change", OnTuningPresetChange)

    UpdateRate.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("update_rate", UpdateRate, 1, 35, true, 0), MarkTuningPresetCustom()))
    PredictionStrength.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("prediction_strength", PredictionStrength, 1.0, 20.0, false, 1), MarkTuningPresetCustom()))
    CloseThreshold.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("close_threshold", CloseThreshold, 0.01, 0.10, false, 2), MarkTuningPresetCustom()))
    NDCycle.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("neutral_duty_cycle", NDCycle, 0.20, 0.60, false, 2), MarkTuningPresetCustom()))
    VelocityDamping.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("velocity_damping", VelocityDamping, 10.0, 60.0, true, 0), MarkTuningPresetCustom()))
    ProportionalGain.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("proportional_gain", ProportionalGain, 0.10, 1.50, false, 2), MarkTuningPresetCustom()))
    DerivativeGain.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("derivative_gain", DerivativeGain, 0.00, 1.00, false, 2), MarkTuningPresetCustom()))
    EdgeBoundary.OnEvent("LoseFocus", (*) => (ValidateAndSaveMain("edge_boundary", EdgeBoundary, 0.02, 0.30, false, 2), MarkTuningPresetCustom()))

    ; Lock fields for named presets; don't rewrite saved numbers on every GUI open.
    SetTuningFieldsEnabled(savedPreset = "custom")

    mg.AddGroupBox("x450 y30 w420 h135 c" TextColor, "자동 실행").SetFont("s9 bold")

    AutoTotemEnabled := mg.AddCheckbox("x465 y50 h20 w20")
    AutoTotemEnabled.Value := MAIN.Has("auto_totem_enabled") ? MAIN["auto_totem_enabled"] : 0
    mg.AddText("x485 y51 w90 h20 c" TextColor, "아이템 사용").SetFont("s10")
    AutoTotemHelp := mg.AddText("x580 y51 w40 h20 c" Accent, "설명")
    AutoTotemHelp.SetFont("underline")
    AutoTotemHelp.OnEvent("Click", (*) => InfoPopup.Show("아이템 사용", "켜면 낚시 매크로 실행 중 아이템 탭에서 선택한 토템·포션·Shell을 핫바에서 자동으로 사용합니다."))

    global AutoTotemSelectionText := mg.AddText("x465 y72 w390 h18 c" SubColor, FormatAutoTotemSelectionDisplay())
    AutoTotemSelectionText.SetFont("s8")

    global AutoSovereignEnchantCharge := mg.AddCheckbox("x465 y98 w20 h20")
    AutoSovereignEnchantCharge.Value := MAIN.Has("auto_sovereign_enchant_charge_enabled") ? MAIN["auto_sovereign_enchant_charge_enabled"] : 0
    mg.AddText("x485 y100 w160 h20 c" TextColor, "자동 군주 인챈트 충전").SetFont("s9")
    AutoSovereignEnchantChargeHelp := mg.AddText("x650 y100 w40 h20 c" Accent, "설명")
    AutoSovereignEnchantChargeHelp.SetFont("underline")
    AutoSovereignEnchantChargeHelp.OnEvent("Click", (*) => InfoPopup.Show("자동 군주 인챈트 충전", "낚시 중 파워가 95% 이하이면 핫바 Relic으로 게임패스 Enchant를 돌려 100% 이상까지 충전한 뒤 낚시를 재개합니다.`n(이하 95% / 목표 100% 고정)"))

    mg.AddText("x465 y128 w280 h20 c" SubColor, "고정: 95% 이하 → 100% 이상까지").SetFont("s8")

    AdvancedFishingBtn := mg.AddButton("x450 y185 w420 h36", "고급 낚시 설정")
    AdvancedFishingBtn.OnEvent("Click", (*) => FishingSettingsGui.Show("w880 h475"))
    mg.AddText("x465 y230 w390 h36 c" SubColor, "캐스팅 · 낚시 · 조정 설정을 변경합니다.").SetFont("s9")

    ; lazy-tab controls (outer scope so nested assigns persist)
    AccessabilityHeader := unset
    AlertTotemFailedCb := unset
    AppraiseCustomEdit := unset
    AppraiseMutationTotem := unset
    AppraiseMutationTotemHelp := unset
    AutoAppraiseMutation := unset
    AutoAppraiseMutationHelp := unset
    AutoEnchantHelp := unset
    AutoEnchantName := unset
    BuffItemHelp := unset
    BuffToggleLuck1 := unset
    BuffToggleLuck2 := unset
    BuffToggleLuck3 := unset
    BuffToggleLure1 := unset
    BuffToggleLure2 := unset
    BuffToggleLure3 := unset
    BuffToggleShellDepth := unset
    BuffToggleShellEndurance := unset
    BuffToggleShellFortune := unset
    BuffToggleShellSwiftness := unset
    BuffToggleShellWrath := unset
    CreditsDiscordLink := unset
    CreditsLicenseLink := unset
    CreditsLocalLicense := unset
    CreditsLocalNotice := unset
    CreditsWebLink := unset
    DarkModeToggle := unset
    DiffLogBtn := unset
    EnchantCustomEdit := unset
    EnchantDumpBtn := unset
    FixRbxHelpBtn := unset
    FixRbxKey := unset
    GamepassAppraise := unset
    GamepassEnchant := unset
    GamepassEnchantHelp := unset
    GamepassHelp := unset
    HikariDiscordLink := unset
    HumpbackSpawnBtn := unset
    HumpbackSpawnHelp := unset
    HuntActiveHelp := unset
    HuntCategoryDdl := unset
    HuntCategoryHelp := unset
    HuntClearBtn := unset
    HuntDetectEnabled := unset
    HuntDetectHelp := unset
    HuntDetectNotify := unset
    HuntDetectSound := unset
    HuntDetectWebhook := unset
    HuntDumpBtn := unset
    HuntList := unset
    HuntNotifyHelp := unset
    HuntRefreshBtn := unset
    HuntSelectAllBtn := unset
    HuntSoundHelp := unset
    HuntWatchCountText := unset
    HuntWebhookHelp := unset
    LegalNotice := unset
    MenuDumpBtn := unset
    StellaDumpBtn := unset
    StellarwaveLogCb := unset
    StellarwaveLogOpenBtn := unset
    StellarwaveLogHelp := unset
    MinimizeOnMacroToggle := unset
    NpcDumpBtn := unset
    OpenSettingsBtn := unset
    PublicServerEnabled := unset
    PublicServerHelp := unset
    ReelDebugCb := unset
    ReelDebugHelp := unset
    ReelDebugLogCb := unset
    ReelDebugOpenBtn := unset
    ReloadKey := unset
    SaveWebhookBtn := unset
    SovereignEnchantCharge := unset
    SovereignEnchantChargeHelp := unset
    StartMacroKey := unset
    StopAppraiseKey := unset
    SummaryCastTimeoutsCb := unset
    SummaryConfigCb := unset
    SummaryFishCb := unset
    SummaryRodCb := unset
    SummarySessionTimeCb := unset
    SummarySuccessRateCb := unset
    SummaryTotemPopsCb := unset
    SummaryTotemStateCb := unset
    TestWebhookBtn := unset
    TotemInterval := unset
    TotemIntervalHelp := unset
    TotemToggleAurora := unset
    TotemToggleClearcast := unset
    TotemToggleEclipse := unset
    TotemToggleMutation := unset
    TotemToggleShiny := unset
    TotemToggleSmokescreen := unset
    TotemToggleSparkling := unset
    TotemToggleTempest := unset
    TotemToggleTropical := unset
    TotemToggleWindset := unset
    TreasureAppraise := unset
    TreasureAppraiseHelp := unset
    TreasureAutoTake := unset
    TreasureGoalBigGiant := unset
    TreasureGoalBigGiantHelp := unset
    TreasureGoalMult := unset
    TreasureGoalMultEdit := unset
    TreasureGoalMultHelp := unset
    TreasureGoalTotal := unset
    TreasureGoalTotalEdit := unset
    TreasureGoalTotalHelp := unset
    UseModeDdl := unset
    UseModeHelp := unset
    WebhookEnabled := unset
    WebhookInterval := unset
    WebhookUrlEdit := unset
    WindowUseEnabled := unset
    WindowUseHelp := unset
    WindowUseStatusText := unset
    HarpoonUseEnabled := unset
    HarpoonUseHelp := unset
    HarpoonStatusText := unset

    ; 탭 2~10: 보고 있을 때만 생성, 떠나면 Destroy (낚시 탭은 상태 갱신용으로 유지)
    global g_TabBuilt, g_TabCtrls, g_ActiveLazyTab
    g_TabBuilt := Map(1, true)
    g_TabCtrls := Map()
    g_ActiveLazyTab := 1
    loop 9 {
        g_TabBuilt[A_Index + 1] := false
        g_TabCtrls[A_Index + 1] := []
    }

    SnapshotGuiHwnds() {
        m := Map()
        for ctrl in mg {
            try m[ctrl.Hwnd] := true
            catch {
            }
        }
        return m
    }

    EnsureLazyTab(idx) {
        global g_TabBuilt
        if !(idx >= 2 && idx <= 10)
            return
        if (g_TabBuilt.Has(idx) && g_TabBuilt[idx])
            return
        LazyBuildTab(idx)
        g_TabBuilt[idx] := true
    }

    DestroyLazyTab(idx) {
        global g_TabBuilt, g_TabCtrls
        if !(idx >= 2 && idx <= 10)
            return
        if !(g_TabBuilt.Has(idx) && g_TabBuilt[idx]) && !(g_TabCtrls.Has(idx) && g_TabCtrls[idx].Length)
            return

        ; Tab3 페이지에 붙인 컨트롤은 해당 탭을 연 뒤 Destroy 해야 함
        try MainTab.UseTab(idx)
        catch {
        }

        hwnds := (g_TabCtrls.Has(idx) && g_TabCtrls[idx]) ? g_TabCtrls[idx] : []
        i := hwnds.Length
        while (i >= 1) {
            hwnd := hwnds[i]
            try {
                if (c := GuiCtrlFromHwnd(hwnd))
                    c.Destroy()
            } catch {
            }
            i -= 1
        }
        g_TabCtrls[idx] := []
        g_TabBuilt[idx] := false
        ClearLazyTabRefs(idx)
    }

    DestroyAllLazyTabsExcept(keepIdx := 0) {
        loop 9 {
            i := A_Index + 1
            if (i != keepIdx)
                DestroyLazyTab(i)
        }
    }

    ClearLazyTabRefs(idx) {
        ; 이름 붙은 참조를 끊어 IsSet 가드가 동작하게 함
        switch idx {
            case 2:
                global WindowUseStatusText, HarpoonStatusText
                WindowUseEnabled := unset, WindowUseHelp := unset, WindowUseStatusText := unset
                HarpoonUseEnabled := unset, HarpoonUseHelp := unset, HarpoonStatusText := unset
            case 3:
                global AppraiseStatusText, TreasureStatusText
                GamepassAppraise := unset, GamepassHelp := unset
                AppraiseMutationTotem := unset, AppraiseMutationTotemHelp := unset
                AutoAppraiseMutation := unset, AutoAppraiseMutationHelp := unset
                AppraiseCustomEdit := unset
                AppraiseStatusText := unset
                TreasureAppraise := unset, TreasureAppraiseHelp := unset, TreasureAutoTake := unset
                TreasureGoalMult := unset, TreasureGoalMultEdit := unset, TreasureGoalMultHelp := unset
                TreasureGoalTotal := unset, TreasureGoalTotalEdit := unset, TreasureGoalTotalHelp := unset
                TreasureGoalBigGiant := unset, TreasureGoalBigGiantHelp := unset
                TreasureStatusText := unset
            case 4:
                global EnchantStatusText
                GamepassEnchant := unset, GamepassEnchantHelp := unset
                SovereignEnchantCharge := unset, SovereignEnchantChargeHelp := unset
                AutoEnchantName := unset, AutoEnchantHelp := unset, EnchantCustomEdit := unset
                EnchantStatusText := unset
            case 5:
                TotemToggleAurora := unset, TotemToggleTropical := unset, TotemToggleEclipse := unset
                TotemToggleShiny := unset, TotemToggleSparkling := unset, TotemToggleMutation := unset
                TotemToggleClearcast := unset, TotemToggleSmokescreen := unset
                TotemToggleTempest := unset, TotemToggleWindset := unset
                UseModeDdl := unset, UseModeHelp := unset, TotemInterval := unset, TotemIntervalHelp := unset
                PublicServerEnabled := unset, PublicServerHelp := unset, BuffItemHelp := unset
                BuffToggleLuck1 := unset, BuffToggleLuck2 := unset, BuffToggleLuck3 := unset
                BuffToggleLure1 := unset, BuffToggleLure2 := unset, BuffToggleLure3 := unset
                BuffToggleShellDepth := unset, BuffToggleShellEndurance := unset
                BuffToggleShellFortune := unset, BuffToggleShellSwiftness := unset, BuffToggleShellWrath := unset
                TotemToggleControls := unset, BuffItemToggleControls := unset
            case 6:
                global HuntStatusText
                HuntCategoryDdl := unset, HuntCategoryHelp := unset
                HuntSelectAllBtn := unset, HuntClearBtn := unset, HuntList := unset
                HuntDetectEnabled := unset, HuntDetectHelp := unset
                HuntDetectSound := unset, HuntSoundHelp := unset
                HuntDetectNotify := unset, HuntNotifyHelp := unset
                HuntDetectWebhook := unset, HuntWebhookHelp := unset
                HuntRefreshBtn := unset, HuntActiveHelp := unset
                HuntWatchCountText := unset, HuntStatusText := unset
            case 7:
                global HumpbackStatusText
                HumpbackSpawnHelp := unset, HumpbackSpawnBtn := unset, HumpbackStatusText := unset
            case 8:
                StartMacroKey := unset, StopAppraiseKey := unset
                FixRbxKey := unset, FixRbxHelpBtn := unset, ReloadKey := unset
                OpenSettingsBtn := unset
            case 9:
                DarkModeToggle := unset, MinimizeOnMacroToggle := unset
                WebhookUrlEdit := unset, TestWebhookBtn := unset, SaveWebhookBtn := unset
                WebhookEnabled := unset, WebhookInterval := unset
                SummaryFishCb := unset, SummarySuccessRateCb := unset, SummaryRodCb := unset
                SummaryConfigCb := unset, SummaryTotemStateCb := unset, SummaryTotemPopsCb := unset
                SummarySessionTimeCb := unset, SummaryCastTimeoutsCb := unset, AlertTotemFailedCb := unset
                EnchantDumpBtn := unset, HuntDumpBtn := unset, NpcDumpBtn := unset, MenuDumpBtn := unset
                StellaDumpBtn := unset
                StellarwaveLogCb := unset, StellarwaveLogOpenBtn := unset, StellarwaveLogHelp := unset
                ReelDebugCb := unset, ReelDebugLogCb := unset, ReelDebugOpenBtn := unset, ReelDebugHelp := unset
                AccessabilityHeader := unset
            case 10:
                DiffLogBtn := unset, HikariDiscordLink := unset
                CreditsLicenseLink := unset, CreditsLocalLicense := unset, CreditsLocalNotice := unset
                CreditsWebLink := unset, CreditsDiscordLink := unset, LegalNotice := unset
        }
    }

    OnMainTabChange(ctrl, *) {
        global g_ActiveLazyTab, g_GuiSizing, g_DragDetached, g_HuntCategoryId
        ; 드래그 detach 중 탭 전환하면 HWND/redraw가 꼬일 수 있음 → 복구.
        if ((IsSet(g_DragDetached) && g_DragDetached) || (IsSet(g_GuiSizing) && g_GuiSizing)) {
            try DetachGuiChildrenForDrag(false)
            g_GuiSizing := false
            SetTimer(GuiCaptionDragSafety, 0)
        }
        oldIdx := IsSet(g_ActiveLazyTab) ? g_ActiveLazyTab : 0
        newIdx := ctrl.Value
        FlushLazyTabState(oldIdx)
        ; 탭을 떠날 때마다 Destroy 하면 Tab3 자식 HWND가 덜 지워진 채
        ; 새로 그려져 DDL(이전 분류)과 ListView(초기 상어)가 어긋남.
        ; 한 번 만든 탭은 유지하고, 처음 열 때만 생성한다.
        EnsureLazyTab(newIdx)
        g_ActiveLazyTab := (newIdx >= 1 && newIdx <= 10) ? newIdx : 1
        if (newIdx >= 2)
            try MainTab.UseTab(newIdx)
        if (newIdx = 6) {
            try {
                if (IsSet(HuntCategoryDdl) && HuntCategoryDdl && IsSet(HuntList) && HuntList)
                    ReloadHuntListView()
            } catch {
            }
        }
        ResizeGuiTab(ctrl)
    }

    ; 탭을 떠날 때 미저장 Edit / 헌트 분류 기억
    FlushLazyTabState(idx) {
        global g_HuntCategoryId
        if (idx = 3) {
            try {
                if (IsSet(AutoAppraiseMutation) && AutoAppraiseMutation && IsSet(AppraiseCustomEdit) && AppraiseCustomEdit)
                    ResolveAndSaveAppraiseTarget()
            } catch {
            }
        } else if (idx = 4) {
            try {
                if (IsSet(AutoEnchantName) && AutoEnchantName && IsSet(EnchantCustomEdit) && EnchantCustomEdit)
                    ResolveAndSaveEnchantTarget()
            } catch {
            }
        } else if (idx = 6) {
            try {
                if (IsSet(HuntCategoryDdl) && HuntCategoryDdl)
                    g_HuntCategoryId := ResolveHuntCategoryIdFromDdl(HuntCategoryDdl)
            } catch {
            }
        }
    }

    LazyBuildTab(idx) {
        global g_TabCtrls
        existing := SnapshotGuiHwnds()

        MainTab.UseTab(idx)
        switch idx {
            case 2:
                mg.AddGroupBox("x10 y30 w860 h200 c" TextColor, "창").SetFont("s9 bold")
                WindowUseEnabled := mg.AddCheckbox("x20 y55 w20 h20")
                WindowUseEnabled.Value := MAIN.Has("window_use_enabled") ? MAIN["window_use_enabled"] : 0
                mg.AddText("x45 y56 w120 h20 c" TextColor, "창 사용").SetFont("s10")
                WindowUseHelp := mg.AddText("x160 y56 w40 h20 c" Accent, "설명")
                WindowUseHelp.SetFont("underline")
                WindowUseHelp.OnEvent("Click", (*) => InfoPopup.Show("창 사용", "이 탭에서 매크로 시작(기본 F1)을 누르면 대기합니다.`nstab(창) GUI가 뜨고 바가 한 번 커지면(미니게임 시작) 좌·우 초고속 연타를 합니다.`n같은 키로 중지. (작살총과 동시 불가)"))
                mg.AddText("x20 y90 w820 h40 c" SubColor, "로블록스 창을 포커스한 뒤 시작하세요. GUI 감지 후 바가 커질 때까지 기다렸다가 좌·우를 매우 빠르게 번갈아 보냅니다.").SetFont("s9")
                global WindowUseStatusText := mg.AddText("x20 y145 w820 h50 c" TextColor, "상태: 대기.`n토글을 켠 뒤 이 탭에서 F1로 시작하세요.")
                WindowUseStatusText.SetFont("s9")
                WindowUseEnabled.OnEvent("Click", PersistWindowUseEnabled)

                mg.AddGroupBox("x10 y250 w860 h200 c" TextColor, "작살총").SetFont("s9 bold")
                HarpoonUseEnabled := mg.AddCheckbox("x20 y275 w20 h20")
                HarpoonUseEnabled.Value := MAIN.Has("harpoon_use_enabled") ? MAIN["harpoon_use_enabled"] : 0
                mg.AddText("x45 y276 w120 h20 c" TextColor, "작살총 사용").SetFont("s10")
                HarpoonUseHelp := mg.AddText("x170 y276 w40 h20 c" Accent, "설명")
                HarpoonUseHelp.SetFont("underline")
                HarpoonUseHelp.OnEvent("Click", (*) => InfoPopup.Show("작살총", "작살총을 든 상태에서 이 탭의 토글을 켜고 매크로 시작(기본 F1)을 누르면 작살총 매크로가 실행됩니다.`n같은 키로 다시 누르면 멈춥니다.`n(창 사용과 동시에 켤 수 없습니다.)"))
                mg.AddText("x20 y310 w820 h40 c" SubColor, "핫바에 작살총을 장착한 뒤 시작하세요.").SetFont("s9")
                global HarpoonStatusText := mg.AddText("x20 y365 w820 h50 c" TextColor, "상태: 대기.`n토글을 켠 뒤 이 탭에서 F1로 시작하세요.")
                HarpoonStatusText.SetFont("s9")
                HarpoonUseEnabled.OnEvent("Click", PersistHarpoonUseEnabled)
                UpdateWindowHarpoonStatusUi()

            case 3:
                mg.AddGroupBox("x10 y30 w860 h210 c" TextColor, "감정").SetFont("s9 bold")

                GamepassAppraise := mg.AddCheckbox("x20 y48 w20 h20")
                GamepassAppraise.Value := MAIN.Has("gamepass_appraise_enabled") ? MAIN["gamepass_appraise_enabled"] : 0
                mg.AddText("x40 y50 w150 h20 c" TextColor, "게임패스 감정 사용").SetFont("s9")
                GamepassHelp := mg.AddText("x195 y50 w40 h20 c" Accent, "설명")
                GamepassHelp.SetFont("underline")
                GamepassHelp.OnEvent("Click", (*) => InfoPopup.Show("게임패스 감정", "켜면 Appraise 버튼을 자동으로 찾아 클릭한 뒤 Enter로 Confirm을 처리합니다. 끄면 NPC 대화 선택지(Can you appraise…)를 자동으로 누릅니다. Pierre 등과 대화가 열린 상태에서 이 탭에서 매크로를 시작하세요."))

                AppraiseMutationTotem := mg.AddCheckbox("x250 y48 w20 h20")
                AppraiseMutationTotem.Value := MAIN.Has("auto_appraise_mutation_totem") ? MAIN["auto_appraise_mutation_totem"] : 0
                mg.AddText("x270 y50 w180 h20 c" TextColor, "자동 뮤테이션 토템 사용").SetFont("s9")
                AppraiseMutationTotemHelp := mg.AddText("x455 y50 w40 h20 c" Accent, "설명")
                AppraiseMutationTotemHelp.SetFont("underline")
                AppraiseMutationTotemHelp.OnEvent("Click", (*) => InfoPopup.Show("자동 뮤테이션 토템", "켜면 감정 중 Mutation Surge가 없을 때 핫바의 Mutation Totem을 자동으로 사용합니다.`n물고기가 핫바에 실제로 있는지 확인한 뒤에만 쓰며, 사용 후 같은 슬롯으로 다시 장착합니다.`n인벤토리에서만 든 물고기는 재장착할 수 없어 시작이 막힙니다.`n핫바에 Mutation Totem과 물고기를 함께 올려두세요."))
                Border(mg, 20, 71, 830, 1)

                mg.AddText("x20 y86 w100 h20 c" TextColor, "돌연변이").SetFont("s10")
                mutationItems := ["Mythical", "Abyssal", "Glossy", "Electric", "Negative", "Amber", "Fossilized", "Silver", "Darkened", "Scorched", "Albino", "Lunar", "Mosaic", "Translucent", "Shiny", "Big", "Midas", "Hexed", "Frozen", "Sparkling"]
                savedMutation := Trim(MAIN["auto_appraise_mutation"])
                mutationInList := false
                for item in mutationItems {
                    if (item = savedMutation) {
                        mutationInList := true
                        break
                    }
                }
                AutoAppraiseMutation := mg.AddDDL("x260 y85 w200 h100", mutationItems)
                if (mutationInList) {
                    try ControlChooseString(savedMutation, AutoAppraiseMutation)
                    catch
                        AutoAppraiseMutation.Choose(1)
                } else {
                    AutoAppraiseMutation.Choose(1)
                }

                AutoAppraiseMutationHelp := mg.AddText("x135 y88 h20 c" Accent, "설명")
                AutoAppraiseMutationHelp.SetFont("underline")
                AutoAppraiseMutationHelp.OnEvent("Click", (*) => InfoPopup.Show("돌연변이", "목록에서 목표 돌연변이를 고릅니다. 목록을 고르면 아래 직접 입력을 비우고 그 값을 씁니다. 직접 입력에 값을 넣으면 그 값이 우선합니다."))

                mg.AddText("x20 y113 w100 h20 c" TextColor, "직접 입력").SetFont("s10")
                AppraiseCustomEdit := mg.AddEdit("x260 y113 w200 h20", mutationInList ? "" : savedMutation)

                mg.AddText("x20 y141 w820 h28 c" SubColor, "NPC 대화가 열린 뒤 이 탭에서 시작하세요. 물고기가 핫바에 있는지 확인하세요.").SetFont("s8")

                global AppraiseStatusText := mg.AddText("x480 y86 w370 h90 c" TextColor, "상태: 준비됨.`n대화창을 연 뒤 시작하면 감정 매크로가 실행됩니다.")

                GamepassAppraise.OnEvent("Click", SaveGamepassAppraiseEnabled)
                AppraiseMutationTotem.OnEvent("Click", SaveAppraiseMutationTotemEnabled)
                AutoAppraiseMutation.OnEvent("Change", OnAppraiseMutationDdlChange)
                AppraiseCustomEdit.OnEvent("LoseFocus", (*) => ResolveAndSaveAppraiseTarget())
                AppraiseCustomEdit.OnEvent("Change", (*) => ResolveAndSaveAppraiseTarget())

                ; ── 보물섬 감정 (EventAppraise) ──
                mg.AddGroupBox("x10 y250 w860 h230 c" TextColor, "보물섬 감정").SetFont("s9 bold")

                TreasureAppraise := mg.AddCheckbox("x20 y268 w20 h20")
                TreasureAppraise.Value := MAIN.Has("treasure_appraise_enabled") ? MAIN["treasure_appraise_enabled"] : 0
                mg.AddText("x40 y270 w160 h20 c" TextColor, "보물섬 감정 사용").SetFont("s9")
                TreasureAppraiseHelp := mg.AddText("x205 y270 w40 h20 c" Accent, "설명")
                TreasureAppraiseHelp.SetFont("underline")
                TreasureAppraiseHelp.OnEvent("Click", (*) => InfoPopup.Show("보물섬 감정", "Treasure Appraise(EventAppraise) 창용입니다.`n3×7 슬롯에서 가운데 세로줄만 위에서 아래로 클릭합니다.`n아래 목표를 켜면 달성할 때까지 라운드를 반복합니다.`n창을 연 뒤 감정 탭에서 매크로를 시작하세요.`n(일반/게임패스 감정보다 우선)"))

                TreasureAutoTake := mg.AddCheckbox("x270 y268 w20 h20")
                TreasureAutoTake.Value := MAIN.Has("treasure_appraise_auto_take") ? MAIN["treasure_appraise_auto_take"] : 0
                mg.AddText("x290 y270 w120 h20 c" TextColor, "Take Now 자동").SetFont("s9")
                Border(mg, 20, 295, 830, 1)

                TreasureGoalMult := mg.AddCheckbox("x20 y310 w20 h20")
                TreasureGoalMult.Value := MAIN.Has("treasure_goal_mult_enabled") ? MAIN["treasure_goal_mult_enabled"] : 0
                mg.AddText("x40 y312 w220 h20 c" TextColor, "Header 배수(1x kg) ≥").SetFont("s9")
                TreasureGoalMultEdit := mg.AddEdit("x270 y310 w80 h20", MAIN.Has("treasure_goal_mult") ? MAIN["treasure_goal_mult"] : "1.10")
                TreasureGoalMultHelp := mg.AddText("x360 y312 w40 h20 c" Accent, "설명")
                TreasureGoalMultHelp.SetFont("underline")
                TreasureGoalMultHelp.OnEvent("Click", (*) => InfoPopup.Show("Header 배수 목표", "창 상단의 1x kg / 1.15x kg 같은 배수 표시가 입력값 이상이 될 때까지 반복합니다."))

                TreasureGoalTotal := mg.AddCheckbox("x20 y338 w20 h20")
                TreasureGoalTotal.Value := MAIN.Has("treasure_goal_total_kg_enabled") ? MAIN["treasure_goal_total_kg_enabled"] : 0
                mg.AddText("x40 y340 w220 h20 c" TextColor, "Total kg ≥").SetFont("s9")
                TreasureGoalTotalEdit := mg.AddEdit("x270 y338 w80 h20", MAIN.Has("treasure_goal_total_kg") ? MAIN["treasure_goal_total_kg"] : "500")
                TreasureGoalTotalHelp := mg.AddText("x360 y340 w40 h20 c" Accent, "설명")
                TreasureGoalTotalHelp.SetFont("underline")
                TreasureGoalTotalHelp.OnEvent("Click", (*) => InfoPopup.Show("Total kg 목표", "창 하단 Total: xxx kg 표시가 입력값 이상이 될 때까지 반복합니다."))

                TreasureGoalBigGiant := mg.AddCheckbox("x20 y366 w20 h20")
                TreasureGoalBigGiant.Value := MAIN.Has("treasure_goal_big_giant_enabled") ? MAIN["treasure_goal_big_giant_enabled"] : 0
                mg.AddText("x40 y368 w400 h20 c" TextColor, "물고기 수식어 Big / Giant 될 때까지").SetFont("s9")
                TreasureGoalBigGiantHelp := mg.AddText("x450 y368 w40 h20 c" Accent, "설명")
                TreasureGoalBigGiantHelp.SetFont("underline")
                TreasureGoalBigGiantHelp.OnEvent("Click", (*) => InfoPopup.Show("Big / Giant 목표", "들고 있는 물고기 이름에 Big 또는 Giant가 붙을 때까지 반복합니다."))

                mg.AddText("x20 y396 w820 h28 c" SubColor, "목표를 여러 개 켜면 하나라도 달성하면 종료합니다. 목표가 없으면 1라운드만 실행합니다.").SetFont("s8")

                global TreasureStatusText := mg.AddText("x480 y310 w370 h80 c" TextColor, "상태: 준비됨.`n보물섬 감정 창을 연 뒤 토글을 켜고 시작하세요.")

                TreasureAppraise.OnEvent("Click", SaveTreasureAppraiseEnabled)
                TreasureAutoTake.OnEvent("Click", SaveTreasureAppraiseAutoTake)
                TreasureGoalMult.OnEvent("Click", SaveTreasureGoalMultEnabled)
                TreasureGoalMultEdit.OnEvent("LoseFocus", SaveTreasureGoalMultValue)
                TreasureGoalTotal.OnEvent("Click", SaveTreasureGoalTotalEnabled)
                TreasureGoalTotalEdit.OnEvent("LoseFocus", SaveTreasureGoalTotalValue)
                TreasureGoalBigGiant.OnEvent("Click", SaveTreasureGoalBigGiantEnabled)

            case 4:
                mg.AddGroupBox("x10 y30 w860 h270 c" TextColor, "인챈트").SetFont("s9 bold")

                GamepassEnchant := mg.AddCheckbox("x20 y48 w20 h20")
                GamepassEnchant.Value := MAIN.Has("gamepass_enchant_enabled") ? MAIN["gamepass_enchant_enabled"] : 0
                mg.AddText("x40 y50 w150 h20 c" TextColor, "게임패스 인챈트 사용").SetFont("s9")
                GamepassEnchantHelp := mg.AddText("x190 y50 w40 h20 c" Accent, "설명")
                GamepassEnchantHelp.SetFont("underline")
                GamepassEnchantHelp.OnEvent("Click", (*) => InfoPopup.Show("게임패스 인챈트", "인밴토리를 열고 시작하면 게임패스 인챈트 버튼을 활용해 인챈트합니다.`nRelic을 들고 이 탭에서 매크로를 시작하세요."))

                SovereignEnchantCharge := mg.AddCheckbox("x250 y48 w20 h20")
                SovereignEnchantCharge.Value := MAIN.Has("sovereign_enchant_charge_enabled") ? MAIN["sovereign_enchant_charge_enabled"] : 0
                mg.AddText("x270 y50 w140 h20 c" TextColor, "군주 인챈트 충전").SetFont("s9")
                SovereignEnchantChargeHelp := mg.AddText("x415 y50 w40 h20 c" Accent, "설명")
                SovereignEnchantChargeHelp.SetFont("underline")
                SovereignEnchantChargeHelp.OnEvent("Click", (*) => InfoPopup.Show("군주 인챈트 충전", "Keeperbound(군주) 낚싯대 파워를 채울 때 켭니다.`n켜면 목표 인챈트 대신 Power가 100%로 충전 될 때까지 인챈트를 반복합니다.`n이미 100%면 바로 종료합니다.`nRelic을 들고 이 탭에서 매크로를 시작하세요."))
                Border(mg, 20, 71, 830, 1)

                mg.AddText("x20 y86 w100 h20 c" TextColor, "인챈트").SetFont("s10")
                enchantItems := GetDefaultEnchantList()
                savedEnchant := Trim(MAIN.Has("auto_enchant_name") ? MAIN["auto_enchant_name"] : "Hasty")
                enchantInList := false
                for item in enchantItems {
                    if (item = savedEnchant) {
                        enchantInList := true
                        break
                    }
                }
                AutoEnchantName := mg.AddDDL("x260 y85 w200 h100", enchantItems)
                if (enchantInList) {
                    try ControlChooseString(savedEnchant, AutoEnchantName)
                    catch
                        AutoEnchantName.Choose(1)
                } else {
                    AutoEnchantName.Choose(1)
                }

                AutoEnchantHelp := mg.AddText("x135 y88 h20 c" Accent, "설명")
                AutoEnchantHelp.SetFont("underline")
                AutoEnchantHelp.OnEvent("Click", (*) => InfoPopup.Show("인챈트", "목록에서 목표 인챈트를 고릅니다. 아래 직접 입력이 비어 있으면 선택된 값을 쓰고, 채워져 있으면 입력한 값을 씁니다.`nRelic을 들고 이 탭에서 매크로를 시작하세요."))

                mg.AddText("x20 y113 w100 h20 c" TextColor, "직접 입력").SetFont("s10")
                EnchantCustomEdit := mg.AddEdit("x260 y113 w200 h20", enchantInList ? "" : savedEnchant)

                global EnchantStatusText := mg.AddText("x480 y86 w370 h130 c" TextColor, "상태: 준비됨.`nRelic을 들고 이 탭에서 시작하면 인챈트 매크로가 실행됩니다.`n제단은 밤에만 활성화됩니다.")

                GamepassEnchant.OnEvent("Click", SaveGamepassEnchantEnabled)
                SovereignEnchantCharge.OnEvent("Click", SaveSovereignEnchantChargeEnabled)
                AutoEnchantName.OnEvent("Change", OnEnchantNameDdlChange)
                EnchantCustomEdit.OnEvent("LoseFocus", (*) => ResolveAndSaveEnchantTarget())
                EnchantCustomEdit.OnEvent("Change", (*) => ResolveAndSaveEnchantTarget())

            case 5:

                mg.AddGroupBox("x10 y25 w425 h250 c" TextColor, "자동 토템 · 시간/이벤트").SetFont("s9 bold")

                mg.AddText("x20 y45 w390 h18 c" TextColor, "시간").SetFont("s9 bold")
                TotemToggleAurora := mg.AddCheckbox("x20 y66 w20 h20")
                mg.AddText("x45 y67 w370 h18 c" TextColor, "Aurora Totem (밤)").SetFont("s9")
                TotemToggleTropical := mg.AddCheckbox("x20 y88 w20 h20")
                mg.AddText("x45 y89 w370 h18 c" TextColor, "Tropical Sun Totem (낮)").SetFont("s9")
                TotemToggleEclipse := mg.AddCheckbox("x20 y110 w20 h20")
                mg.AddText("x45 y111 w370 h18 c" TextColor, "Eclipse Totem (낮)").SetFont("s9")

                mg.AddText("x20 y138 w390 h18 c" TextColor, "이벤트").SetFont("s9 bold")
                TotemToggleShiny := mg.AddCheckbox("x20 y159 w20 h20")
                mg.AddText("x45 y160 w370 h18 c" TextColor, "Shiny Totem → Shiny Surge").SetFont("s9")
                TotemToggleSparkling := mg.AddCheckbox("x20 y181 w20 h20")
                mg.AddText("x45 y182 w370 h18 c" TextColor, "Sparkling Totem → Night of the Luminous").SetFont("s9")
                TotemToggleMutation := mg.AddCheckbox("x20 y203 w20 h20")
                mg.AddText("x45 y204 w370 h18 c" TextColor, "Mutation Totem → Mutation Surge").SetFont("s9")

                mg.AddText("x20 y232 w390 h28 c" TextColor, "타입별 1개씩: 시간 + 이벤트 + 날씨.").SetFont("s8")

                mg.AddGroupBox("x450 y25 w420 h250 c" TextColor, "자동 토템 · 날씨/실행").SetFont("s9 bold")

                mg.AddText("x465 y45 w390 h18 c" TextColor, "날씨").SetFont("s9 bold")
                TotemToggleClearcast := mg.AddCheckbox("x465 y66 w20 h20")
                mg.AddText("x490 y67 w360 h18 c" TextColor, "Clearcast Totem (맑음)").SetFont("s9")
                TotemToggleSmokescreen := mg.AddCheckbox("x465 y88 w20 h20")
                mg.AddText("x490 y89 w360 h18 c" TextColor, "Smokescreen Totem (안개)").SetFont("s9")
                TotemToggleTempest := mg.AddCheckbox("x465 y110 w20 h20")
                mg.AddText("x490 y111 w360 h18 c" TextColor, "Tempest Totem (비)").SetFont("s9")
                TotemToggleWindset := mg.AddCheckbox("x465 y132 w20 h20")
                mg.AddText("x490 y133 w360 h18 c" TextColor, "Windset Totem (바람)").SetFont("s9")

                Border(mg, 465, 160, 390, 1)

                mg.AddText("x465 y175 w80 h20 c" TextColor, "사용 모드").SetFont("s10")
                UseModeDdl := mg.AddDDL("x740 y175 w110 h100", ["만료 시", "간격"])
                UseModeHelp := mg.AddText("x650 y175 w60 h20 c" Accent, "설명")
                UseModeHelp.SetFont("underline")
                UseModeHelp.OnEvent("Click", (*) => InfoPopup.Show("사용 모드", "만료 시: 토템은 효과가 끝나면, 포션/Shell은 버프가 사라지면 다시 사용합니다. 간격: 설정한 초마다 사용을 시도합니다.`n같은 타입(시간/이벤트/날씨/Luck/Lure)은 동시에 하나만 켤 수 있습니다. Shell은 여러 개 가능합니다."))
                UseModeDdl.Choose(1)

                mg.AddText("x465 y205 w80 h20 c" TextColor, "간격 (초)").SetFont("s10")
                TotemInterval := mg.AddEdit("x740 y205 w110 h20", "15")
                TotemIntervalHelp := mg.AddText("x650 y205 w60 h20 c" Accent, "설명")
                TotemIntervalHelp.SetFont("underline")
                TotemIntervalHelp.OnEvent("Click", (*) => InfoPopup.Show("간격 (초)", "사용 모드가 간격일 때 토템/아이템을 다시 사용하기까지 기다리는 시간(초)입니다."))

                PublicServerEnabled := mg.AddCheckbox("x465 y235 h20 w20")
                mg.AddText("x485 y236 w80 h20 c" TextColor, "공개 서버").SetFont("s10")
                PublicServerHelp := mg.AddText("x575 y236 w50 h20 c" Accent, "설명")
                PublicServerHelp.SetFont("underline")
                PublicServerHelp.OnEvent("Click", (*) => InfoPopup.Show("공개 서버", "켜면 Starfall / Rainbow처럼 다른 유저 토템·이벤트가 걸린 날씨에서는 자동 토템을 잠시 멈춥니다. 개인 서버면 끌 수 있습니다."))

                mg.AddGroupBox("x10 y290 w860 h250 c" TextColor, "기타 아이템").SetFont("s9 bold")
                BuffItemHelp := mg.AddText("x820 y292 w40 h18 c" Accent, "설명")
                BuffItemHelp.SetFont("underline")
                BuffItemHelp.OnEvent("Click", (*) => InfoPopup.Show("기타 아이템", "핫바의 Luck/Lure 포션과 Shell을 자동 사용합니다.`nLuck·Lure는 티어 중 하나만, Shell은 여러 개 동시에 켤 수 있습니다.`n낚시 탭 상태창에 활성 버프가 표시됩니다. 자동 사용 on/off는 낚시 탭 '아이템 사용'입니다."))

                mg.AddText("x20 y315 w400 h18 c" TextColor, "Luck Potion").SetFont("s9 bold")
                BuffToggleLuck1 := mg.AddCheckbox("x20 y336 w20 h20")
                mg.AddText("x45 y337 w120 h18 c" TextColor, "Tier I").SetFont("s9")
                BuffToggleLuck2 := mg.AddCheckbox("x180 y336 w20 h20")
                mg.AddText("x205 y337 w120 h18 c" TextColor, "Tier II").SetFont("s9")
                BuffToggleLuck3 := mg.AddCheckbox("x340 y336 w20 h20")
                mg.AddText("x365 y337 w120 h18 c" TextColor, "Tier III").SetFont("s9")

                mg.AddText("x20 y365 w400 h18 c" TextColor, "Lure Speed Potion").SetFont("s9 bold")
                BuffToggleLure1 := mg.AddCheckbox("x20 y386 w20 h20")
                mg.AddText("x45 y387 w120 h18 c" TextColor, "Tier I").SetFont("s9")
                BuffToggleLure2 := mg.AddCheckbox("x180 y386 w20 h20")
                mg.AddText("x205 y387 w120 h18 c" TextColor, "Tier II").SetFont("s9")
                BuffToggleLure3 := mg.AddCheckbox("x340 y386 w20 h20")
                mg.AddText("x365 y387 w120 h18 c" TextColor, "Tier III").SetFont("s9")

                mg.AddText("x20 y415 w400 h18 c" TextColor, "Shell (여러 개 가능)").SetFont("s9 bold")
                BuffToggleShellDepth := mg.AddCheckbox("x20 y436 w20 h20")
                mg.AddText("x45 y437 w140 h18 c" TextColor, "Shell of Depth").SetFont("s9")
                BuffToggleShellEndurance := mg.AddCheckbox("x220 y436 w20 h20")
                mg.AddText("x245 y437 w160 h18 c" TextColor, "Shell of Endurance").SetFont("s9")
                BuffToggleShellFortune := mg.AddCheckbox("x450 y436 w20 h20")
                mg.AddText("x475 y437 w160 h18 c" TextColor, "Shell of Fortune").SetFont("s9")
                BuffToggleShellSwiftness := mg.AddCheckbox("x20 y458 w20 h20")
                mg.AddText("x45 y459 w160 h18 c" TextColor, "Shell of Swiftness").SetFont("s9")
                BuffToggleShellWrath := mg.AddCheckbox("x220 y458 w20 h20")
                mg.AddText("x245 y459 w160 h18 c" TextColor, "Shell of Wrath").SetFont("s9")

                mg.AddText("x20 y490 w820 h28 c" SubColor, "버프가 없으면(만료) 또는 간격마다 핫바에서 사용합니다. 낚시 탭 상태에 Luck/Lure/Shell이 표시됩니다.").SetFont("s8")

            case 6:
                global g_HuntCategoryId

                mg.AddGroupBox("x10 y25 w425 h500 c" TextColor, "헌트 감시 목록").SetFont("s9 bold")

                mg.AddText("x20 y48 w60 h20 c" TextColor, "분류").SetFont("s10")
                HuntCategoryDdl := mg.AddDDL("x70 y45 w200 h200", GetHuntCategoryLabels())
                catChoose := 1
                if (IsSet(g_HuntCategoryId) && g_HuntCategoryId != "") {
                    for i, def in GetHuntCategoryDefs() {
                        if (def["id"] = g_HuntCategoryId) {
                            catChoose := i
                            break
                        }
                    }
                }
                HuntCategoryDdl.Choose(catChoose)
                HuntCategoryHelp := mg.AddText("x280 y48 w40 h20 c" Accent, "설명")
                HuntCategoryHelp.SetFont("underline")
                HuntCategoryHelp.OnEvent("Click", (*) => InfoPopup.Show("분류", "카테고리를 고른 뒤 아래 목록에서 감시할 헌트를 체크하세요. 여러 개를 동시에 켤 수 있습니다."))

                HuntSelectAllBtn := mg.AddText("x340 y48 w40 h20 c" Accent, "전체")
                HuntSelectAllBtn.SetFont("s9 underline")
                HuntClearBtn := mg.AddText("x385 y48 w40 h20 c" Accent, "해제")
                HuntClearBtn.SetFont("s9 underline")

                HuntList := mg.AddListView("x20 y75 w395 h280 Checked -Multi -Hdr Background" BgColor " c" TextColor, ["헌트"])
                HuntList.ModifyCol(1, 360)

                HuntWatchCountText := mg.AddText("x20 y365 w395 h18 c" SubColor, "감시 중: 0")
                HuntWatchCountText.SetFont("s8")

                Border(mg, 20, 388, 395, 1)

                HuntDetectEnabled := mg.AddCheckbox("x20 y405 h20 w20")
                mg.AddText("x40 y406 w40 h20 c" TextColor, "사용").SetFont("s10")
                HuntDetectHelp := mg.AddText("x80 y406 w40 h20 c" Accent, "설명")
                HuntDetectHelp.SetFont("underline")
                HuntDetectHelp.OnEvent("Click", (*) => InfoPopup.Show("사용", "켜면 백그라운드에서 자동으로 감시합니다. 체크한 헌트가 뜨면 지금 검사 없이 바로 알립니다. 체크가 하나도 없으면 감지된 헌트 전부 알립니다."))

                HuntDetectSound := mg.AddCheckbox("x115 y405 h20 w20")
                mg.AddText("x135 y406 w35 h20 c" TextColor, "소리").SetFont("s10")
                HuntSoundHelp := mg.AddText("x168 y406 w30 h20 c" Accent, "설명")
                HuntSoundHelp.SetFont("underline")
                HuntSoundHelp.OnEvent("Click", (*) => InfoPopup.Show("소리", "헌트가 새로 감지되면 바로 비프음으로 알립니다."))

                HuntDetectNotify := mg.AddCheckbox("x205 y405 h20 w20")
                mg.AddText("x225 y406 w35 h20 c" TextColor, "알림").SetFont("s10")
                HuntNotifyHelp := mg.AddText("x258 y406 w30 h20 c" Accent, "설명")
                HuntNotifyHelp.SetFont("underline")
                HuntNotifyHelp.OnEvent("Click", (*) => InfoPopup.Show("알림", "헌트가 새로 감지되면 Windows 토스트 알림을 보냅니다."))

                HuntDetectWebhook := mg.AddCheckbox("x295 y405 h20 w20")
                mg.AddText("x315 y406 w40 h20 c" TextColor, "웹훅").SetFont("s10")
                HuntWebhookHelp := mg.AddText("x355 y406 w40 h20 c" Accent, "설명")
                HuntWebhookHelp.SetFont("underline")
                HuntWebhookHelp.OnEvent("Click", (*) => InfoPopup.Show("웹훅", "설정 탭의 Discord 웹훅이 켜져 있을 때, 선택한 헌트 감지를 즉시 전송합니다."))

                HuntRefreshBtn := mg.AddText("x20 y445 w100 h18 c" Accent, "지금 검사")
                HuntRefreshBtn.SetFont("s9 underline")
                HuntRefreshBtn.OnEvent("Click", RefreshHuntDetectNow)

                mg.AddGroupBox("x450 y25 w420 h500 c" TextColor, "감지된 헌트").SetFont("s9 bold")
                HuntActiveHelp := mg.AddText("x465 y48 w40 h16 c" Accent, "설명")
                HuntActiveHelp.SetFont("underline")
                HuntActiveHelp.OnEvent("Click", (*) => InfoPopup.Show("감지된 헌트", "서버 상단 배너 문구를 읽어 지금 떠 있는 헌트를 표시합니다.`n형식: [월.일 시:분] (헌트 이름)`n`n불완전한 기능입니다. 배너가 짧게 뜨거나 문구가 바뀌면 놓치거나, 잡은 뒤에도 잠시 남을 수 있습니다. 참고용으로만 쓰세요."))
                global HuntStatusText := mg.AddEdit("x465 y70 w390 h435 ReadOnly", FormatActiveHuntsDisplay())
                HuntStatusText.SetFont("s8")

            case 7:
                mg.AddGroupBox("x10 y25 w860 h220 c" TextColor, "기타").SetFont("s9 bold")

                mg.AddText("x20 y50 w820 h40 c" TextColor, "Humpback Whale Spawn").SetFont("s12 bold")
                mg.AddText("x20 y90 w820 h40 c" SubColor, "핫바의 Clearcast Totem ↔ Smokescreen Totem을 번갈아 사용해`nHumpback Whale Migration이 뜰 때까지 반복합니다.").SetFont("s9")

                HumpbackSpawnHelp := mg.AddText("x20 y140 w40 h20 c" Accent, "설명")
                HumpbackSpawnHelp.SetFont("underline")
                HumpbackSpawnHelp.OnEvent("Click", (*) => InfoPopup.Show("Humpback Whale Spawn", "핫바에 Clearcast Totem과 Smokescreen Totem이 있어야 합니다.`n버튼을 누르거나 이 탭에서 매크로 시작(F1)을 누르면 Clearcast → Smokescreen을 교차 사용합니다.`n배너/풀로 Humpback Whale Migration이 감지되면 자동 종료합니다.`n같은 키로 다시 누르면 중지합니다."))

                HumpbackSpawnBtn := button(mg, "Humpback Whale Spawn", 20, 170, {w: 220, h: 36, bg: BgColor, fontSize: 10})
                HumpbackSpawnBtn.OnEvent("Click", (*) => ToggleHumpbackSpawnFromGui())

                global HumpbackStatusText := mg.AddText("x260 y165 w580 h80 c" TextColor, "상태: 대기.`n핫바에 Clearcast / Smokescreen을 올린 뒤 시작하세요.")
                HumpbackStatusText.SetFont("s9")

            case 8:

                AccessabilityHeader:= mg.AddText("x10 y25 w400 h40 c" TextColor, "단축키")
                AccessabilityHeader.SetFont("s15")
                border(mg, 10, 60, 860, 1)

                StartMacroKey := mg.AddHotkey("x10 y80 w30 h20", SETTINGS["hotkeys"]["start_macro"])
                StartMacroKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("start_macro", ctrl))
                mg.AddText("x50 y79 w120 h20 c" TextColor, "매크로 시작").SetFont("s11")
                mg.AddText("x50 y100 w380 h36 c" SubColor, "열린 탭 기준: 감정/인챈트/기타 탭=해당 모드, 그 외=낚시")

                StopAppraiseKey := mg.AddHotkey("x10 y150 w30 h20", SETTINGS["hotkeys"].Has("stop_appraise") ? SETTINGS["hotkeys"]["stop_appraise"] : "F2")
                StopAppraiseKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("stop_appraise", ctrl))
                mg.AddText("x50 y149 w180 h20 c" TextColor, "감정/인챈트 중지").SetFont("s11")
                mg.AddText("x50 y170 w380 h36 c" SubColor, "진행 중인 감정·인챈트·기타 사이클을 중지합니다.")

                FixRbxKey := mg.AddHotkey("x450 y80 w30 h20", SETTINGS["hotkeys"]["fix_roblox"])
                FixRbxKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("fix_roblox", ctrl))
                mg.AddText("x490 y79 w120 h20 c" TextColor, "로블록스 복구").SetFont("s11")
                mg.AddText("x490 y100 w360 h36 c" SubColor, "낚싯대를 읽지 못할 때 사용하세요.")
                FixRbxHelpBtn := mg.AddText("x620 y82 w80 h20 c" Accent, "자세히")
                FixRbxHelpBtn.SetFont("s9 underline")
                FixRbxHelpBtn.OnEvent("Click", (*) => InfoPopup.Show("로블록스 복구", "실행 중인 로블록스에 XTernal을 다시 연결하고 메모리 오프셋을 다시 불러옵니다. 실행 중인 로블록스 버전이 최신과 다르면 오프셋이 맞지 않아 매크로가 오작동할 수 있습니다."))

                ReloadKey := mg.AddHotkey("x450 y150 w30 h20", SETTINGS["hotkeys"]["reload"])
                ReloadKey.OnEvent("Change", (ctrl, *) => UpdateHotkey("reload", ctrl))
                mg.AddText("x490 y149 w120 h20 c" TextColor, "새로고침").SetFont("s11")
                mg.AddText("x490 y170 w360 h36 c" SubColor, "매크로를 새로고침하는 단축키를 변경합니다.")

                OpenSettingsBtn := mg.AddText("x780 y27 w80 h16 c" Accent, "폴더 열기")
                OpenSettingsBtn.SetFont("underline")
                OpenSettingsBtn.OnEvent("Click", (*) => Run("explorer.exe `"" APPDATA_DIR "`""))

            case 9:

                mg.AddGroupBox("x10 y25 w425 h85 c" TextColor, "외관").SetFont("s9 bold")
                DarkModeToggle := mg.AddCheckbox("x20 y45 w20 h20")
                DarkModeToggle.Value := USERPREFS.Has("dark_mode") ? USERPREFS["dark_mode"] : 1
                mg.AddText("x45 y47 w200 h20 c" TextColor, "다크 모드").SetFont("s10")
                DarkModeToggle.OnEvent("Click", SaveDarkModeToggle)

                MinimizeOnMacroToggle := mg.AddCheckbox("x20 y70 w20 h20")
                MinimizeOnMacroToggle.Value := USERPREFS.Has("minimize_on_macro") ? USERPREFS["minimize_on_macro"] : 1
                mg.AddText("x45 y72 w360 h20 c" TextColor, "매크로 켜지면 앱 최소화").SetFont("s10")
                MinimizeOnMacroToggle.OnEvent("Click", SaveMinimizeOnMacroToggle)

                mg.AddGroupBox("x10 y125 w425 h95 c" TextColor, "웹훅").SetFont("s9 bold")

                WebhookUrlEdit := mg.AddEdit("x20 y145 w300 h20")
                TestWebhookBtn := button(mg, "테스트", 335, 143, {w: 80, h: 21, bg: BgColor, fontSize: 10})

                WebhookEnabled := mg.AddCheckbox("x20 y180 h20 w20")
                mg.AddText("x40 y182 w60 h20 c" TextColor, "사용").SetFont("s10")

                mg.AddText("x110 y182 w90 h20 c" TextColor, "간격 (분)").SetFont("s10")
                WebhookInterval := mg.AddEdit("x205 y183 w100 h20")

                SaveWebhookBtn := button(mg, "저장", 335, 180, {w: 80, h: 21, bg: BgColor, fontSize: 10})

                mg.AddGroupBox("x10 y235 w425 h70 c" TextColor, "알림").SetFont("s9 bold")

                AlertTotemFailedCb := mg.AddCheckbox("x20 y260 h20 w20")
                mg.AddText("x40 y261 w200 h20 c" TextColor, "자동 토템 실패").SetFont("s10")

                mg.AddGroupBox("x450 y25 w420 h280 c" TextColor, "요약").SetFont("s9 bold")

                SummaryFishCb := mg.AddCheckbox("x465 y50 h20 w20")
                mg.AddText("x485 y51 w160 h20 c" TextColor, "낚음/놓침").SetFont("s10")

                SummarySuccessRateCb := mg.AddCheckbox("x465 y80 h20 w20")
                mg.AddText("x485 y81 w160 h20 c" TextColor, "성공률").SetFont("s10")

                SummaryRodCb := mg.AddCheckbox("x465 y110 h20 w20")
                mg.AddText("x485 y111 w160 h20 c" TextColor, "낚싯대").SetFont("s10")

                SummaryConfigCb := mg.AddCheckbox("x465 y140 h20 w20")
                mg.AddText("x485 y141 w160 h20 c" TextColor, "활성 설정값").SetFont("s10")

                SummaryTotemStateCb := mg.AddCheckbox("x655 y50 h20 w20")
                mg.AddText("x675 y51 w180 h20 c" TextColor, "자동 토템 상태").SetFont("s10")

                SummaryTotemPopsCb := mg.AddCheckbox("x655 y80 h20 w20")
                mg.AddText("x675 y81 w180 h20 c" TextColor, "사용한 토템").SetFont("s10")

                SummarySessionTimeCb := mg.AddCheckbox("x655 y110 h20 w20")
                mg.AddText("x675 y111 w180 h20 c" TextColor, "세션 시간").SetFont("s10")

                SummaryCastTimeoutsCb := mg.AddCheckbox("x655 y140 h20 w20")
                mg.AddText("x675 y141 w180 h20 c" TextColor, "캐스트 타임아웃").SetFont("s10")

                TelemetryToggle := mg.AddCheckbox("x20 y490 w820 h20", "사용 통계 전송 (설치 ID·장치 해시·앱/OS 버전·오프셋 상태 → OpenMacro)")
                TelemetryToggle.Value := IsTelemetryEnabled() ? 1 : 0
                TelemetryToggle.OnEvent("Click", (ctrl, *) => SetTelemetryEnabled(ctrl.Value))

                mg.AddGroupBox("x10 y320 w860 h155 c" TextColor, "개발자 옵션").SetFont("s9 bold")
                mg.AddText("x20 y342 w820 h18 c" SubColor, "디버그용 GUI 덤프 / 낚시 PID 오버레이 / StellaWave 로그입니다.").SetFont("s8")
                EnchantDumpBtn := mg.AddText("x20 y370 w120 h18 c" Accent, "인챈트 GUI 덤프")
                EnchantDumpBtn.SetFont("s9 underline")
                EnchantDumpBtn.OnEvent("Click", DumpEnchantGuiDebug)
                HuntDumpBtn := mg.AddText("x150 y370 w110 h18 c" Accent, "헌트 GUI 덤프")
                HuntDumpBtn.SetFont("s9 underline")
                HuntDumpBtn.OnEvent("Click", DumpHuntGuiDebug)
                NpcDumpBtn := mg.AddText("x270 y370 w120 h18 c" Accent, "NPC 대화 덤프")
                NpcDumpBtn.SetFont("s9 underline")
                NpcDumpBtn.OnEvent("Click", DumpNpcDialogueDebug)
                MenuDumpBtn := mg.AddText("x400 y370 w130 h18 c" Accent, "설정/메뉴 창 덤프")
                MenuDumpBtn.SetFont("s9 underline")
                MenuDumpBtn.OnEvent("Click", DumpGameMenuGuiDebug)
                StellaDumpBtn := mg.AddText("x540 y370 w150 h18 c" Accent, "StellaWave 덤프")
                StellaDumpBtn.SetFont("s9 underline")
                StellaDumpBtn.OnEvent("Click", DumpStellaWaveMelodyDebug)
                HalibutDumpBtn := mg.AddText("x700 y370 w140 h18 c" Accent, "Halibut 덤프")
                HalibutDumpBtn.SetFont("s9 underline")
                HalibutDumpBtn.OnEvent("Click", DumpHalibutHarpoonDebug)
                mg.AddText("x20 y388 w820 h16 c" SubColor, "기믹이 보이는 동안 덤프. StellaWave=문양 / Halibut=느낌표(!) 경고.").SetFont("s8")

                ReelDebugCb := mg.AddCheckbox("x20 y415 h20 w20")
                ReelDebugCb.Value := USERPREFS.Has("reel_debug_enabled") ? USERPREFS["reel_debug_enabled"] : 0
                mg.AddText("x40 y416 w120 h20 c" TextColor, "낚시 PID 오버레이").SetFont("s9")
                ReelDebugLogCb := mg.AddCheckbox("x180 y415 h20 w20")
                ReelDebugLogCb.Value := USERPREFS.Has("reel_debug_log") ? USERPREFS["reel_debug_log"] : 0
                mg.AddText("x200 y416 w100 h20 c" TextColor, "파일 로그").SetFont("s9")
                ReelDebugOpenBtn := mg.AddText("x320 y416 w140 h18 c" Accent, "로그 폴더 열기")
                ReelDebugOpenBtn.SetFont("s9 underline")
                ReelDebugOpenBtn.OnEvent("Click", (*) => OpenReelDebugLogFolder())
                ReelDebugHelp := mg.AddText("x480 y416 w40 h18 c" Accent, "설명")
                ReelDebugHelp.SetFont("s9 underline")
                ReelDebugHelp.OnEvent("Click", (*) => InfoPopup.Show("낚시 PID 디버그",
                    "켜면 낚시 중 error / barVel / mode / duty / barWidth 등을 화면에 표시합니다.`n"
                    . "파일 로그를 켜면 %APPDATA%\OpenMacro\XTernal\reel-debug.log 에 기록합니다.`n"
                    . "먼 거리 불안정·존 휘청임 제보 시 이 수치를 같이 보내 주세요."))

                PersistReelDebugSettings(*) {
                    global USERPREFS, SETTINGS
                    USERPREFS["reel_debug_enabled"] := ReelDebugCb.Value ? 1 : 0
                    USERPREFS["reel_debug_log"] := ReelDebugLogCb.Value ? 1 : 0
                    SETTINGS["user"]["reel_debug_enabled"] := USERPREFS["reel_debug_enabled"]
                    SETTINGS["user"]["reel_debug_log"] := USERPREFS["reel_debug_log"]
                    SaveSettingsFile()
                    if (!USERPREFS["reel_debug_enabled"])
                        HideReelDebugOverlay()
                }
                ReelDebugCb.OnEvent("Click", PersistReelDebugSettings)
                ReelDebugLogCb.OnEvent("Click", PersistReelDebugSettings)

                StellarwaveLogCb := mg.AddCheckbox("x20 y440 h20 w20")
                StellarwaveLogCb.Value := USERPREFS.Has("stellarwave_log") ? USERPREFS["stellarwave_log"] : 0
                mg.AddText("x40 y441 w160 h20 c" TextColor, "StellaWave 파일 로그").SetFont("s9")
                StellarwaveLogOpenBtn := mg.AddText("x210 y441 w140 h18 c" Accent, "로그 폴더 열기")
                StellarwaveLogOpenBtn.SetFont("s9 underline")
                StellarwaveLogOpenBtn.OnEvent("Click", (*) => OpenStellarwaveLogFolder())
                StellarwaveLogHelp := mg.AddText("x360 y441 w40 h18 c" Accent, "설명")
                StellarwaveLogHelp.SetFont("s9 underline")
                StellarwaveLogHelp.OnEvent("Click", (*) => InfoPopup.Show("StellaWave 로그",
                    "켜면 기믹 시작/종료, 서클 완료·시작, 문양 클릭, 맵/버튼 누락을`n"
                    . "%APPDATA%\OpenMacro\XTernal\stellarwave.log 에 기록합니다.`n"
                    . "클릭이 씹히거나 서클이 멈출 때 이 로그를 같이 보내 주세요."))

                PersistStellarwaveLogSettings(*) {
                    global USERPREFS, SETTINGS
                    USERPREFS["stellarwave_log"] := StellarwaveLogCb.Value ? 1 : 0
                    SETTINGS["user"]["stellarwave_log"] := USERPREFS["stellarwave_log"]
                    SaveSettingsFile()
                }
                StellarwaveLogCb.OnEvent("Click", PersistStellarwaveLogSettings)

            case 10:

                mg.AddText("x10 y25 w860 h25 c" TextColor, APP_NAME).SetFont("s12 bold")
                mg.AddText("x10 y50 w860 h18 c" SubColor, FULL_VER "  ·  XTernal " UPSTREAM_VER " 기반").SetFont("s9")

                mg.AddGroupBox("x10 y75 w425 h185 c" TextColor, "편집자").SetFont("s9 bold")
                mg.AddText("x20 y95 w400 h20 c" TextColor, "하나노 히카리 (Discord: @1004hikari)").SetFont("s10")
                mg.AddText("x20 y115 w400 h18 c" SubColor, "이 포크의 UI·기능 수정 및 개인화").SetFont("s8")
                DiffLogBtn := button(mg, "XTernal과 다른 점", 20, 140, {w: 180, h: 28, bg: BgColor, fontSize: 9})
                DiffLogBtn.OnEvent("Click", (*) => InfoPopup.ShowLog("업데이트 로그", GetHikariUpdateLog()))
                mg.AddText("x20 y178 w400 h18 c" SubColor, "프로그램에 피드백을 남기고 업데이트를 받으세요.").SetFont("s8")
                HikariDiscordLink := mg.AddText("x20 y198 w400 h18 c" Accent, "Discord — https://discord.gg/KzgDYMAVxw")
                HikariDiscordLink.SetFont("s8 underline")
                HikariDiscordLink.OnEvent("Click", (*) => Run("https://discord.gg/KzgDYMAVxw"))

                mg.AddGroupBox("x450 y75 w420 h185 c" TextColor, "원작자").SetFont("s9 bold")
                mg.AddText("x465 y95 w390 h18 c" TextColor, "OpenMacro XTernal").SetFont("s10 bold")
                mg.AddText("x465 y120 w390 h18 c" TextColor, "Designed & developed by Misery (@termx3)").SetFont("s9")
                mg.AddText("x465 y142 w390 h18 c" TextColor, "Maintained by Shinkting (@Invermatic1)").SetFont("s9")
                mg.AddText("x465 y164 w390 h18 c" SubColor, "Copyright © 2026 (@anorexc)").SetFont("s8")
                mg.AddText("x465 y182 w390 h18 c" SubColor, "https://github.com/termx3/OpenMacro-XTernal").SetFont("s8")

                mg.AddGroupBox("x10 y275 w860 h230 c" TextColor, "라이선스 고지").SetFont("s9 bold")
                LegalNotice := "GNU Affero General Public License, version 3.0 only (AGPL-3.0-only)`n`n"
                    . "이 프로그램은 어떠한 보증도 제공하지 않습니다. 자유 소프트웨어이며 AGPL-3.0 조건에 따라 재배포할 수 있습니다.`n`n"
                    . "재배포·배포·네트워크를 통한 사용 시 저작권·라이선스·원작 고지를 유지하고, AGPL-3.0에 따라 완전한 대응 소스를 제공해야 합니다.`n`n"
                    . "library/ 폴더의 서드파티 구성 요소는 각 저작권자의 소유이며 각각의 라이선스가 적용됩니다.`n`n"
                    . "자세한 내용은 프로젝트 루트의 LICENSE, NOTICE 파일을 확인하세요."
                mg.AddText("x20 y295 w820 h130 c" SubColor, LegalNotice).SetFont("s8")

                CreditsLicenseLink := mg.AddText("x20 y440 w200 h18 c" Accent, "AGPL-3.0 전문 보기")
                CreditsLicenseLink.SetFont("underline")
                CreditsLicenseLink.OnEvent("Click", (*) => Run("https://www.gnu.org/licenses/agpl-3.0.txt"))

                CreditsLocalLicense := mg.AddText("x240 y440 w160 h18 c" Accent, "LICENSE 파일 열기")
                CreditsLocalLicense.SetFont("underline")
                CreditsLocalLicense.OnEvent("Click", (*) => Run(A_ScriptDir "\LICENSE"))

                CreditsLocalNotice := mg.AddText("x420 y440 w160 h18 c" Accent, "NOTICE 파일 열기")
                CreditsLocalNotice.SetFont("underline")
                CreditsLocalNotice.OnEvent("Click", (*) => Run(A_ScriptDir "\NOTICE"))

                CreditsWebLink := mg.AddText("x20 y465 w140 h18 c" Accent, "공식 웹사이트")
                CreditsWebLink.SetFont("underline")
                CreditsWebLink.OnEvent("Click", (*) => Run("https://openmacro.net"))

                CreditsDiscordLink := mg.AddText("x180 y465 w140 h18 c" Accent, "공식 Discord")
                CreditsDiscordLink.SetFont("underline")
                CreditsDiscordLink.OnEvent("Click", (*) => Run("https://discord.gg/openmacro"))

        }
        FinishLazyTab(idx)

        list := []
        for ctrl in mg {
            try {
                hwnd := ctrl.Hwnd
                if !existing.Has(hwnd)
                    list.Push(hwnd)
            } catch {
            }
        }
        g_TabCtrls[idx] := list
    }

    ApplyMacroCastMode(showPopup := false, *) {
        switch CastMode.Text {
            case "퍼펙트":
                CastPowerThreshold.Value := "96%"
                CastPowerThreshold.Enabled := false
                if (showPopup)
                    InfoPopup.Show("퍼펙트 캐스트 주의", "피쉬에는 캐스트 파워가 11%를 넘으면 캐스트마다 캐릭터가 조금씩 움직이는 버그가 있어, 퍼펙트 캐스트로 오래 돌리면 물에 빠질 수 있습니다.")
            case "숏":
                CastPowerThreshold.Value := "1%"
                CastPowerThreshold.Enabled := false
            case "사용자 지정":
                CastPowerThreshold.Value := MAIN["cast_power_custom"] "%"
                CastPowerThreshold.Enabled := true
        }
    }

    LoadMacroTabFields() {
        global MAIN
        switch MAIN["cast_mode"] {
            case "short":  CastMode.Choose(2)
            case "custom": CastMode.Choose(3)
            default:       CastMode.Choose(1)
        }
        ApplyMacroCastMode()
        if (MAIN["cast_mode"] = "custom")
            CastPowerThreshold.Value := MAIN["cast_power_custom"] "%"

        CastTimeout.Value := MAIN["cast_timeout_ms"] / 1000
        PreCastDelay.Value := MAIN["pre_cast_delay_ms"]
        PostCastDelay.Value := MAIN["post_cast_delay_ms"]
        CastOnTimeout.Value := MAIN["cast_on_timeout"]

        FishingActionDelay.Value := MAIN["fishing_action_delay_ms"]
        CompletionThreshold.Value := Format("{:.1f}", MAIN["completion_threshold"]) "%"
        ShakeInterval.Value := MAIN["shake_interval_ms"]
        if (IsSet(WindowUseEnabled) && WindowUseEnabled)
            WindowUseEnabled.Value := MAIN.Has("window_use_enabled") ? MAIN["window_use_enabled"] : 0
    }

    SaveMacroCastSettings(*) {
        global MAIN, SETTINGS, USERPREFS
        modeMap := Map(1, "perfect", 2, "short", 3, "custom")
        MAIN["cast_mode"] := modeMap[CastMode.Value]
        SETTINGS["main"]["cast_mode"] := MAIN["cast_mode"]

        if (CastMode.Text = "사용자 지정") {
            raw := RegExReplace(CastPowerThreshold.Value, "%")
            if (IsNumber(raw)) {
                v := Max(1.0, Min(100.0, raw + 0.0))
                MAIN["cast_power_custom"] := v
                SETTINGS["main"]["cast_power_custom"] := v
            }
        }

        raw := Trim(CastTimeout.Value)
        if (IsNumber(raw) && raw + 0 >= 0) {
            v := Max(GetMinCastTimeoutMs(), Round(raw * 1000))
            MAIN["cast_timeout_ms"] := v
            SETTINGS["main"]["cast_timeout_ms"] := v
        }

        for key, ctrl in Map(
            "pre_cast_delay_ms", PreCastDelay,
            "post_cast_delay_ms", PostCastDelay)
        {
            raw := Trim(ctrl.Value)
            if (IsInteger(raw) && raw + 0 >= 0) {
                MAIN[key] := raw + 0
                SETTINGS["main"][key] := raw + 0
            }
        }

        MAIN["cast_on_timeout"] := CastOnTimeout.Value
        SETTINGS["main"]["cast_on_timeout"] := CastOnTimeout.Value

        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        LoadMacroTabFields()
        SaveCastBtn.ctrl.Value := "저장됨!"
        SetTimer(() => (SaveCastBtn.ctrl.Value := "저장"), -1500)
    }

    SaveMacroFishSettings(*) {
        global MAIN, SETTINGS
        for key, ctrl in Map(
            "fishing_action_delay_ms", FishingActionDelay,
            "shake_interval_ms", ShakeInterval)
        {
            raw := Trim(ctrl.Value)
            if (IsInteger(raw) && raw + 0 >= 0) {
                MAIN[key] := raw + 0
                SETTINGS["main"][key] := raw + 0
            }
        }

        raw := Trim(RegExReplace(CompletionThreshold.Value, "%"))
        if (IsNumber(raw)) {
            v := Max(0.0, Min(100.0, raw + 0.0))
            MAIN["completion_threshold"] := v
            SETTINGS["main"]["completion_threshold"] := v
        }

        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        LoadMacroTabFields()
        SaveFishBtn.ctrl.Value := "저장됨!"
        SetTimer(() => (SaveFishBtn.ctrl.Value := "저장"), -1500)
    }

    CastMode.OnEvent("Change", (*) => ApplyMacroCastMode(true))
    SaveCastBtn.OnEvent("Click", SaveMacroCastSettings)
    SaveFishBtn.OnEvent("Click", SaveMacroFishSettings)
    LoadMacroTabFields()

    ApplyUseMode(*) {
        if !(IsSet(TotemInterval) && TotemInterval && IsSet(UseModeDdl) && UseModeDdl)
            return
        TotemInterval.Enabled := (UseModeDdl.Value = 2)
    }

    PersistTotemSettings(*) {
        global MAIN, SETTINGS

        MAIN["auto_totem_enabled"] := AutoTotemEnabled.Value ? 1 : 0
        SETTINGS["main"]["auto_totem_enabled"] := MAIN["auto_totem_enabled"]

        ; 아이템 탭이 아직 안 만들어졌으면 토글만 저장
        if (IsSet(PublicServerEnabled) && PublicServerEnabled) {
            MAIN["public_server_enabled"] := PublicServerEnabled.Value ? 1 : 0
            SETTINGS["main"]["public_server_enabled"] := MAIN["public_server_enabled"]
        }
        if (IsSet(UseModeDdl) && UseModeDdl) {
            MAIN["auto_totem_mode"] := (UseModeDdl.Value = 2) ? "interval" : "expire"
            SETTINGS["main"]["auto_totem_mode"] := MAIN["auto_totem_mode"]
        }
        if (IsSet(TotemInterval) && TotemInterval) {
            rawInterval := Trim(TotemInterval.Value)
            previousInterval := MAIN["auto_totem_interval_sec"]
            if RegExMatch(rawInterval, "^\d+$") && (rawInterval + 0) >= 1 {
                MAIN["auto_totem_interval_sec"] := rawInterval + 0
                SETTINGS["main"]["auto_totem_interval_sec"] := MAIN["auto_totem_interval_sec"]
            } else {
                TotemInterval.Value := previousInterval
            }
        }

        EnsureAutoTotemToggles()
        SETTINGS["main"]["auto_totem_toggles"] := MAIN["auto_totem_toggles"]
        SETTINGS["main"]["auto_totem_name"] := MAIN["auto_totem_name"]
        EnsureBuffItemToggles()
        SETTINGS["main"]["auto_buff_item_toggles"] := MAIN["auto_buff_item_toggles"]

        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        UpdateAutoTotemSelectionUi()
    }

    AutoTotemEnabled.OnEvent("Click", PersistTotemSettings)
    AutoSovereignEnchantCharge.OnEvent("Click", SaveAutoSovereignEnchantChargeEnabled)

    PersistWindowUseEnabled(*) {
        global MAIN, SETTINGS, Macro
        if !(IsSet(WindowUseEnabled) && WindowUseEnabled)
            return
        on := WindowUseEnabled.Value ? 1 : 0
        MAIN["window_use_enabled"] := on
        if (SETTINGS.Has("main"))
            SETTINGS["main"]["window_use_enabled"] := on
        if (on) {
            MAIN["harpoon_use_enabled"] := 0
            if (SETTINGS.Has("main"))
                SETTINGS["main"]["harpoon_use_enabled"] := 0
            if (IsSet(HarpoonUseEnabled) && HarpoonUseEnabled)
                HarpoonUseEnabled.Value := 0
            try StopHarpoonMacro(false)
            catch {
            }
        } else {
            ; Force-stop clicker even if phase was already cleared.
            try StopWindowUseClicker()
            catch {
            }
            try StopWindowUseMacro()
            catch {
            }
        }
        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        UpdateWindowHarpoonStatusUi()
    }

    PersistHarpoonUseEnabled(*) {
        global MAIN, SETTINGS
        if !(IsSet(HarpoonUseEnabled) && HarpoonUseEnabled)
            return
        on := HarpoonUseEnabled.Value ? 1 : 0
        MAIN["harpoon_use_enabled"] := on
        if (SETTINGS.Has("main"))
            SETTINGS["main"]["harpoon_use_enabled"] := on
        if (on) {
            MAIN["window_use_enabled"] := 0
            if (SETTINGS.Has("main"))
                SETTINGS["main"]["window_use_enabled"] := 0
            if (IsSet(WindowUseEnabled) && WindowUseEnabled)
                WindowUseEnabled.Value := 0
            StopWindowUseMacro()
        }
        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        if (!on) {
            try StopHarpoonMacro(false)
            catch {
            }
        }
        UpdateWindowHarpoonStatusUi()
    }

    LoadAdvFields() {
        global MAIN, WEBHOOK
        if (IsSet(UseModeDdl) && UseModeDdl) {
            EnsureAutoTotemToggles()
            AutoTotemEnabled.Value := MAIN["auto_totem_enabled"]
            PublicServerEnabled.Value := MAIN["public_server_enabled"]
            UseModeDdl.Choose(MAIN["auto_totem_mode"] = "interval" ? 2 : 1)
            TotemInterval.Value := MAIN["auto_totem_interval_sec"]
            SyncTotemToggleUi()
            SyncBuffItemToggleUi()
            UpdateAutoTotemSelectionUi()
            ApplyUseMode()
            UpdateBuffStatusUi(true)
        }
        if (IsSet(HuntDetectEnabled) && HuntDetectEnabled) {
            EnsureHuntDetectToggles()
            HuntDetectEnabled.Value := MAIN["hunt_detect_enabled"]
            HuntDetectSound.Value := MAIN["hunt_detect_sound"]
            HuntDetectNotify.Value := MAIN.Has("hunt_detect_notify") ? MAIN["hunt_detect_notify"] : 1
            HuntDetectWebhook.Value := MAIN["hunt_detect_webhook"]
            ReloadHuntListView()
            UpdateHuntWatchCount()
            UpdateHuntStatusUi()
        }
        if (IsSet(WebhookUrlEdit) && WebhookUrlEdit) {
            WebhookUrlEdit.Value := WEBHOOK["webhook_url"]
            WebhookEnabled.Value := WEBHOOK["webhook_enabled"]
            WebhookInterval.Value := WEBHOOK["webhook_summary_interval_min"]
            SummaryFishCb.Value := WEBHOOK["webhook_summary_fish"]
            SummarySuccessRateCb.Value := WEBHOOK["webhook_summary_success_rate"]
            SummaryRodCb.Value := WEBHOOK["webhook_summary_rod"]
            SummaryConfigCb.Value := WEBHOOK["webhook_summary_config"]
            SummaryTotemStateCb.Value := WEBHOOK["webhook_summary_totem_state"]
            SummaryTotemPopsCb.Value := WEBHOOK["webhook_summary_totem_pops"]
            SummarySessionTimeCb.Value := WEBHOOK["webhook_summary_session_time"]
            SummaryCastTimeoutsCb.Value := WEBHOOK["webhook_summary_cast_timeouts"]
            AlertTotemFailedCb.Value := WEBHOOK["webhook_alert_totem_failed"]
        }
    }


    TotemToggleControls := unset
    BuffItemToggleControls := unset

    FinishLazyTab(idx) {
        switch idx {
            case 5:
                TotemToggleControls := Map(
                    "Aurora Totem", TotemToggleAurora,
                    "Tropical Sun Totem", TotemToggleTropical,
                    "Eclipse Totem", TotemToggleEclipse,
                    "Shiny Totem", TotemToggleShiny,
                    "Sparkling Totem", TotemToggleSparkling,
                    "Mutation Totem", TotemToggleMutation,
                    "Clearcast Totem", TotemToggleClearcast,
                    "Smokescreen Totem", TotemToggleSmokescreen,
                    "Tempest Totem", TotemToggleTempest,
                    "Windset Totem", TotemToggleWindset
                )
                BuffItemToggleControls := Map(
                    "Luck Potion I", BuffToggleLuck1,
                    "Luck Potion II", BuffToggleLuck2,
                    "Luck Potion III", BuffToggleLuck3,
                    "Lure Speed Potion I", BuffToggleLure1,
                    "Lure Speed Potion II", BuffToggleLure2,
                    "Lure Speed Potion III", BuffToggleLure3,
                    "Shell of Depth", BuffToggleShellDepth,
                    "Shell of Endurance", BuffToggleShellEndurance,
                    "Shell of Fortune", BuffToggleShellFortune,
                    "Shell of Swiftness", BuffToggleShellSwiftness,
                    "Shell of Wrath", BuffToggleShellWrath
                )
                for name, ctrl in TotemToggleControls
                    ctrl.OnEvent("Click", OnTotemToggleClick.Bind(name))
                for name, ctrl in BuffItemToggleControls
                    ctrl.OnEvent("Click", OnBuffItemToggleClick.Bind(name))
                UseModeDdl.OnEvent("Change", (*) => (ApplyUseMode(), PersistTotemSettings()))
                TotemInterval.OnEvent("LoseFocus", PersistTotemSettings)
                PublicServerEnabled.OnEvent("Click", PersistTotemSettings)
                ; load totem/buff fields only
                global MAIN
                EnsureAutoTotemToggles()
                AutoTotemEnabled.Value := MAIN["auto_totem_enabled"]
                PublicServerEnabled.Value := MAIN["public_server_enabled"]
                UseModeDdl.Choose(MAIN["auto_totem_mode"] = "interval" ? 2 : 1)
                TotemInterval.Value := MAIN["auto_totem_interval_sec"]
                SyncTotemToggleUi()
                SyncBuffItemToggleUi()
                UpdateAutoTotemSelectionUi()
                ApplyUseMode()
                UpdateBuffStatusUi(true)
            case 6:
                global MAIN
                EnsureHuntDetectToggles()
                HuntDetectEnabled.Value := MAIN["hunt_detect_enabled"]
                HuntDetectSound.Value := MAIN["hunt_detect_sound"]
                HuntDetectNotify.Value := MAIN.Has("hunt_detect_notify") ? MAIN["hunt_detect_notify"] : 1
                HuntDetectWebhook.Value := MAIN["hunt_detect_webhook"]
                ReloadHuntListView()
                UpdateHuntWatchCount()
                UpdateHuntStatusUi()
                HuntDetectEnabled.OnEvent("Click", PersistHuntSettings)
                HuntDetectSound.OnEvent("Click", PersistHuntSettings)
                HuntDetectNotify.OnEvent("Click", PersistHuntSettings)
                HuntDetectWebhook.OnEvent("Click", PersistHuntSettings)
                ; Change 직후 Value가 예전 인덱스일 수 있어 한 틱 뒤에 목록 갱신
                HuntCategoryDdl.OnEvent("Change", OnHuntCategoryChange)
                HuntList.OnEvent("ItemCheck", OnHuntListItemCheck)
                HuntSelectAllBtn.OnEvent("Click", (*) => SetCategoryHuntChecks(1))
                HuntClearBtn.OnEvent("Click", (*) => SetCategoryHuntChecks(0))
            case 9:
                global WEBHOOK
                WebhookUrlEdit.Value := WEBHOOK["webhook_url"]
                WebhookEnabled.Value := WEBHOOK["webhook_enabled"]
                WebhookInterval.Value := WEBHOOK["webhook_summary_interval_min"]
                SummaryFishCb.Value := WEBHOOK["webhook_summary_fish"]
                SummarySuccessRateCb.Value := WEBHOOK["webhook_summary_success_rate"]
                SummaryRodCb.Value := WEBHOOK["webhook_summary_rod"]
                SummaryConfigCb.Value := WEBHOOK["webhook_summary_config"]
                SummaryTotemStateCb.Value := WEBHOOK["webhook_summary_totem_state"]
                SummaryTotemPopsCb.Value := WEBHOOK["webhook_summary_totem_pops"]
                SummarySessionTimeCb.Value := WEBHOOK["webhook_summary_session_time"]
                SummaryCastTimeoutsCb.Value := WEBHOOK["webhook_summary_cast_timeouts"]
                AlertTotemFailedCb.Value := WEBHOOK["webhook_alert_totem_failed"]
                TestWebhookBtn.OnEvent("Click", SendTestWebhook)
                SaveWebhookBtn.OnEvent("Click", SaveWebhookSettings)
                SummaryFishCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_fish", ctrl.Value))
                SummarySuccessRateCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_success_rate", ctrl.Value))
                SummaryRodCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_rod", ctrl.Value))
                SummaryConfigCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_config", ctrl.Value))
                SummaryTotemStateCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_totem_state", ctrl.Value))
                SummaryTotemPopsCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_totem_pops", ctrl.Value))
                SummarySessionTimeCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_session_time", ctrl.Value))
                SummaryCastTimeoutsCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_summary_cast_timeouts", ctrl.Value))
                AlertTotemFailedCb.OnEvent("Click", (ctrl, *) => PersistWebhookFlag("webhook_alert_totem_failed", ctrl.Value))
        }
    }

    SyncTotemToggleUi(*) {
        global MAIN
        if !(IsSet(TotemToggleControls) && TotemToggleControls)
            return
        EnsureAutoTotemToggles()
        for name, ctrl in TotemToggleControls
            ctrl.Value := MAIN["auto_totem_toggles"].Has(name) && MAIN["auto_totem_toggles"][name] ? 1 : 0
        UpdateAutoTotemSelectionUi()
    }

    SyncBuffItemToggleUi(*) {
        global MAIN
        if !(IsSet(BuffItemToggleControls) && BuffItemToggleControls)
            return
        EnsureBuffItemToggles()
        for name, ctrl in BuffItemToggleControls
            ctrl.Value := MAIN["auto_buff_item_toggles"].Has(name) && MAIN["auto_buff_item_toggles"][name] ? 1 : 0
        UpdateAutoTotemSelectionUi()
    }

    OnTotemToggleClick(totemName, ctrl, *) {
        SetAutoTotemToggle(totemName, ctrl.Value)
        SyncTotemToggleUi()
        PersistTotemSettings()
    }

    OnBuffItemToggleClick(itemName, ctrl, *) {
        SetBuffItemToggle(itemName, ctrl.Value)
        SyncBuffItemToggleUi()
        PersistTotemSettings()
    }

    global g_HuntListRowKeys := []
    global g_HuntListSyncing := false

    UpdateHuntWatchCount(*) {
        global MAIN
        if !(IsSet(HuntWatchCountText) && HuntWatchCountText)
            return
        EnsureHuntDetectToggles()
        n := GetEnabledWatchHunts().Length
        HuntWatchCountText.Value := "감시 중: " n "개"
    }

    EnsureGuiRedrawReady(*) {
        global g_GuiSizing, g_DragDetached, g_MainGuiHwnd
        if ((IsSet(g_DragDetached) && g_DragDetached) || (IsSet(g_GuiSizing) && g_GuiSizing)) {
            g_GuiSizing := false
            try DetachGuiChildrenForDrag(false)
            catch {
            }
        }
        if (IsSet(g_MainGuiHwnd) && g_MainGuiHwnd) {
            DllCall("SendMessage", "ptr", g_MainGuiHwnd, "uint", 0x000B, "ptr", 1, "ptr", 0) ; WM_SETREDRAW TRUE
        }
    }

    ReloadHuntListView(*) {
        global MAIN, g_HuntListRowKeys, g_HuntListSyncing
        if !(IsSet(HuntList) && HuntList && IsSet(HuntCategoryDdl) && HuntCategoryDdl)
            return
        EnsureGuiRedrawReady()
        EnsureHuntDetectToggles()
        g_HuntListSyncing := true
        lvHwnd := 0
        try lvHwnd := HuntList.Hwnd
        catch {
        }
        if (lvHwnd)
            DllCall("SendMessage", "ptr", lvHwnd, "uint", 0x000B, "ptr", 0, "ptr", 0) ; WM_SETREDRAW FALSE
        try {
            HuntList.Delete()
            g_HuntListRowKeys := []
            catId := ResolveHuntCategoryIdFromDdl(HuntCategoryDdl)
            for entry in GetHuntsByCategory(catId) {
                checked := MAIN["hunt_detect_toggles"].Has(entry["key"]) && MAIN["hunt_detect_toggles"][entry["key"]]
                opts := checked ? "Check" : ""
                HuntList.Add(opts, entry["label"])
                g_HuntListRowKeys.Push(entry["key"])
            }
            try HuntList.ModifyCol(1, 360)
            catch {
            }
        } finally {
            if (lvHwnd) {
                DllCall("SendMessage", "ptr", lvHwnd, "uint", 0x000B, "ptr", 1, "ptr", 0)
                DllCall("InvalidateRect", "ptr", lvHwnd, "ptr", 0, "int", 1)
                DllCall("UpdateWindow", "ptr", lvHwnd)
            }
            SetTimer(() => (g_HuntListSyncing := false), -50)
        }
        UpdateHuntWatchCount()
    }

    OnHuntCategoryChange(*) {
        global g_HuntCategoryId
        try g_HuntCategoryId := ResolveHuntCategoryIdFromDdl(HuntCategoryDdl)
        catch {
        }
        ; DDL 선택이 커밋된 뒤 목록을 채움 (같은 메시지에서 Value가 늦는 경우 방지)
        SetTimer(ReloadHuntListView, -1)
    }

    PersistHuntSettings(doPulse := true, *) {
        global MAIN, SETTINGS

        ; OnEvent("Click")는 doPulse 자리에 컨트롤을 넘김 → 객체면 기본(true)로 처리
        if (doPulse is Object)
            doPulse := true

        if !(IsSet(HuntDetectEnabled) && HuntDetectEnabled)
            return

        MAIN["hunt_detect_enabled"] := HuntDetectEnabled.Value ? 1 : 0
        SETTINGS["main"]["hunt_detect_enabled"] := MAIN["hunt_detect_enabled"]
        MAIN["hunt_detect_sound"] := HuntDetectSound.Value ? 1 : 0
        SETTINGS["main"]["hunt_detect_sound"] := MAIN["hunt_detect_sound"]
        MAIN["hunt_detect_notify"] := HuntDetectNotify.Value ? 1 : 0
        SETTINGS["main"]["hunt_detect_notify"] := MAIN["hunt_detect_notify"]
        MAIN["hunt_detect_webhook"] := HuntDetectWebhook.Value ? 1 : 0
        SETTINGS["main"]["hunt_detect_webhook"] := MAIN["hunt_detect_webhook"]

        EnsureHuntDetectToggles()
        SETTINGS["main"]["hunt_detect_toggles"] := MAIN["hunt_detect_toggles"]

        SaveSettingsFile()
        if (SETTINGS["last_config"] != "" && FileExist(CONFIGS_DIR "\" SETTINGS["last_config"] ".json"))
            SaveConfig(SETTINGS["last_config"])
        UpdateHuntWatchCount()

        ; 사용/소리 켠 직후 — 이미 떠 있는 헌트도 바로 울리게
        if (doPulse && MAIN["hunt_detect_enabled"])
            PulseHuntDetectAlerts()
    }

    OnHuntListItemCheck(ctrl, row, checked) {
        global g_HuntListRowKeys, g_HuntListSyncing, MAIN
        if (g_HuntListSyncing)
            return
        if (row < 1 || row > g_HuntListRowKeys.Length)
            return
        key := g_HuntListRowKeys[row]
        SetHuntDetectToggle(key, checked ? 1 : 0)
        PersistHuntSettings(false)
        if (checked && MAIN["hunt_detect_enabled"])
            PulseHuntDetectAlerts([key])
    }

    SetCategoryHuntChecks(enabled) {
        global MAIN, g_HuntListSyncing
        EnsureHuntDetectToggles()
        catId := ResolveHuntCategoryIdFromDdl(HuntCategoryDdl)
        forceKeys := []
        for entry in GetHuntsByCategory(catId) {
            MAIN["hunt_detect_toggles"][entry["key"]] := enabled ? 1 : 0
            if (enabled)
                forceKeys.Push(entry["key"])
        }
        ReloadHuntListView()
        PersistHuntSettings(false)
        if (enabled && MAIN["hunt_detect_enabled"])
            PulseHuntDetectAlerts(forceKeys)
    }

    ; HuntCategory/List/Detect OnEvent → FinishLazyTab(6)

    SendTestWebhook(*) {
        url := Trim(WebhookUrlEdit.Value)
        if (url = "") {
            MsgBox("먼저 웹훅 URL을 입력하세요.", "웹훅")
            return
        }
        try {
            payload := '{"flags":32768,"components":[{"type":17,"accent_color":5763719,"components":[{"type":10,"content":"## 웹훅 테스트\n웹훅이 올바르게 설정되었습니다."}]}]}'
            wr := ComObject("WinHttp.WinHttpRequest.5.1")
            wr.Open("POST", url "?with_components=true", false)
            wr.SetRequestHeader("Content-Type", "application/json")
            wr.Send(payload)
            status := wr.Status
            if (status < 200 || status >= 300)
                throw Error("HTTP " status ": " wr.ResponseText)
            TestWebhookBtn.ctrl.Value := "전송됨!"
            SetTimer(() => (TestWebhookBtn.ctrl.Value := "테스트"), -1500)
        } catch as err {
            MsgBox("전송 실패: " err.Message, "웹훅 오류")
        }
    }

    SaveWebhookSettings(*) {
        global WEBHOOK
        rawInterval := Trim(WebhookInterval.Value)
        if !RegExMatch(rawInterval, "^\d+$") || (rawInterval + 0) < 1 {
            WebhookInterval.Value := WEBHOOK["webhook_summary_interval_min"]
            MsgBox("간격은 1 이상의 정수여야 합니다.", "잘못된 값")
            return
        }

        WEBHOOK["webhook_url"] := Trim(WebhookUrlEdit.Value)
        WEBHOOK["webhook_enabled"] := WebhookEnabled.Value
        WEBHOOK["webhook_summary_interval_min"] := rawInterval + 0
        SaveSettingsFile()
        SaveWebhookBtn.ctrl.Value := "저장됨!"
        SetTimer(() => (SaveWebhookBtn.ctrl.Value := "저장"), -1500)
    }

    PersistWebhookFlag(key, value) {
        global WEBHOOK
        WEBHOOK[key] := value
        SaveSettingsFile()
    }

    ; 탭 2~9 위젯은 EnsureLazyTab → FinishLazyTab 에서 초기화

    ; Detach from the tab control so the promo strip is window-level (shows on
    ; every tab), slide the whole tab page down by bannerH, then build the strip
    ; in the freed top band. Tab3 moves its children with it, so none of the
    ; per-tab control coordinates above need to change.
    if (bannerH > 0) {
        MainTab.UseTab(0)
        MainTab.Move(, bannerH)
        PromoBanner.Attach(mg, Accent, BgColor, TextColor, BorderColor)
    }

    mg.Show("w880 h" (700 + bannerH) " y40 x900")
    global g_MainGuiHwnd
    g_MainGuiHwnd := mg.Hwnd
    ; 창 끌기/리사이즈 중 매크로 타이머가 메시지 펌프를 잡아먹지 않게
    ; (MaxThreads>0 → 진행 중인 MacroLoop도 이 콜백으로 끊을 수 있음)
    OnMessage(0x0231, OnGuiEnterSizeMove, 2)  ; WM_ENTERSIZEMOVE
    OnMessage(0x0232, OnGuiExitSizeMove, 2)   ; WM_EXITSIZEMOVE
    OnMessage(0x00A1, OnGuiNcLButtonDown, 2)  ; WM_NCLBUTTONDOWN — 타이틀바
    OnMessage(0x00A2, OnGuiNcLButtonUp, 2)    ; WM_NCLBUTTONUP — 클릭만 하고 뗄 때 복구
    ; WM_MOVING은 픽셀마다 AHK로 들어와 탭 컨트롤이 많을수록 드래그를 죽임 → 등록하지 않음
    UpdateRobloxUiState()
    UpdateMacroStatus("OFF", "---", "---")
	MainTab.OnEvent("Change", OnMainTabChange)
    MainTab.Choose(1)
	ResizeGuiTab(MainTab)
    lastAllowedTab := MainTab.Value

    mg.OnEvent("Close", (*) => ExitApp())

    SaveDarkModeToggle(ctrl, *) {
        global USERPREFS, SETTINGS

        USERPREFS["dark_mode"] := ctrl.Value ? 1 : 0
        SETTINGS["user"]["dark_mode"] := USERPREFS["dark_mode"]
        ApplyFixedAppearance()
        SaveSettingsFile()
        ReloadMacro()
    }

    SaveMinimizeOnMacroToggle(ctrl, *) {
        global USERPREFS, SETTINGS
        USERPREFS["minimize_on_macro"] := ctrl.Value ? 1 : 0
        SETTINGS["user"]["minimize_on_macro"] := USERPREFS["minimize_on_macro"]
        SaveSettingsFile()
    }

    ResolveAndSaveAppraiseTarget(*) {
        global MAIN, SETTINGS
        if !(IsSet(AutoAppraiseMutation) && AutoAppraiseMutation && IsSet(AppraiseCustomEdit) && AppraiseCustomEdit)
            return
        custom := Trim(AppraiseCustomEdit.Value)
        selected := Trim(AutoAppraiseMutation.Text)
        value := (custom != "") ? custom : selected
        if (value = "")
            return
        if (MAIN.Has("auto_appraise_mutation") && MAIN["auto_appraise_mutation"] = value)
            return
        MAIN["auto_appraise_mutation"] := value
        SETTINGS["main"]["auto_appraise_mutation"] := value
        SaveSettingsFile()
    }

    ; 목록 선택 시 직접 입력을 비워 DDL이 항상 MAIN에 반영되게 함
    OnAppraiseMutationDdlChange(*) {
        if (IsSet(AppraiseCustomEdit) && AppraiseCustomEdit)
            AppraiseCustomEdit.Value := ""
        ResolveAndSaveAppraiseTarget()
    }

    ResolveAndSaveEnchantTarget(*) {
        global MAIN, SETTINGS
        if !(IsSet(AutoEnchantName) && AutoEnchantName && IsSet(EnchantCustomEdit) && EnchantCustomEdit)
            return
        custom := Trim(EnchantCustomEdit.Value)
        selected := Trim(AutoEnchantName.Text)
        value := (custom != "") ? custom : selected
        if (value = "")
            return
        if (MAIN.Has("auto_enchant_name") && MAIN["auto_enchant_name"] = value)
            return
        MAIN["auto_enchant_name"] := value
        SETTINGS["main"]["auto_enchant_name"] := value
        SaveSettingsFile()
    }

    OnEnchantNameDdlChange(*) {
        if (IsSet(EnchantCustomEdit) && EnchantCustomEdit)
            EnchantCustomEdit.Value := ""
        ResolveAndSaveEnchantTarget()
    }

    SaveGamepassEnchantEnabled(ctrl, *) {
        global MAIN, SETTINGS

        MAIN["gamepass_enchant_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["gamepass_enchant_enabled"] := MAIN["gamepass_enchant_enabled"]
        SaveSettingsFile()
    }

    SaveSovereignEnchantChargeEnabled(ctrl, *) {
        global MAIN, SETTINGS

        MAIN["sovereign_enchant_charge_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["sovereign_enchant_charge_enabled"] := MAIN["sovereign_enchant_charge_enabled"]
        SaveSettingsFile()
    }

    SaveAutoSovereignEnchantChargeEnabled(ctrl, *) {
        global MAIN, SETTINGS

        MAIN["auto_sovereign_enchant_charge_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["auto_sovereign_enchant_charge_enabled"] := MAIN["auto_sovereign_enchant_charge_enabled"]
        MAIN["auto_sovereign_charge_below"] := 95
        MAIN["auto_sovereign_charge_until"] := 100
        SETTINGS["main"]["auto_sovereign_charge_below"] := 95
        SETTINGS["main"]["auto_sovereign_charge_until"] := 100
        SaveSettingsFile()
    }

    SaveAutoEnchantName(ctrl, *) {
        ResolveAndSaveEnchantTarget()
    }

    SaveGamepassAppraiseEnabled(ctrl, *) {
        global MAIN, SETTINGS

        MAIN["gamepass_appraise_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["gamepass_appraise_enabled"] := MAIN["gamepass_appraise_enabled"]
        SaveSettingsFile()
    }

    SaveAppraiseMutationTotemEnabled(ctrl, *) {
        global MAIN, SETTINGS

        MAIN["auto_appraise_mutation_totem"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["auto_appraise_mutation_totem"] := MAIN["auto_appraise_mutation_totem"]
        SaveSettingsFile()
    }

    SaveTreasureAppraiseEnabled(ctrl, *) {
        global MAIN, SETTINGS
        MAIN["treasure_appraise_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["treasure_appraise_enabled"] := MAIN["treasure_appraise_enabled"]
        SaveSettingsFile()
    }

    SaveTreasureAppraiseAutoTake(ctrl, *) {
        global MAIN, SETTINGS
        MAIN["treasure_appraise_auto_take"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["treasure_appraise_auto_take"] := MAIN["treasure_appraise_auto_take"]
        SaveSettingsFile()
    }

    SaveTreasureGoalMultEnabled(ctrl, *) {
        global MAIN, SETTINGS
        MAIN["treasure_goal_mult_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["treasure_goal_mult_enabled"] := MAIN["treasure_goal_mult_enabled"]
        SaveSettingsFile()
    }

    SaveTreasureGoalMultValue(ctrl, *) {
        global MAIN, SETTINGS
        value := Trim(ctrl.Value)
        if !RegExMatch(value, "^\d+(\.\d+)?$") {
            ctrl.Value := MAIN.Has("treasure_goal_mult") ? MAIN["treasure_goal_mult"] : "1.10"
            MsgBox("배수 목표는 숫자여야 합니다. 예: 1.10", "잘못된 값")
            return
        }
        MAIN["treasure_goal_mult"] := value + 0.0
        SETTINGS["main"]["treasure_goal_mult"] := MAIN["treasure_goal_mult"]
        ctrl.Value := MAIN["treasure_goal_mult"]
        SaveSettingsFile()
    }

    SaveTreasureGoalTotalEnabled(ctrl, *) {
        global MAIN, SETTINGS
        MAIN["treasure_goal_total_kg_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["treasure_goal_total_kg_enabled"] := MAIN["treasure_goal_total_kg_enabled"]
        SaveSettingsFile()
    }

    SaveTreasureGoalTotalValue(ctrl, *) {
        global MAIN, SETTINGS
        value := Trim(ctrl.Value)
        if !RegExMatch(value, "^\d+(\.\d+)?$") {
            ctrl.Value := MAIN.Has("treasure_goal_total_kg") ? MAIN["treasure_goal_total_kg"] : "500"
            MsgBox("Total kg 목표는 숫자여야 합니다.", "잘못된 값")
            return
        }
        MAIN["treasure_goal_total_kg"] := value + 0.0
        SETTINGS["main"]["treasure_goal_total_kg"] := MAIN["treasure_goal_total_kg"]
        ctrl.Value := MAIN["treasure_goal_total_kg"]
        SaveSettingsFile()
    }

    SaveTreasureGoalBigGiantEnabled(ctrl, *) {
        global MAIN, SETTINGS
        MAIN["treasure_goal_big_giant_enabled"] := ctrl.Value ? 1 : 0
        SETTINGS["main"]["treasure_goal_big_giant_enabled"] := MAIN["treasure_goal_big_giant_enabled"]
        SaveSettingsFile()
    }

    SaveAutoAppraiseMutation(ctrl, *) {
        ResolveAndSaveAppraiseTarget()
    }

    UpdateAppraiseControls() {
    }
	
	ResizeGuiTab(ctrl, *){
		switch ctrl.Value{
			case 1: ; fishing
				w := 880, h := 300
			case 2: ; window & harpoon
				w := 880, h := 500
			case 3: ; appraisal
				w := 880, h := 520
			case 4: ; enchant
				w := 880, h := 320
			case 5: ; items
				w := 880, h := 580
			case 6: ; hunt
				w := 880, h := 560
			case 7: ; misc
				w := 880, h := 280
			case 8: ; hotkeys
				w := 880, h := 260
			case 9: ; settings
				w := 880, h := 460
			case 10: ; credits
				w := 880, h := 520
			default:
				w := 880, h := 680
		}
		MainTab.Move(0, bannerH, w, h)
		global g_MainTabGeom
		g_MainTabGeom := { x: 0, y: bannerH, w: w, h: h }
		mg.Show("w" w " h" (h + bannerH))
	}
}

GetRodDisplayText() {
    global ROD
    ; Once we're attached and in Fisch the rod name is the source of truth; until then,
    ; reuse this field to tell the user where attachment stands (no rod yet anyway).
    base := (ROD != "" ? ROD : GetAttachStatusText())
    if (ROD = "")
        return base

    ; Keeperbound(군주) 낚싯대만 핫바 powerLabel이 있음 — 자동 충전 여부와 무관하게 표시.
    try {
        p := ReadKeeperboundPowerPercent()
        if (p != "")
            return base " · " Format("{:.1f}%", p)
    } catch {
    }
    return base
}

UpdateWindowHarpoonStatusUi(*) {
    global Macro, WindowUseStatusText, HarpoonStatusText, MAIN

    winLine := "상태: 대기.`n토글을 켠 뒤 이 탭에서 F1로 시작하세요."
    harpLine := "상태: 대기.`n토글을 켠 뒤 이 탭에서 F1로 시작하세요."

    if (IsSet(Macro) && Macro && Macro.cycleEnabled && Macro.phase = "WINDOW") {
        if (IsWindowUseClickerRunning())
            winLine := "상태: 연타 중 — 좌·우 초고속 연타.`n같은 단축키로 중지하세요."
        else if (IsWindowUseGuiVisible())
            winLine := "상태: 미니게임 시작 대기 — 바가 커질 때까지 기다립니다."
        else
            winLine := "상태: 대기 중 — 창 GUI가 뜰 때까지 연타하지 않습니다.`n같은 단축키로 중지하세요."
    } else if (MAIN.Has("window_use_enabled") && MAIN["window_use_enabled"])
        winLine := "상태: 준비됨.`n이 탭에서 F1을 누르면 창 GUI 대기 모드로 들어갑니다."

    if (IsSet(Macro) && Macro && Macro.cycleEnabled && Macro.phase = "HARPOON")
        harpLine := "상태: 실행 중 — 작살총.`n같은 단축키로 중지하세요."
    else if (MAIN.Has("harpoon_use_enabled") && MAIN["harpoon_use_enabled"])
        harpLine := "상태: 준비됨.`n이 탭에서 F1을 누르면 작살총이 시작됩니다."

    if (IsSet(WindowUseStatusText) && WindowUseStatusText)
        try WindowUseStatusText.Value := winLine
    if (IsSet(HarpoonStatusText) && HarpoonStatusText)
        try HarpoonStatusText.Value := harpLine
}

ToggleHumpbackSpawnFromGui(*) {
    global Macro
    if (Macro.cycleEnabled && Macro.phase = "HUMPBACK_SPAWN") {
        StopHumpbackSpawnCycle("OFF", "중지됨.")
        return
    }
    if (Macro.cycleEnabled) {
        MsgBox("다른 매크로가 실행 중입니다. 먼저 중지하세요.", "Humpback Whale Spawn")
        return
    }
    if (StartHumpbackSpawnCycle())
        StartMacroMouseTip("혹등 스폰 ON")
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
    global AutoTotemSelectionText
    if IsSet(AutoTotemSelectionText) && AutoTotemSelectionText
        SetCtrlTextIfChanged(AutoTotemSelectionText, FormatAutoTotemSelectionDisplay())
}

; Plain-text, dialog-free attach state for the UI. Ordered cheapest-first: the no-Roblox
; case returns before any process-memory work, so the per-second watcher refresh is light.
GetAttachStatusText() {
    global g_BuildUnsupported, g_AttachFailReason, _ConnectingSince, ATTACH_CONNECTING_TIMEOUT_MS

    if (!GetRobloxPID())
        return "로블록스 대기 중..."

    if (IsSet(g_BuildUnsupported) && g_BuildUnsupported)
        return GetUnsupportedBuildStatusText()

    ; A real attach failure beats the generic prompt: telling someone already inside
    ; Fisch to "Join a Fisch server" reads as stuck, when the truth is the offsets
    ; (or the API) are what's broken. See g_AttachFailReason in Constants.ahk.
    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "offsets")
        return "이 빌드에 오프셋이 아직 맞지 않음"
    if (IsSet(g_AttachFailReason) && g_AttachFailReason = "api")
        return "OpenMacro 서버에 연결할 수 없음"

    if (IsMemoryReady() && IsInFischGame()) {
        if (!_ConnectingSince)
            _ConnectingSince := A_TickCount
        leftMs := ATTACH_CONNECTING_TIMEOUT_MS - (A_TickCount - _ConnectingSince)
        leftSec := Max(0, Ceil(leftMs / 1000))
        return "접속 중... (" leftSec "초)"
    }

    return "Fisch 서버에 입장하세요"
}

UpdateRobloxUiState() {
    global RodEquipped, g_GuiSizing

    if (IsSet(g_GuiSizing) && g_GuiSizing)
        return

    if IsSet(RodEquipped) && RodEquipped
        SetCtrlTextIfChanged(RodEquipped, GetRodDisplayText())

    UpdateWorldClimateUi()
    UpdateHuntStatusUi()
    UpdateLullabyModeUi()
    UpdateLullabyFishingToggleUi()
    UpdateAutoTotemSelectionUi()
}

UpdateLullabyModeUi() {
    global RodEquipped, StatusText, Macro, PowerText, ProgressText

    if IsSet(RodEquipped) && RodEquipped
        SetCtrlTextIfChanged(RodEquipped, GetRodDisplayText())

    if !(IsSet(Macro) && Macro && Macro.phase = "LULLABY")
        return
    if !(IsSet(StatusText) && StatusText)
        return

    power := (IsSet(PowerText) && PowerText) ? RegExReplace(PowerText.Value, "^파워:\s*", "") : "---"
    progress := (IsSet(ProgressText) && ProgressText) ? RegExReplace(ProgressText.Value, "^진행:\s*", "") : "---"
    UpdateMacroStatus(GetMacroDisplayStatus(), power, progress)
}

UpdateLullabyFishingToggleUi() {
    global ROD, LullabyFishCb, LullabyFishLabel, USERPREFS
    show := (IsSet(ROD) && ROD != "" && IsLullabyRodText(ROD))
    if IsSet(LullabyFishCb) && LullabyFishCb {
        LullabyFishCb.Visible := show
        if (show)
            LullabyFishCb.Value := (USERPREFS.Has("lullaby_fishing") && USERPREFS["lullaby_fishing"]) ? 1 : 0
    }
    if IsSet(LullabyFishLabel) && LullabyFishLabel
        LullabyFishLabel.Visible := show
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

UpdateWorldClimateUi() {
    global WeatherText, ClimateDetailText

    climate := FormatWorldClimateDisplay()

    if IsSet(WeatherText) && WeatherText
        SetCtrlTextIfChanged(WeatherText, climate["weatherLine"])

    if IsSet(ClimateDetailText) && ClimateDetailText
        SetCtrlTextIfChanged(ClimateDetailText, climate["detailLine"])

    UpdateBuffStatusUi(false)
}

ApplyThemePreset(ddl, themes, appearanceFields) {
    global SETTINGS, APPEARANCE
    themeName := ddl.Text

    if (themeName = "사용자 지정") {
        customTheme := SETTINGS.Has("custom_theme") ? SETTINGS["custom_theme"] : APPEARANCE
        for field in appearanceFields {
            if (customTheme.Has(field.key)) {
                field.ctrl.Value := customTheme[field.key]
                field.swatch.Opt("Background" customTheme[field.key])
            }
        }
        return
    }

    if (!themes.Has(themeName))
        return

    theme := themes[themeName]

    for field in appearanceFields {
        if (theme.Has(field.key)) {
            field.ctrl.Value := theme[field.key]
            field.swatch.Opt("Background" theme[field.key])
        }
    }
}

; Returns an HBITMAP of `path` resized to w*h logical px using GDI+
; HighQualityBicubic interpolation. Supersamples by the screen DPI factor so it
; stays sharp on hi-DPI displays. The "HBITMAP:*" prefix lets the Picture control
; take ownership and free it.
LoadHQBitmap(path, w, h) {
    dpi := A_ScreenDPI / 96
    w := Round(w * dpi), h := Round(h * dpi)

    DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si, 0)                                   ; GdiplusVersion = 1
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", si, "Ptr", 0)

    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", path, "Ptr*", &src := 0)
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0
          , "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst := 0)      ; 32bppARGB
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g := 0)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7)  ; HighQualityBicubic
    DllCall("gdiplus\GdipSetSmoothingMode",     "Ptr", g, "Int", 4)  ; AntiAlias
    DllCall("gdiplus\GdipSetPixelOffsetMode",   "Ptr", g, "Int", 2)  ; HighQuality
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", src
          , "Int", 0, "Int", 0, "Int", w, "Int", h)
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", dst, "Ptr*", &hbm := 0, "UInt", 0)

    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", dst)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", src)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", tok)
    return hbm
}

; Returns an HICON of `path` scaled to fit a square `size`x`size` canvas with the
; aspect ratio preserved and transparent padding, using GDI+ HighQualityBicubic.
; Used as the window/taskbar icon via WM_SETICON; Windows frees it on exit/reload.
LoadHQIcon(path, size) {
    DllCall("LoadLibrary", "Str", "gdiplus", "Ptr")
    si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, si, 0)                                   ; GdiplusVersion = 1
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &tok := 0, "Ptr", si, "Ptr", 0)

    DllCall("gdiplus\GdipCreateBitmapFromFile", "WStr", path, "Ptr*", &src := 0)
    DllCall("gdiplus\GdipGetImageWidth",  "Ptr", src, "UInt*", &srcW := 0)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", src, "UInt*", &srcH := 0)

    ; Fit within the square, preserving aspect ratio, centered.
    scale := Min(size / srcW, size / srcH)
    dw := Round(srcW * scale), dh := Round(srcH * scale)
    dx := (size - dw) // 2, dy := (size - dh) // 2

    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", size, "Int", size, "Int", 0
          , "Int", 0x26200A, "Ptr", 0, "Ptr*", &dst := 0)      ; 32bppARGB
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", dst, "Ptr*", &g := 0)
    DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", g, "Int", 7)  ; HighQualityBicubic
    DllCall("gdiplus\GdipSetSmoothingMode",     "Ptr", g, "Int", 4)  ; AntiAlias
    DllCall("gdiplus\GdipSetPixelOffsetMode",   "Ptr", g, "Int", 2)  ; HighQuality
    DllCall("gdiplus\GdipDrawImageRectI", "Ptr", g, "Ptr", src
          , "Int", dx, "Int", dy, "Int", dw, "Int", dh)
    DllCall("gdiplus\GdipCreateHICONFromBitmap", "Ptr", dst, "Ptr*", &hicon := 0)

    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", g)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", dst)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", src)
    DllCall("gdiplus\GdiplusShutdown", "Ptr", tok)
    return hicon
}

ApplyAppearanceChanges(appearanceFields, themeDDL := "") {
    global SETTINGS, APPEARANCE

    pendingColors := Map()
    hasChanges := false

    for field in appearanceFields {
        raw := StrUpper(Trim(field.ctrl.Value))

        if !RegExMatch(raw, "^[0-9A-F]{6}$") {
            field.ctrl.Value := APPEARANCE[field.key]
            field.ctrl.Focus()
            MsgBox(field.label "에 유효한 6자리 16진수 색상을 입력하세요 (예: FF0000).", "잘못된 색상")
            return
        }

        pendingColors[field.key] := raw
        hasChanges := hasChanges || (raw != APPEARANCE[field.key])
    }

    for field in appearanceFields {
        color := pendingColors[field.key]
        field.ctrl.Value := color
        field.swatch.Opt("Background" color)
    }

    if !hasChanges
        return

    for key, color in pendingColors {
        APPEARANCE[key] := color
        SETTINGS["appearance"][key] := color
    }

    if (themeDDL != "") {
        SETTINGS["last_theme"] := themeDDL.Text
        if (themeDDL.Text = "사용자 지정") {
            for key, color in pendingColors
                SETTINGS["custom_theme"][key] := color
        }
    }

    SaveSettingsFile()
    ReloadMacro()
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
        "창 사용", "창 사용",
        "작살총", "작살총",
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
        "GP_WAIT_RELIC", "릴릭 대기"
    )
    ; APPRAISE / GP / ENCHANT STATE 형태
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
    return statusMap.Has(status) ? statusMap[status] : status
}

UpdateMacroStatus(status := "", power := "", progress := "") {
    global StatusText, PowerText, ProgressText, CaughtText, LostText, SuccessRateText, Macro

    displayStatus := status
    if (IsSet(Macro) && Macro && Macro.HasOwnProp("autoChargeStatusHold")
        && Macro.autoChargeStatusHold != ""
        && Macro.HasOwnProp("autoChargeStatusHoldUntil")
        && A_TickCount < Macro.autoChargeStatusHoldUntil) {
        displayStatus := Macro.autoChargeStatusHold
    }

    if IsSet(StatusText) && StatusText
        SetCtrlTextIfChanged(StatusText, "상태: " (displayStatus = "" ? "---" : LocalizeStatus(displayStatus)))

    if IsSet(PowerText) && PowerText
        SetCtrlTextIfChanged(PowerText, "파워: " (power = "" ? "---" : power))

    if IsSet(ProgressText) && ProgressText
        SetCtrlTextIfChanged(ProgressText, "진행: " (progress = "" ? "---" : progress))

    if IsSet(Macro) {
        caught := Macro.fishCaughtCount
        lost := Macro.fishLostCount
        total := caught + lost
        successRate := total > 0 ? (caught / total) * 100.0 : 0.0

        if IsSet(CaughtText) && CaughtText
            SetCtrlTextIfChanged(CaughtText, "낚음: " caught)

        if IsSet(LostText) && LostText
            SetCtrlTextIfChanged(LostText, "놓침: " lost)

        if IsSet(SuccessRateText) && SuccessRateText
            SetCtrlTextIfChanged(SuccessRateText, "성공률: " Format("{:.1f}", successRate) "%")
    }
}

SetCtrlTextIfChanged(ctrl, text) {
    if (!ctrl)
        return
    try {
        if (ctrl.Value = text)
            return
        ctrl.Value := text
    } catch {
        try {
            if (ctrl.Text = text)
                return
            ctrl.Text := text
        } catch {
        }
    }
}

OnGuiEnterSizeMove(*) {
    global g_GuiSizing, g_GuiInSizeMove
    g_GuiInSizeMove := true
    g_GuiSizing := true
    DetachGuiChildrenForDrag(true)
    SetTimer(GuiCaptionDragSafety, 0)
    SetTimer(GuiCaptionDragFailsafe, 0)
}

OnGuiExitSizeMove(*) {
    global g_GuiSizing, g_GuiInSizeMove
    g_GuiInSizeMove := false
    SetTimer(GuiCaptionDragSafety, 0)
    SetTimer(GuiCaptionDragFailsafe, 0)
    g_GuiSizing := false
    DetachGuiChildrenForDrag(false)
}

; 타이틀바 클릭만으로는 자식을 떼지 않음 — ENTERSIZEMOVE(실제 드래그)에서만 분리.
; 클릭 즉시 detach하면 EXIT가 안 오거나 redraw가 꺼진 채 남아 DDL/ListView가 어긋남.
OnGuiNcLButtonDown(wParam, lParam, msg, hwnd) {
    return
}

OnGuiNcLButtonUp(wParam, lParam, msg, hwnd) {
    global g_MainGuiHwnd, g_GuiInSizeMove
    if (IsSet(g_MainGuiHwnd) && g_MainGuiHwnd && hwnd != g_MainGuiHwnd)
        return
    ; 실제 이동/리사이즈 루프 중이면 EXITSIZEMOVE가 복구함.
    if (IsSet(g_GuiInSizeMove) && g_GuiInSizeMove)
        return
    if (wParam = 2) ; HTCAPTION
        GuiCaptionDragSafety()
}

; 타이틀바 빠른 클릭: detach만 되고 EXIT가 안 오는 경우 복구
GuiCaptionDragSafety(*) {
    global g_GuiSizing, g_GuiInSizeMove, g_DragDetached
    if (IsSet(g_GuiInSizeMove) && g_GuiInSizeMove)
        return
    if GetKeyState("LButton", "P")
        return
    SetTimer(GuiCaptionDragSafety, 0)
    SetTimer(GuiCaptionDragFailsafe, 0)
    if ((IsSet(g_GuiSizing) && g_GuiSizing) || (IsSet(g_DragDetached) && g_DragDetached)) {
        g_GuiSizing := false
        DetachGuiChildrenForDrag(false)
    }
}

; 최대 2초 — 드래그 중이 아니면 강제 복구 (redraw 영구 OFF 방지)
GuiCaptionDragFailsafe(*) {
    global g_GuiSizing, g_GuiInSizeMove, g_DragDetached
    if (IsSet(g_GuiInSizeMove) && g_GuiInSizeMove)
        return
    if GetKeyState("LButton", "P")
        return
    SetTimer(GuiCaptionDragSafety, 0)
    g_GuiSizing := false
    DetachGuiChildrenForDrag(false)
}

; Tab3 페이지 컨트롤은 GUI의 직계 자식 HWND라 Visible/Destroy만으로는
; 창 이동 비용이 안 줄어듦. 드래그 중엔 자식을 message-only 창으로 잠시 떼어냄.
DetachGuiChildrenForDrag(detach) {
    global g_MainGuiHwnd, g_DragChildHwnds, g_DragDetached, g_DragHoldHwnd
    if !(IsSet(g_MainGuiHwnd) && g_MainGuiHwnd)
        return

    if !IsSet(g_DragDetached)
        g_DragDetached := false
    if !IsSet(g_DragChildHwnds)
        g_DragChildHwnds := []

    if (detach) {
        if (g_DragDetached)
            return
        try {
            if !(IsSet(g_DragHoldHwnd) && g_DragHoldHwnd) {
                ; HWND_MESSAGE(-3) 아래 보관용 창 — 화면/이동 대상 아님
                g_DragHoldHwnd := DllCall("CreateWindowExW"
                    , "uint", 0
                    , "wstr", "Static"
                    , "wstr", ""
                    , "uint", 0
                    , "int", 0, "int", 0, "int", 0, "int", 0
                    , "ptr", -3
                    , "ptr", 0, "ptr", 0, "ptr", 0
                    , "ptr")
            }
            if !g_DragHoldHwnd
                return

            g_DragChildHwnds := []
            ; 직계 자식만 (EnumChildWindows는 손자까지 포함해 ComboBox 등이 깨짐)
            child := DllCall("GetWindow", "ptr", g_MainGuiHwnd, "uint", 5, "ptr") ; GW_CHILD
            while (child) {
                g_DragChildHwnds.Push(child)
                child := DllCall("GetWindow", "ptr", child, "uint", 2, "ptr") ; GW_HWNDNEXT
            }

            for hwnd in g_DragChildHwnds
                DllCall("SetParent", "ptr", hwnd, "ptr", g_DragHoldHwnd)

            g_DragDetached := true
            DllCall("SendMessage", "ptr", g_MainGuiHwnd, "uint", 0x000B, "ptr", 0, "ptr", 0) ; WM_SETREDRAW FALSE
        } catch {
        }
        return
    }

    ; re-attach — 실패해도 redraw는 반드시 복구 (꺼진 채면 DDL/ListView가 안 바뀌는 것처럼 보임)
    wasDetached := g_DragDetached
    try {
        if (wasDetached) {
            for hwnd in g_DragChildHwnds {
                if (hwnd && DllCall("IsWindow", "ptr", hwnd))
                    DllCall("SetParent", "ptr", hwnd, "ptr", g_MainGuiHwnd)
            }
        }
    } catch {
    } finally {
        g_DragChildHwnds := []
        g_DragDetached := false
        DllCall("SendMessage", "ptr", g_MainGuiHwnd, "uint", 0x000B, "ptr", 1, "ptr", 0) ; WM_SETREDRAW TRUE
        DllCall("RedrawWindow", "ptr", g_MainGuiHwnd, "ptr", 0, "ptr", 0, "uint", 0x0485) ; ERASE|INVALIDATE|FRAME|ALLCHILDREN
    }
}

UpdateHotkey(name, ctrl) {
    global SETTINGS

    newKey := ctrl.Value
    oldKey := SETTINGS["hotkeys"][name]

    if (newKey = oldKey)
        return

    if (newKey != "") {
        actionNames := Map(
            "start_macro", "매크로 시작",
            "stop_appraise", "감정/인챈트 중지",
            "fix_roblox", "로블록스 복구",
            "reload", "새로고침"
        )

        for actionName, assignedKey in SETTINGS["hotkeys"] {
            if (actionName != name && assignedKey = newKey) {
                ctrl.Value := oldKey
                MsgBox(
                    newKey " 키는 이미 " actionNames[actionName] "에 할당되어 있습니다. 다른 키를 선택하세요.",
                    "단축키 충돌"
                )
                return
            }
        }
    }

    callback := (name = "start_macro")   ? (*) => StartMacro()
              : (name = "stop_appraise") ? (*) => StopAppraisingHotkey()
              : (name = "fix_roblox")   ? (*) => FixRoblox()
              :                           (*) => ReloadMacro()

    HotkeyManager.ChangeHotkey(oldKey, newKey, callback)
    SETTINGS["hotkeys"][name] := newKey

    SaveSettingsFile()
    TrayTip("단축키가 로컬에 저장되었습니다.", "설정", "Mute")
}

OnLoadConfig(ddl) {
    if (ddl.Text = "설정값 없음")
        return

    LoadConfig(ddl.Text)
}

OnSaveConfig(ddl) {
    if (ddl.Text = "설정값 없음")
        return

    SaveConfig(ddl.Text)
    ShowConfigSavedDialog(ddl.Text)
}

OnNewConfig(ddl) {
    name := Trim(ShowConfigNameInput())

    if (name = "")
        return

    if (ddl.Text != "설정값 없음") {
        existingConfigs := ListConfigs()
        for cfg in existingConfigs {
            if (cfg = name) {
                ShowConfigAlert("이름 중복", "'" name "' 이름의 설정값이 이미 있습니다.")
                return
            }
        }
    }

    SaveConfig(name, true)

    if (ddl.Text = "설정값 없음") {
        ddl.Delete()
        ddl.Add([name])
    } else {
        ddl.Add([name])
    }

    ControlChooseString(name, ddl)
}

OnDeleteConfig(ddl) {
    if (ddl.Text = "설정값 없음")
        return

    name := ddl.Text

    if (!ShowConfigConfirmDialog(name))
        return

    DeleteConfig(name)
    RefreshConfigDDL(ddl)
}

RefreshConfigDDL(ddl, selectName := "") {
    ddl.Delete()
    configs := ListConfigs()

    if (configs.Length = 0) {
        ddl.Add(["설정값 없음"])
        ddl.Choose(1)
        return
    }

    ddl.Add(configs)
    if (selectName != "") {
        try ControlChooseString(selectName, ddl)
        catch
            ddl.Choose(1)
    } else {
        ddl.Choose(1)
    }
}

OnImportConfigs(ddl) {
    files := FileSelect("M3", , "설정값 가져오기", "설정값 파일 (*.json)")
    if (files.Length = 0)
        return

    imported := 0, lastName := "", failed := []
    for path in files {
        name := RegExReplace(RegExReplace(path, "^.*\\"), "i)\.json$")

        if (FileExist(CONFIGS_DIR "\" name ".json")) {
            choice := ShowImportCollisionDialog(name)
            if (choice = "skip")
                continue
            if (choice = "copy")
                name := FindFreeConfigName(name)
        }

        if (ImportConfigFile(path, name)) {
            imported++
            lastName := name
        } else {
            failed.Push(name)
        }
    }

    if (imported > 0)
        RefreshConfigDDL(ddl, lastName)

    ; Imported configs are added to the list, NOT applied -- loading stays an
    ; explicit user action, same as any locally saved config.
    if (failed.Length > 0) {
        names := ""
        for i, f in failed
            names .= (i = 1 ? "" : ", ") f
        ShowConfigAlert("가져오기 실패", failed.Length "개 파일을 가져오지 못했습니다 (잘못된 JSON?): " names)
    } else if (imported > 0) {
        ShowConfigAlert("가져오기 완료", imported "개 설정값을 가져왔습니다. 선택한 뒤 불러오기를 누르세요.")
    }
}

OnExportConfig(ddl) {
    if (ddl.Text = "설정값 없음")
        return

    name := ddl.Text
    if (!FileExist(CONFIGS_DIR "\" name ".json")) {
        ShowConfigAlert("내보내기 실패", "설정값 '" name "'에 저장된 파일이 없습니다. 먼저 저장하세요.")
        return
    }

    dest := FileSelect("S16", A_MyDocuments "\" name ".json", "설정값 내보내기", "설정값 파일 (*.json)")
    if (dest = "")
        return
    if (!RegExMatch(dest, "i)\.json$"))
        dest .= ".json"

    ; Config files contain only shareable tuning since the schema split, so
    ; export is a plain copy of the saved file.
    if (ExportConfigFile(name, dest))
        ShowConfigAlert("내보내기 완료", "설정값 '" name "'을(를) 내보냈습니다.")
    else
        ShowConfigAlert("내보내기 실패", "해당 위치에 쓸 수 없습니다.")
}

DimHex(hex, factor) {
    r := Round(Integer("0x" SubStr(hex, 1, 2)) * factor)
    g := Round(Integer("0x" SubStr(hex, 3, 2)) * factor)
    b := Round(Integer("0x" SubStr(hex, 5, 2)) * factor)
    return Format("{:02X}{:02X}{:02X}", r, g, b)
}
