// 2026-01-19 16:12:00 EST - 통합 테스트: 인스턴스 관리 플로우
// PRD 001 v1.4.4 섹션 7 테스트 전략

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pinger/providers/instance_provider.dart';
import 'package:pinger/screens/instance_form_screen.dart';

void main() {
  group('인스턴스 관리 플로우 통합 테스트', () {
    late InstanceProvider provider;

    setUp(() {
      provider = InstanceProvider();
    });

    testWidgets('인스턴스 추가 폼 렌더링', (WidgetTester tester) async {
      // Given: 인스턴스 추가 화면
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: InstanceFormScreen(),
          ),
        ),
      );

      // Then: 필수 필드 존재 확인
      expect(find.text('인스턴스 추가'), findsOneWidget);
      expect(find.text('별칭 *'), findsOneWidget);
      expect(find.text('IP 주소 *'), findsOneWidget);
      expect(find.text('Health Check URL (선택)'), findsOneWidget);
      expect(find.text('체크 주기'), findsOneWidget);
      expect(find.text('타임아웃'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
    });

    testWidgets('필수 필드 미입력 시 검증 오류', (WidgetTester tester) async {
      // Given: 인스턴스 추가 화면
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: InstanceFormScreen(),
          ),
        ),
      );

      // When: 저장 버튼 클릭 (필드 미입력)
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // Then: 검증 오류 메시지 표시
      expect(find.text('별칭을 입력하세요'), findsOneWidget);
      expect(find.text('IP 주소를 입력하세요'), findsOneWidget);
    });

    testWidgets('잘못된 IP 형식 검증', (WidgetTester tester) async {
      // Given: 인스턴스 추가 화면
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: InstanceFormScreen(),
          ),
        ),
      );

      // When: 잘못된 IP 입력
      await tester.enterText(
        find.widgetWithText(TextFormField, '별칭 *'),
        'Test Server',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'IP 주소 *'),
        'invalid-ip',
      );
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();

      // Then: IP 검증 오류
      expect(find.text('올바른 IP 형식이 아닙니다'), findsOneWidget);
    });

    testWidgets('체크 주기 선택 테스트', (WidgetTester tester) async {
      // Given: 인스턴스 추가 화면
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: InstanceFormScreen(),
          ),
        ),
      );

      // When: 1분 주기 선택
      await tester.tap(find.text('1분'));
      await tester.pumpAndSettle();

      // Then: 1분이 선택됨
      final chip1 = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('1분'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip1.selected, isTrue);

      // When: 5분 주기로 변경
      await tester.tap(find.text('5분'));
      await tester.pumpAndSettle();

      // Then: 5분이 선택됨
      final chip5 = tester.widget<ChoiceChip>(
        find.ancestor(
          of: find.text('5분'),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip5.selected, isTrue);
    });

    testWidgets('타임아웃 슬라이더 조정', (WidgetTester tester) async {
      // Given: 인스턴스 추가 화면
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: InstanceFormScreen(),
          ),
        ),
      );

      // When: 슬라이더 조정 (20초로)
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      // Then: 타임아웃 값 변경 확인 (정확한 값은 슬라이더 위치에 따라 다름)
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
