import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindsound/widgets/common.dart';

// 자체 위젯 스모크 테스트. (flutter create 가 기본 widget_test.dart 를 덮어쓰지 않도록
// 파일을 선점한다 — 기본 템플릿은 존재하지 않는 MyApp 을 참조해 컴파일 오류를 낸다.)
void main() {
  testWidgets('PrimaryButton 이 라벨을 렌더링하고 탭 콜백이 동작한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: '시작하기',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('시작하기'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppSwitch 토글', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppSwitch(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(value, isTrue);
  });
}
