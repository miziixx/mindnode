#!/usr/bin/env bash
# 로컬에서 마인드사운드 Android APK(릴리스) 빌드.
# CI(.github/workflows/build.yml)의 android 잡과 동일한 순서.
#
# 사전 준비:
#   - Flutter SDK (stable) : https://docs.flutter.dev/get-started/install
#   - Android SDK (Android Studio 설치 시 포함) + `flutter doctor` 통과
#   - Python 3
#
# 사용:  bash tools/build_local.sh
set -euo pipefail

cd "$(dirname "$0")/.."   # 저장소 루트로 이동

echo "▶ 1/4  Android 플랫폼 스캐폴드 생성 (flutter create)"
flutter create --org com.mindsound --project-name mindsound --platforms=android .

echo "▶ 2/4  네이티브 오디오 엔진 오버레이 + 매니페스트/아이콘 패치"
python3 tools/apply_native.py --platform android

echo "▶ 3/4  의존성 설치 (flutter pub get)"
flutter pub get

echo "▶ 4/4  릴리스 APK 빌드 (flutter build apk --release)"
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
echo
echo "✅ 완료: $APK"
echo "   폰에 설치: 이 파일을 폰으로 옮겨 열거나,  flutter install  (USB 디버깅 연결 시)"
