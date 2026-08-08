#!/usr/bin/env bash
# 로컬 기기/에뮬레이터에서 마인드사운드 실행(디버그).
# 처음 한 번 스캐폴드+네이티브 오버레이를 적용한 뒤 flutter run 으로 띄운다.
# 에뮬레이터나 USB 기기가 먼저 켜져 있어야 한다( flutter devices 로 확인 ).
#
# 사용:  bash tools/run_local.sh
set -euo pipefail

cd "$(dirname "$0")/.."

# flutter create 는 기존 파일을 덮어쓰지 않아 옛 패치가 남는다 → 매번 새로 생성.
echo "▶ android/ 정리 후 스캐폴드 생성 + 네이티브 엔진 오버레이"
rm -rf android
flutter create --org com.mindsound --project-name mindsound --platforms=android .
python3 tools/apply_native.py --platform android

flutter pub get

echo "▶ 연결된 기기/에뮬레이터:"
flutter devices || true

echo "▶ 실행 (flutter run) — 여러 기기면 목록에서 고르세요"
flutter run
