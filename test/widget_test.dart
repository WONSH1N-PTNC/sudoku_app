import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku_app/main.dart';
import 'package:sudoku_app/router.dart';

void main() {
  // appRouter는 전역 싱글턴이라 테스트 간 위치가 남는다. 매 테스트를 로비에서 시작시킨다.
  setUp(() => appRouter.go('/'));

  testWidgets('앱 첫 진입 시 로비가 보이고 등록된 게임 카드가 렌더링된다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GameHubApp());
    await tester.pumpAndSettle();

    // 공용 셸의 브랜드와 네비게이션 탭
    expect(find.text('Game Hub'), findsOneWidget);
    expect(find.text('로비'), findsOneWidget);

    // 로비 헤드라인
    expect(find.text('무엇을 하고 놀까요?'), findsOneWidget);

    // 레지스트리에서 파생된 항목들 (각각 네비 탭 + 로비 카드로 2번씩)
    expect(find.text('스도쿠'), findsNWidgets(2));
    expect(find.text('블록 블라스트'), findsNWidgets(2));
    expect(find.textContaining('9×9 보드를 숫자로 채우는'), findsOneWidget);
    expect(find.textContaining('8×8 보드에 조각을 놓아'), findsOneWidget);

    // 아직 만들지 않은 게임들은 준비중 카드로 남는다
    expect(find.text('준비 중'), findsOneWidget);
  });

  testWidgets('로비에서 블록 블라스트 카드를 누르면 해당 게임으로 이동한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GameHubApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('8×8 보드에 조각을 놓아'));
    await tester.pumpAndSettle();

    expect(find.textContaining('점수'), findsWidgets);
    expect(find.textContaining('최고'), findsWidgets);
  });

  testWidgets('로비에서 스도쿠 카드를 누르면 스도쿠 화면으로 이동한다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GameHubApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('9×9 보드를 숫자로 채우는'));
    // 스도쿠 화면은 1초 주기 타이머를 돌리므로 pumpAndSettle을 쓰면 안정화되지 않는다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('9×9 보드 채워진 숫자: 62개'), findsOneWidget);
    expect(find.textContaining('레벨 1'), findsWidgets);

    // 타이머 정리를 위해 위젯 트리를 해제한다.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
