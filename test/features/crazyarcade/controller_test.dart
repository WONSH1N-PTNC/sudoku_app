import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/controller/crazy_arcade_controller.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_world.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/player_input.dart';

CrazyArcadeController makeController({int seed = 4}) =>
    CrazyArcadeController(random: Random(seed));

void main() {
  group('게임 루프', () {
    test('고정 timestep보다 짧은 프레임은 누적됐다가 반영된다', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      final input = PlayerInputSource();
      controller.inputs[CrazyArcadeController.playerId] = input;
      input.setStick(1, 0);

      final startX = controller.player!.x;

      // 1/60초에 못 미치는 프레임을 여러 번 넣는다.
      for (int i = 0; i < 3; i++) {
        controller.advanceFrame(0.004);
      }
      expect(controller.player!.x, startX, reason: '아직 한 스텝도 차지 않았다');

      controller.advanceFrame(0.01); // 합계가 1/60을 넘긴다
      expect(controller.player!.x, greaterThan(startX));
    });

    test('큰 dt가 들어와도 한 번에 과도하게 진행되지 않는다', () {
      final fast = makeController();
      final slow = makeController();
      addTearDown(fast.dispose);
      addTearDown(slow.dispose);

      fast.advanceFrame(10.0); // 탭 복귀 등으로 튄 값
      slow.advanceFrame(kMaxFrameDelta);

      expect(fast.world.elapsed, closeTo(slow.world.elapsed, 1e-9));
    });

    test('설치 요청은 실제로 반영될 때까지 유지된다', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      final input = PlayerInputSource();
      controller.inputs[CrazyArcadeController.playerId] = input;

      input.requestPlace();
      // 아직 한 스텝도 돌지 않는 짧은 프레임
      controller.advanceFrame(0.004);
      expect(controller.world.balloons, isEmpty);

      controller.advanceFrame(0.02);
      expect(controller.world.balloons, hasLength(1),
          reason: '요청이 사라지지 않고 첫 스텝에 반영되어야 한다');
    });

    test('한 번의 요청으로 물풍선이 두 개 놓이지 않는다', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      final input = PlayerInputSource();
      controller.inputs[CrazyArcadeController.playerId] = input;
      controller.player!.maxBalloons = 5;

      input.requestPlace();
      // 여러 스텝이 한꺼번에 도는 긴 프레임
      controller.advanceFrame(0.2);

      expect(controller.world.balloons, hasLength(1));
    });

    test('일시정지 중에는 진행하지 않는다', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      controller.paused = true;
      controller.advanceFrame(0.5);

      expect(controller.world.elapsed, 0);
    });
  });

  group('상태 전달', () {
    test('HUD 값은 실제로 바뀔 때만 알림이 나간다', () {
      final controller = makeController();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.stats.addListener(() => notifications++);

      // 같은 초 안에서 여러 프레임을 돌린다.
      for (int i = 0; i < 20; i++) {
        controller.advanceFrame(1 / 60);
      }
      expect(notifications, lessThanOrEqualTo(1),
          reason: '레코드 값이 같으면 알림이 나가지 않아야 한다');
    });

    test('프레임 신호는 매 프레임 발신된다', () {
      final controller = makeController();
      addTearDown(controller.dispose);

      var frames = 0;
      controller.frames.addListener(() => frames++);

      for (int i = 0; i < 5; i++) {
        controller.advanceFrame(1 / 60);
      }
      expect(frames, 5);
    });

    test('승패가 결정되면 result가 갱신된다', () {
      final controller = makeController();
      addTearDown(controller.dispose);

      for (final actor in controller.world.actors) {
        if (actor.teamId != 0) actor.eliminate();
      }
      controller.advanceFrame(1 / 60);

      expect(controller.result.value, GameResult.victory);
    });

    test('다시 시작하면 새 판이 깔린다', () {
      final controller = makeController();
      addTearDown(controller.dispose);

      controller.player!.power = 7;
      for (final actor in controller.world.actors) {
        if (actor.teamId != 0) actor.eliminate();
      }
      controller.advanceFrame(1 / 60);
      expect(controller.result.value, GameResult.victory);

      controller.restart();

      expect(controller.result.value, GameResult.playing);
      expect(controller.player!.power, 1);
      expect(controller.world.elapsed, 0);
      expect(controller.world.actors.where((a) => a.isDead), isEmpty);
    });
  });
}
