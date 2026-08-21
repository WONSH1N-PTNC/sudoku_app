import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/crazy_arcade_screen.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/virtual_pad.dart';

/// 게임 루프가 계속 도므로 pumpAndSettle을 쓰면 안정화되지 않는다.
/// 프레임을 정해진 만큼만 진행시킨다.
Future<void> runFrames(WidgetTester tester, int frames) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> pumpScreen(WidgetTester tester, Size surface) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: CrazyArcadeScreen())),
  );
  await tester.pump();
}

void main() {
  testWidgets('화면이 그려지고 게임 루프가 돈다', (WidgetTester tester) async {
    await pumpScreen(tester, const Size(1200, 900));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.textContaining('위력'), findsOneWidget);
    expect(find.textContaining('남은 상대'), findsOneWidget);

    // 경과 시간이 흐르면 HUD가 갱신된다.
    await runFrames(tester, 70);
    expect(find.textContaining('1s'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink()); // Ticker 정리
  });

  testWidgets('넓은 화면에서는 가상 패드를 띄우지 않는다', (WidgetTester tester) async {
    await pumpScreen(tester, const Size(1200, 900));

    expect(find.byType(VirtualJoystick), findsNothing);
    expect(find.byType(BalloonButton), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('좁은 화면에서는 조이스틱과 물풍선 버튼이 나온다',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 840));

    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(find.byType(BalloonButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('방향키로 캐릭터가 움직인다', (WidgetTester tester) async {
    await pumpScreen(tester, const Size(1200, 900));
    final state = tester.state<State<CrazyArcadeScreen>>(
        find.byType(CrazyArcadeScreen)) as dynamic;
    final startX = state.controllerForTest.player.x as double;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await runFrames(tester, 30);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);

    expect(state.controllerForTest.player.x as double, greaterThan(startX));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('조이스틱을 끌면 캐릭터가 그 방향으로 움직인다',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 840));
    final state = tester.state<State<CrazyArcadeScreen>>(
        find.byType(CrazyArcadeScreen)) as dynamic;
    final startY = state.controllerForTest.player.y as double;

    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(0, 40)); // 아래로 밀기
    await runFrames(tester, 30);

    expect(state.controllerForTest.player.y as double, greaterThan(startY));

    await gesture.up();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('물풍선 버튼을 누르면 물풍선이 놓인다', (WidgetTester tester) async {
    await pumpScreen(tester, const Size(390, 840));
    final state = tester.state<State<CrazyArcadeScreen>>(
        find.byType(CrazyArcadeScreen)) as dynamic;

    expect(state.controllerForTest.world.balloons, isEmpty);

    await tester.tap(find.byType(BalloonButton));
    await runFrames(tester, 3);

    expect(state.controllerForTest.world.balloons, hasLength(1));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상단 다시 시작 버튼을 누르면 캐릭터가 다시 생성된다',
      (WidgetTester tester) async {
    await pumpScreen(tester, const Size(1200, 900));
    final state = tester.state<State<CrazyArcadeScreen>>(
        find.byType(CrazyArcadeScreen)) as dynamic;
    final controller = state.controllerForTest;

    // 잠시 플레이해 상태를 진행시킨다.
    // (게임이 끝난 뒤에는 모달 다이얼로그가 HUD를 덮으므로 진행 중에 누른다)
    await runFrames(tester, 70);
    final playedWorld = controller.world;
    expect(controller.world.elapsed as double, greaterThan(0.5));

    await tester.tap(find.byTooltip('새 게임'));
    await runFrames(tester, 2);

    expect(controller.world, isNot(same(playedWorld)), reason: '새 판이 깔려야 한다');
    expect(controller.world.actors.where((a) => a.isDead as bool), isEmpty,
        reason: '캐릭터가 살아 있는 상태로 다시 생성되어야 한다');
    expect(controller.world.elapsed as double, lessThan(0.2));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
