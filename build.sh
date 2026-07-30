#!/bin/bash
# ShadowCue 빌드 스크립트
#
# ① -target 을 명시하지 않으면 swiftc 가 **빌드한 맥의 아키텍처와 OS 버전**을 그대로 쓴다.
#    v1.1 이 그렇게 빌드되어 arm64 단독 / minos 16.0(macOS 26) 바이너리가 배포됐고,
#    README 의 "macOS 12 이상, Intel 지원" 약속과 어긋났다. 그래서 타깃을 못 박는다.
#
# ② 번들 안의 바이너리를 교체한 **직후 그 바이너리를 실행하면 안 된다.**
#    com.apple.provenance 가 기록된 앱을 제자리에서 수정하고 실행하면 macOS 가
#    "변조된 앱"으로 보고 번들을 휴지통으로 옮긴다(2026-07-30 실제로 두 번 발생).
#    그래서 셀프테스트는 번들 밖 독립 바이너리로 돌리고, 번들은 수정 후 xattr 정리 + 재서명만 한다.
#
# 사용법:
#   ./build.sh            build/ 에만 빌드하고 검사 (앱 번들 건드리지 않음, 개발 중 기본)
#   ./build.sh --install  검사 통과 시 ShadowCue.app 번들까지 갱신 (배포 준비)
set -euo pipefail

cd "$(dirname "$0")"

MIN_OS="12"
APP="ShadowCue.app"
BUILD_DIR="build"
INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1

mkdir -p "$BUILD_DIR"

echo "==> arm64 (macOS $MIN_OS+)"
swiftc -O -target "arm64-apple-macos$MIN_OS" \
    -o "$BUILD_DIR/ShadowCue-arm64" main.swift \
    -framework Cocoa -framework Carbon

echo "==> x86_64 (macOS $MIN_OS+)"
swiftc -O -target "x86_64-apple-macos$MIN_OS" \
    -o "$BUILD_DIR/ShadowCue-x86_64" main.swift \
    -framework Cocoa -framework Carbon

echo "==> universal 결합"
lipo -create -output "$BUILD_DIR/ShadowCue-universal" \
    "$BUILD_DIR/ShadowCue-arm64" "$BUILD_DIR/ShadowCue-x86_64"

echo
echo "==> 검증"
lipo -archs "$BUILD_DIR/ShadowCue-universal"
vtool -show-build "$BUILD_DIR/ShadowCue-universal" 2>/dev/null | grep -E "architecture|minos" || true

echo
echo "==> 셀프테스트 (번들 밖 독립 바이너리로 — 위 ② 참조)"
# 실제 환경설정을 건드리지 않도록 격리 도메인 사용
SUITE="com.shadowcue.buildcheck.$$"
if SHADOWCUE_DEFAULTS_SUITE="$SUITE" "$BUILD_DIR/ShadowCue-arm64" --selftest > "$BUILD_DIR/selftest.log" 2>&1; then
    grep -cE '^PASS' "$BUILD_DIR/selftest.log" | sed 's/^/  PASS /'
    echo "  셀프테스트 통과"
else
    echo "  ❌ 셀프테스트 실패:"
    grep -E '^FAIL' "$BUILD_DIR/selftest.log" || cat "$BUILD_DIR/selftest.log"
    defaults delete "$SUITE" 2>/dev/null || true
    exit 1
fi
defaults delete "$SUITE" 2>/dev/null || true

if [[ "$INSTALL" -eq 0 ]]; then
    echo
    echo "완료(개발 빌드): $BUILD_DIR/ShadowCue-universal"
    echo "앱 번들까지 갱신하려면: ./build.sh --install"
    exit 0
fi

echo
echo "==> 앱 번들 갱신"
cp "$BUILD_DIR/ShadowCue-universal" "$APP/Contents/MacOS/ShadowCue"

# 번들을 제자리 수정했으므로 확장속성을 정리하고 다시 서명한다.
# --deep 없이 번들 전체를 서명해야 Contents/_CodeSignature/CodeResources 가 생긴다.
# 이게 없으면 codesign -v 가 실패하고, quarantine 이 붙은 배포본은
# "확인되지 않은 개발자"가 아니라 **"손상되었기 때문에 열 수 없습니다"** 로 거부된다(v1.1 의 상태).
xattr -cr "$APP"
codesign --force --sign - --timestamp=none "$APP"

echo
lipo -archs "$APP/Contents/MacOS/ShadowCue"
codesign -v --verbose=2 "$APP" 2>&1 | tail -2
echo
echo "완료(배포용): $APP"
echo "⚠️  이 번들의 바이너리를 지금 직접 실행하지 말 것 — 위 ② 참조."
echo "    실행 확인은 Finder 에서 열거나, 재부팅/로그아웃 후에 하라."
