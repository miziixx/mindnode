import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:mindsound/core/audio/audio_engine_interface.dart';
import 'package:mindsound/core/state/app_state.dart';
import 'package:mindsound/core/state/playback_controller.dart';
import 'package:mindsound/main.dart';

/// 실기기(에뮬레이터)에서 앱이 실제로 부팅·렌더링되는지 확인하는 통합 테스트.
/// "앱을 한 번도 실행해본 적 없음" 간극을 메운다. (오디오 재생은 시작하지 않는다.)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('앱이 부팅되어 온보딩→홈까지 렌더링된다', (tester) async {
    final appState = AppState();
    final engine = AudioEngineInterface();
    final playback = PlaybackController(
      engine: engine,
      presets: appState.presets,
      records: appState.records,
      settingsRepo: appState.settingsRepo,
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: playback),
      ],
      child: const MindSoundApp(),
    ));

    // 저장소 로드 + 첫 렌더 대기(무한 애니메이션 회피를 위해 pump 반복).
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 온보딩이 있으면 끝까지 진행("다음" 반복 후 "시작하기").
    for (var i = 0; i < 6; i++) {
      final start = find.text('시작하기');
      final next = find.text('다음');
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start.first);
        await tester.pump(const Duration(milliseconds: 400));
        break;
      } else if (next.evaluate().isNotEmpty) {
        await tester.tap(next.first);
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        break;
      }
    }
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // 홈 화면 지표: '세션' 문구가 어딘가에 존재해야 한다.
    expect(find.textContaining('세션'), findsWidgets);
  });
}
