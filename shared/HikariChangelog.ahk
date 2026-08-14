; ============================================================================
;  Hikari's Edited Fisch Macro — fork changelog vs OpenMacro XTernal
; ============================================================================
#Requires AutoHotkey v2.0

GetHikariUpdateLog() {
    global FULL_VER
    return (
        FULL_VER "`n"
        . "최적화 문제 수정`n"
        . "감정 시스템 개편`n"
        . "로블록스 연결 강화`n"
        . "`n"
        . "v0.7.1-Alpha.1`n"
        . "창 사용 모드 추가`n"
        . "헌트 Apex 분류 추가 (Mosslurker, Beluga, Dreadfin, Magician Narwhal, Narwhal)`n"
        . "성큰 체스트(Sunken Treasure) 감지 추가`n"
        . "Humpback Whale 이주 감지 수정 — Ancient Isle / Lost Jungle / Moosewood 근처 표시`n"
        . "낚시 PID 개선 (얇은 바 감속, 먼 거리 미끄러짐, 존 이동, 벽 튕김)`n"
        . "릴 디버그 오버레이/로그 추가`n"
        . "매크로 시작 시 이미 낚시 중이면 캐스트를 건너뛰고 잡기 단계로 진입`n"
        . "럴러바이 성능 개선 및 기능 개편`n"
        . "서버 첫 인챈트 Keepers 확인창 처리`n"
        . "`n"
        . "v0.6.2-Alpha.1`n"
        . "GUI 환경 대거 개편`n"
        . "크레딧 수정`n"
        . "토템 지원 범위 확장`n"
        . "게임패스 감정 시스템 추가`n"
        . "인챈트 탭 / 게임패스 인챈트 추가`n"
        . "헌트 감지 시스템 추가`n"
        . "noiseform 매크로 기능 추가`n"
        . "Lullaby 모드 자동 감지 및 낚시 수행 기능 추가`n"
        . "자동 군주 인챈트 충전(인챈트 게임패스 필요) 추가`n"
        . "낚시 PID 성능 개선 (이른 브레이킹 + 목표 통과 즉시 반전)`n"
    )
}
