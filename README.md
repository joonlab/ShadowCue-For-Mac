# ShadowCue for Mac

<p align="center">
  <img src="ShadowCueForMac_app_icon.png" alt="ShadowCue Icon" width="200">
</p>

<p align="center">
  <strong>화면 녹화에 보이지 않는 스텔스 프롬프터</strong><br>
  <em>The Invisible Teleprompter for Screen Recording</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2012.0+-blue?style=flat-square&logo=apple">
  <img src="https://img.shields.io/badge/Arch-Universal%20(arm64%20%2B%20x86__64)-lightgrey?style=flat-square">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square">
  <img src="https://img.shields.io/badge/Version-1.2-orange?style=flat-square">
</p>

<p align="center">
  <a href="https://github.com/joonlab/ShadowCue-For-Mac/releases/latest">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-brightgreen?style=for-the-badge&logo=github" alt="Download">
  </a>
</p>

---

## Overview

**ShadowCue**는 화면 녹화나 화면 공유 시 보이지 않는 macOS 전용 텔레프롬프터입니다.

유튜브 촬영, 화상 회의, 프레젠테이션, 라이브 스트리밍 등에서 자연스럽게 대본을 읽으면서도 시청자에게는 프롬프터가 전혀 보이지 않습니다.

### Key Features

- **스텔스 모드**: 화면 녹화/공유에서 창이 제외됨 (메뉴바에도 앱 이름이 뜨지 않음)
- **작업 상태 유지**: 대본·색상·글자 크기·속도·창 위치·단축키가 다음 실행에도 그대로 — 촬영 준비를 다시 하지 않아도 됨
- **대본 자동 저장**: 타이핑하면 바로 반영되고 파일로 보관됨 (Finder·git 으로 열람/백업 가능)
- **항상 최상위 표시**: 풀스크린 앱 위에서도 항상 보임
- **마크다운 지원**: 제목, 굵게, 기울임, 목록 등 마크다운 문법 렌더링
- **자동/수동 스크롤**: 트랙패드, 스크롤바, 단축키로 자유롭게 조작
- **글로벌 단축키**: 다른 앱에서도 프롬프터 제어 가능 (커스터마이징 가능)
- **완전 커스터마이징**: 글자 크기, 색상, 배경 투명도, 스크롤 속도, 행간
- **클릭스루 모드**: 프롬프터 뒤의 콘텐츠 클릭 가능
- **업데이트 확인**: 메뉴에서 새 버전 확인 가능

---

## Installation

### 방법 1: Release 다운로드 (권장)

1. [**최신 릴리즈 다운로드**](https://github.com/joonlab/ShadowCue-For-Mac/releases/latest)
2. 최신 zip 다운로드 후 압축 해제
3. `ShadowCue.app`을 **Applications** 폴더로 이동
4. **격리 속성 제거** — 이 앱은 Apple 공증(notarization)을 받지 않았습니다:
   ```bash
   xattr -cr /Applications/ShadowCue.app
   ```
5. 실행

> ⚠️ 4번을 건너뛰면 *"손상되었기 때문에 열 수 없습니다"* 가 나오고 **'그래도 열기' 선택지가 없습니다.**
> 악성 코드라서가 아니라, 개발자 서명·공증이 없는 앱에 macOS 가 붙이는 격리 표시 때문입니다.
> 소스가 전부 이 저장소의 `main.swift` 한 파일에 있으니 직접 확인하고 빌드하셔도 됩니다.

### 방법 2: 직접 빌드 (권장 — 격리 문제가 없습니다)

```bash
git clone https://github.com/joonlab/ShadowCue-For-Mac.git
cd ShadowCue-For-Mac

./build.sh            # build/ 에 universal 빌드 + 셀프테스트
./build.sh --install  # ShadowCue.app 번들까지 갱신

cp -R ShadowCue.app /Applications/
```

`build.sh` 는 아키텍처와 최소 OS 버전을 명시해 빌드합니다. `-target` 없이 `swiftc` 를 직접 쓰면
**빌드한 맥의 아키텍처·OS 버전이 그대로 박혀서** 다른 맥에서 실행되지 않습니다(v1.1 이 이 문제로
arm64·macOS 26 전용으로 배포됐습니다).

---

## Usage

### 기본 단축키

| 단축키 | 기능 |
|--------|------|
| `Ctrl + Option + Return` | 자동 스크롤 재생/일시정지 |
| `Ctrl + Option + ↑` | 위로 스크롤 |
| `Ctrl + Option + ↓` | 아래로 스크롤 |
| `Ctrl + Option + H` | 프롬프터 숨기기/보이기 |
| `Ctrl + Option + D` | 클릭스루 모드 전환 |
| `Ctrl + Option + .` | 스크롤 속도 증가 |
| `Ctrl + Option + ,` | 스크롤 속도 감소 |

> 모든 단축키는 설정에서 커스터마이징 가능하며, 바꾼 값은 다음 실행에도 유지됩니다.

> **v1.2 에서 재생 단축키가 `Ctrl+Option+Space` → `Ctrl+Option+Return` 으로 바뀌었습니다.**
> 한국어 환경의 macOS 는 "입력 메뉴에서 다음 소스 선택"(한/영 전환)에 `Ctrl+Option+Space` 를
> **기본으로 켜 둔 채 출고**되어, 재생이 안 되고 입력기만 바뀌는 문제가 있었습니다.

단축키가 안 먹으면 메뉴바 아이콘이 `☷⚠` 로 바뀌고, 설정 창의 해당 항목이 빨갛게 표시됩니다.
다른 앱이 그 조합을 이미 쓰고 있다는 뜻이니 설정에서 다른 조합으로 바꾸세요.

### 스크롤 조작

- **트랙패드**: 프롬프터 위에서 두 손가락 스크롤
- **스크롤바**: 오른쪽 스크롤바 드래그 (스크롤 시 자동 표시, 3초 후 숨김)
- **단축키**: 글로벌 단축키로 어디서든 조작

### 마크다운 지원

설정 창에서 마크다운 문법으로 텍스트를 입력하면 프롬프터에 렌더링됩니다:

| 문법 | 설명 |
|------|------|
| `# 제목` | H1 제목 (가장 큼) |
| `## 제목` | H2 제목 |
| `### 제목` | H3 제목 |
| `**굵게**` | 굵은 글씨 |
| `*기울임*` | 기울임꼴 |
| `~~취소선~~` | 취소선 |
| `` `코드` `` | 인라인 코드 |
| `- 항목` | 목록 |
| `1. 항목` | 번호 목록 |
| `> 인용` | 인용문 |
| `---` | 구분선 |

---

## System Requirements

- macOS 12.0 (Monterey) 이상
- Apple Silicon 및 Intel Mac (universal 바이너리)

확인 방법:

```bash
lipo -archs /Applications/ShadowCue.app/Contents/MacOS/ShadowCue   # x86_64 arm64
vtool -show-build /Applications/ShadowCue.app/Contents/MacOS/ShadowCue | grep minos
```

---

## How It Works

ShadowCue는 macOS의 `NSWindow.sharingType = .none` 속성으로 화면 캡처·공유에서 창을 제외합니다.
추가 드라이버나 시스템 개조 없이 OS 기본 기능만 씁니다. 앱은 메뉴바 전용(`LSUIElement`)으로 동작해
**녹화 화면의 메뉴바에도 앱 이름이 남지 않습니다.**

### ⚠️ 중요한 촬영 전에는 반드시 테스트 녹화로 확인하세요

이 은닉은 Apple 이 "화면 캡처 방지"를 위해 **보증하는 기능이 아닙니다.** Apple 개발자 지원은
공개적으로 *"there are no public APIs for preventing screen capture"* 라고 밝히고 있고,
이 동작을 버그로 접수한 사례도 있습니다. 즉 **OS 업데이트로 바뀔 수 있습니다.**

작성 시점(macOS 26.4)에는 `screencapture`·ScreenCaptureKit 기반 녹화 모두에서 은닉이 확인됐지만,
중요한 촬영 전에는 1분만 투자해 직접 확인하시길 권합니다:

1. 프롬프터를 띄우고 대본을 보이게 한다
2. `⌘⇧5` 또는 `screencapture -v ~/Desktop/test.mov` 로 10초 녹화
3. 녹화 파일을 재생해 **프롬프터와 메뉴바에 ShadowCue 가 없는지** 확인
4. 실제 사용할 도구(Zoom 화면 공유, OBS 등)로도 같은 확인

파일 열기/저장 대화상자는 별도 프로세스가 그리므로 은닉되지 않습니다. 촬영 중에는 열지 마세요.

---

## Changelog

### v1.2

**"촬영 준비를 매번 다시 하지 않아도 되게" 만든 판**

- **설정·대본 영속화** — 대본, 글자 크기, 색상, 배경 투명도, 스크롤 속도, 행간, 창 위치,
  커스텀 단축키가 다음 실행에도 유지됩니다. 이전에는 앱을 끄면 전부 초기화됐습니다.
- **대본 파일 저장** — `~/Library/Application Support/ShadowCue/scripts/` 에 마크다운으로
  보관되고 직전 세대 백업(`.bak`)도 남습니다. 타이핑하면 0.3초 뒤 프롬프터에 자동 반영됩니다.
- **스텔스 강화** — 메뉴바에 앱 이름이 노출되던 문제를 해결했습니다(`.accessory` 전환).
  컬러 패널·알림창 등 보조 창도 캡처에서 제외되고, 창 제목도 남기지 않습니다.
- **기본 재생 단축키 변경** (`⌃⌥Space` → `⌃⌥Return`) — 한국어 macOS 기본 단축키(한/영 전환)와
  충돌해 재생이 안 되던 문제.
- **자동 스크롤 수정** — 대본 끝에 도달하면 이제 실제로 멈춥니다(이전에는 정지 조건이
  수학적으로 도달 불가여서 되감으면 저절로 다시 흘러내려갔습니다). 창·슬라이더를 드래그하는
  동안에도 스크롤이 끊기지 않고, 프레임 누락도 보정합니다.
- **읽던 위치 유지** — 글자 크기를 바꾸거나 창 크기를 조절해도 맨 위로 튀지 않습니다.
- **마크다운 수정** — 한 줄에 여러 강조가 섞이면 앞쪽 강조가 사라지던 문제
  (`*기울임* 그리고 **굵게**`, 백틱 안의 별표 등).
- **단축키 실패 표시** — 다른 앱이 조합을 점유하면 메뉴바 `☷⚠` 와 설정 창 빨간 표시로 알립니다.
- **universal 바이너리 + 유효한 서명** — v1.1 은 arm64·macOS 26 전용으로 빌드되어 README 의
  "macOS 12 이상, Intel 지원" 표기와 달랐고, 서명 검증이 실패해 *"손상되었기 때문에 열 수 없습니다"* 가
  떴습니다. 이제 arm64+x86_64 / macOS 12+ 로 빌드되고 `codesign -v` 를 통과합니다.
- 클릭스루 상태에서 투명도를 조절해도 "입력 통과 중" 표시가 유지됩니다.

### v1.1
- 마크다운 렌더링 지원 (제목, 굵게, 기울임, 목록, 인용, 코드 등)
- 업데이트 확인 메뉴 추가
- 스크롤바 자동 표시/숨김 (3초)
- UI/UX 개선

### v1.0
- 최초 릴리즈
- 스텔스 프롬프터 기본 기능
- 글로벌 단축키 지원
- 커스터마이징 설정

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

<p align="center">
  <strong>박준 (a.k.a 준랩 | JoonLab)</strong>
</p>

<p align="center">
  <a href="mailto:wns9133@gmail.com">wns9133@gmail.com</a>
</p>

<p align="center">
  <a href="https://www.youtube.com/@joonlab98?sub_confirmation=1">
    <img src="https://img.shields.io/badge/YouTube-준랩%20JoonLab-red?style=for-the-badge&logo=youtube" alt="YouTube">
  </a>
</p>

<p align="center">
  <a href="https://bio.link/joonpark">
    <img src="https://img.shields.io/badge/About-준랩%20JoonLab-blue?style=for-the-badge" alt="About">
  </a>
</p>

<p align="center">
  <a href="https://open.kakao.com/o/gl7JSkSg">
    <img src="https://img.shields.io/badge/KakaoTalk-AI%20%2F%20LLM%20지식%20공유방-yellow?style=for-the-badge&logo=kakaotalk" alt="KakaoTalk">
  </a>
</p>

---

<p align="center">
  Made with ❤️ for content creators
</p>
