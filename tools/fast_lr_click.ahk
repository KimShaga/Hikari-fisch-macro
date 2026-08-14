#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
#NoTrayIcon

; 단독 테스트용. 메인 매크로의 「창 사용」은 shared/FastLrClick.ahk 안에서
; 같은 로직을 in-process로 돌립니다 (자식 프로세스 F1/ToolTip 충돌 방지).
;
; F6 = 토글 시작/정지
; F7 = 종료
; (F1은 메인 매크로 단축키와 겹치지 않게 피함)

INTERVAL := 1
ALTERNATE := true

running := false
useLeft := true

F6:: {
    global running
    running := !running
    ToolTip(running ? "연타 ON" : "연타 OFF")
    SetTimer(() => ToolTip(), -800)
    if running
        SetTimer(SpamClick, INTERVAL)
    else
        SetTimer(SpamClick, 0)
}

F7:: ExitApp()

SpamClick() {
    global ALTERNATE, useLeft
    if ALTERNATE {
        if useLeft
            Click("Left")
        else
            Click("Right")
        useLeft := !useLeft
    } else {
        Click("Left")
        Click("Right")
    }
}
