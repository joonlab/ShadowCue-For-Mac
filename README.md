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
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square">
  <img src="https://img.shields.io/badge/Version-1.1-orange?style=flat-square">
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

- **스텔스 모드**: 화면 녹화/공유 시 완전히 투명하게 숨겨짐
- **항상 최상위 표시**: 풀스크린 앱 위에서도 항상 보임
- **마크다운 지원**: 제목, 굵게, 기울임, 목록 등 마크다운 문법 렌더링
- **자동/수동 스크롤**: 트랙패드, 스크롤바, 단축키로 자유롭게 조작
- **글로벌 단축키**: 다른 앱에서도 프롬프터 제어 가능 (커스터마이징 가능)
- **완전 커스터마이징**: 글자 크기, 색상, 배경 투명도, 스크롤 속도
- **클릭스루 모드**: 프롬프터 뒤의 콘텐츠 클릭 가능
- **업데이트 확인**: 메뉴에서 새 버전 확인 가능

---

## Installation

### 방법 1: Release 다운로드 (권장)

1. [**최신 릴리즈 다운로드**](https://github.com/joonlab/ShadowCue-For-Mac/releases/latest)
2. `ShadowCue-v1.1.zip` 다운로드
3. 압축 해제
4. `ShadowCue.app`을 **Applications** 폴더로 이동
5. 실행

### 방법 2: 직접 빌드

```bash
# 저장소 클론
git clone https://github.com/joonlab/ShadowCue-For-Mac.git
cd ShadowCue-For-Mac

# 빌드
swiftc -o ShadowCue.app/Contents/MacOS/ShadowCue main.swift -framework Cocoa -framework Carbon

# Applications 폴더로 복사
cp -R ShadowCue.app /Applications/
```

---

## Usage

### 기본 단축키

| 단축키 | 기능 |
|--------|------|
| `Ctrl + Option + Space` | 자동 스크롤 재생/일시정지 |
| `Ctrl + Option + ↑` | 위로 스크롤 |
| `Ctrl + Option + ↓` | 아래로 스크롤 |
| `Ctrl + Option + H` | 프롬프터 숨기기/보이기 |
| `Ctrl + Option + D` | 클릭스루 모드 전환 |
| `Ctrl + Option + .` | 스크롤 속도 증가 |
| `Ctrl + Option + ,` | 스크롤 속도 감소 |

> 모든 단축키는 설정에서 커스터마이징 가능합니다.

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
- Apple Silicon 또는 Intel Mac

---

## How It Works

ShadowCue는 macOS의 `NSWindow.sharingType = .none` 속성을 활용하여 화면 캡처 및 공유에서 윈도우를 제외합니다. 이는 macOS의 네이티브 기능을 사용하므로 추가 드라이버나 해킹 없이 안전하게 동작합니다.

---

## Changelog

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
