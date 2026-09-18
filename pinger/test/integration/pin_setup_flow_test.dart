// 2026-01-19 16:10:00 EST - 통합 테스트: PIN 설정 플로우
// PRD 001 v1.4.4 섹션 7 테스트 전략

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinger/screens/auth/pin_setup_screen.dart';

void main() {
  group('PIN 설정 플로우 통합 테스트', () {
    testWidgets('PIN 설정 화면 렌더링 테스트', (WidgetTester tester) async {
      // Given: PIN 설정 화면 로드
      await tester.pumpWidget(
        const MaterialApp(
          home: PinSetupScreen(),
        ),
      );

      // Then: 필수 UI 요소 존재 확인
      expect(find.text('PIN 설정 (6자리)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
    });

    testWidgets('PIN 입력 → 확인 → 설정 완료 플로우', (WidgetTester tester) async {
      // Given: PIN 설정 화면
      await tester.pumpWidget(
        MaterialApp(
          home: const PinSetupScreen(),
          routes: {
            '/dashboard': (context) => const Scaffold(
              body: Center(child: Text('Dashboard')),
            ),
          },
        ),
      );

      // When: 첫 번째 PIN 입력 (123456)
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // Then: PIN 확인 화면으로 전환
      expect(find.text('PIN 확인'), findsOneWidget);

      // When: 동일한 PIN 재입력
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('PIN 설정 완료'));
      await tester.pumpAndSettle();

      // Then: 대시보드로 이동
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('PIN 불일치 시 에러 메시지 표시', (WidgetTester tester) async {
      // Given: PIN 설정 화면
      await tester.pumpWidget(
        const MaterialApp(
          home: PinSetupScreen(),
        ),
      );

      // When: 첫 번째 PIN 입력
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // When: 다른 PIN 입력
      await tester.enterText(find.byType(TextField), '654321');
      await tester.tap(find.text('PIN 설정 완료'));
      await tester.pumpAndSettle();

      // Then: 에러 메시지 표시
      expect(find.text('PIN이 일치하지 않습니다'), findsOneWidget);
    });

    testWidgets('6자리 미만 PIN 입력 시 에러', (WidgetTester tester) async {
      // Given: PIN 설정 화면
      await tester.pumpWidget(
        const MaterialApp(
          home: PinSetupScreen(),
        ),
      );

      // When: 5자리 PIN 입력
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      // Then: 에러 메시지 표시
      expect(find.text('PIN은 6자리여야 합니다'), findsOneWidget);
    });
  });
}
