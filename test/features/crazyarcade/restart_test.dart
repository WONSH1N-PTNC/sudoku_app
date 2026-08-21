import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/controller/crazy_arcade_controller.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/game_painter.dart';

void main() {
  test('재시작하면 새 판의 액터가 살아 있다', () {
    final controller = CrazyArcadeController(random: Random(4));
    addTearDown(controller.dispose);

    for (final actor in controller.world.actors) {
      actor.eliminate();
    }
    controller.advanceFrame(1 / 60);

    controller.restart();

    expect(controller.world.actors.where((a) => a.isDead), isEmpty);
    expect(controller.player, isNotNull);
  });

  test('페인터는 재시작 후 새 월드를 그린다', () {
    // 화면은 프레임마다 리빌드되지 않으므로, 페인터가 build 시점의 world를
    // 붙들고 있으면 재시작해도 옛 월드를 계속 그린다. 캐릭터가 사라져 보이던 원인이다.
    final controller = CrazyArcadeController(random: Random(4));
    addTearDown(controller.dispose);

    final painter = GamePainter(
      controller: controller,
      colorScheme: const ColorScheme.light(),
      repaint: controller.frames,
    );
    final before = controller.world;

    controller.restart();

    expect(controller.world, isNot(same(before)), reason: '재시작은 새 월드를 만든다');
    expect(painter.world, same(controller.world),
        reason: '페인터는 항상 현재 월드를 봐야 한다');
  });
}
