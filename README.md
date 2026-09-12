# Hikari's Edited Fisch Macro

**OpenMacro XTernal 기반의 Roblox Fisch 외부 메모리 매크로 포크**

기반: OpenMacro XTernal `v0.2.55`

편집: 히카리 (Discord : @1004hikari)

[디스코드 서버](https://discord.com/invite/KzgDYMAVxw) 가입해서 피드백 남기기

---

## 이 프로젝트는?

[OpenMacro XTernal](https://github.com/termx3/OpenMacro-XTernal)을 기반으로 UI·기능을 개인화한 포크입니다.  

원작 개발: misery ([@termx3](https://github.com/termx3))  
원작 유지보수: shinkting ([@Invermatic1](https://github.com/Invermatic1))  
원작 Discord: https://discord.gg/openmacro

---

## 실행 방법

1. [AutoHotkey v2](https://www.autohotkey.com/) 설치
2. Roblox에서 **Fisch** 접속
3. `Main.ahk` 실행

설정·오프셋 캐시 등은 `%APPDATA%\OpenMacro\XTernal`에 저장됩니다.

설정 저장 시 이전 파일은 `settings.json.bak`에 보관됩니다. 설정 JSON이
손상되거나 누락되면 백업을 복구하고, 백업도 읽을 수 없으면 기본값으로
시작합니다. 손상된 원본은 `settings.json.corrupt-*`로 보존됩니다.

---

## 이 포크에서 달라진 점

GUI 개선
안정성 강화
인챈트, 감정, 헌트 감지 기능
노이즈 폼, 할리벗 하푼, 스텔라웨이브 기믹 수행 기능
럴러바이 모드 자동 감지 및 낚시 수행
그 외 여러가지

[스텔라웨이브 돈작 테스트 영상](https://youtu.be/DynLK9EjU9A)

[럴러바이 테스트 영상](https://youtu.be/k6l38ZX8EIQ)

[노이즈 폼 테스트 영상](https://youtu.be/fmoRHaSsYPw)

[할리벗 하푼 테스트 영상](https://youtu.be/03FGReAdt5M)

디스코드에 가입해서 업데이트 소식을 빠르게 받으세요

---

## 라이선스 & 저작권

이 소프트웨어는 **GNU Affero General Public License, version 3.0 only (AGPL-3.0-only)** 하에 배포됩니다.  
자세한 내용은 [`LICENSE`](LICENSE), [`NOTICE`](NOTICE)를 참고하세요.

- OpenMacro XTernal 원작 저작권: Copyright © 2026 (@anorexc)
- 포크 수정분 또한 AGPL-3.0-only로 배포됩니다

의미 요약:
- **가능:** 사용·연구·수정·재배포 (단, 수정본도 AGPL-3.0으로 완전한 대응 소스 공개)
- **AGPL §13:** 네트워크로 수정본을 제공하면 그 버전의 완전한 소스를 제공해야 함
- **불가:** 비공개/독점 소프트웨어에 편입, 저작권·라이선스·고지 제거
- `library/`는 서드파티이며 각 저작권·라이선스가 적용됩니다. 위 AGPL 고지는 주로 원작 XTernal 소스(`Main.ahk`, `shared/`, `ui/`)와 이 포크의 수정분에 해당합니다.

`LICENSE` / `NOTICE` 또는 소스 헤더를 지워도 권리가 포기되거나 퍼블릭 도메인이 되지 않습니다.

---

*원작 프로젝트: [OpenMacro XTernal](https://github.com/termx3/OpenMacro-XTernal) · https://openmacro.net*
