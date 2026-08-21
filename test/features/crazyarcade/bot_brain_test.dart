import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/ai/bot_brain.dart';
import 'package:sudoku_app/features/crazyarcade/ai/danger_map.dart';
import 'package:sudoku_app/features/crazyarcade/ai/grid_path.dart';
import 'package:sudoku_app/features/crazyarcade/domain/balloon.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_world.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

import 'crazy_arcade_harness.dart';

/// 봇 하나를 두뇌에 물려 시뮬레이션을 돌린다.
/// 실제 컨트롤러와 같게 프레임마다 read()를 한 번만 호출한다.
({int deadAtFrame, int placements, int framesRun}) runBot(
  GameWorld world,
  int botId, {
  required int frames,
  int seed = 1,
}) {
  final brain = BotBrain(world: world, actorId: botId, random: Random(seed));
  final bot = world.actorById(botId)!;
  var placements = 0;

  for (int frame = 0; frame < frames; frame++) {
    final intent = brain.read();
    if (intent.placeBalloon) placements++;
    world.update(kStep, {botId: intent});

    if (bot.isDead) {
      return (deadAtFrame: frame, placements: placements, framesRun: frame + 1);
    }
    if (world.result != GameResult.playing) {
      return (deadAtFrame: -1, placements: placements, framesRun: frame + 1);
    }
  }
  return (deadAtFrame: -1, placements: placements, framesRun: frames);
}

void main() {
  group('DangerMap', () {
    test('물풍선이 없으면 모든 칸이 안전하다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final danger = DangerMap.of(world);
      expect(danger.isSafe(3, 3), isTrue);
      expect(danger.isSafe(7, 7), isTrue);
    });

    test('폭발 예정 범위가 심지 시간과 함께 표시된다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      world.balloons.add(Balloon(col: 3, row: 3, ownerId: 0, power: 2));

      final danger = DangerMap.of(world);
      expect(danger.timeToBlast(3, 3), closeTo(kBalloonFuse, 1e-9));
      expect(danger.timeToBlast(5, 3), closeTo(kBalloonFuse, 1e-9));
      expect(danger.isSafe(6, 3), isTrue, reason: '위력 밖은 안전하다');
      expect(danger.isSafe(3, 6), isTrue);
    });

    test('벽 뒤는 안전하다', () {
      final map = openMap();
      map.setTile(5, 3, TileType.wall);
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)], map: map);
      world.balloons.add(Balloon(col: 3, row: 3, ownerId: 0, power: 5));

      final danger = DangerMap.of(world);
      expect(danger.isSafe(6, 3), isTrue);
    });

    test('연쇄를 반영해 더 이른 폭발 시각을 쓴다', () {
      // 늦게 놓인 물풍선이라도 먼저 터지는 물풍선에 닿으면 함께 터진다.
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final early = Balloon(col: 3, row: 3, ownerId: 0, power: 3)..fuse = 0.4;
      final late = Balloon(col: 5, row: 3, ownerId: 0, power: 3);
      world.balloons.addAll([early, late]);

      final danger = DangerMap.of(world);
      expect(danger.timeToBlast(5, 3), closeTo(0.4, 1e-9),
          reason: '연쇄로 함께 터지므로 이른 시각을 따라야 한다');
      expect(danger.timeToBlast(8, 3), closeTo(0.4, 1e-9),
          reason: '연쇄된 물풍선의 사거리도 그 시각에 위험해진다');
    });

    test('놓았다고 가정하고 미리 볼 수 있다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      expect(DangerMap.of(world).isSafe(3, 3), isTrue);

      final hypothetical = Balloon(col: 3, row: 3, ownerId: 0, power: 2);
      final danger = DangerMap.of(world, extraBalloon: hypothetical);
      expect(danger.isSafe(3, 3), isFalse);
      expect(world.balloons, isEmpty, reason: '실제로 놓이면 안 된다');
    });
  });

  group('경로 탐색', () {
    test('막힌 곳을 우회해 걸음 수를 센다', () {
      final map = openMap();
      for (int row = 1; row < 6; row++) {
        map.setTile(5, row, TileType.wall);
      }
      final field = breadthFirst(map.width, map.height, 3, 3,
          (col, row, steps) => !map.isBlocking(col, row));

      expect(field.stepsTo(3, 3), 0);
      expect(field.stepsTo(4, 3), 1);
      expect(field.stepsTo(5, 3), -1, reason: '벽에는 갈 수 없다');
      // 아래로 돌아가야 하므로 직선 거리보다 멀다.
      expect(field.stepsTo(6, 3), greaterThan(3));
    });

    test('목표로 가는 첫 걸음 방향을 알려 준다', () {
      final map = openMap();
      final field = breadthFirst(map.width, map.height, 3, 3,
          (col, row, steps) => !map.isBlocking(col, row));

      expect(field.firstStepTo(6, 3), (1, 0));
      expect(field.firstStepTo(3, 1), (0, -1));
      expect(field.firstStepTo(3, 3), isNull, reason: '이미 도착했다');
    });
  });

  group('봇 행동', () {
    test('자기 물풍선에 스스로 당하지 않는다', () {
      // AI에서 가장 중요한 성질이다. 봇은 상대에게 다가가려면 상자를 부숴야 하고,
      // 그 과정에서 계속 자기 발밑에 물풍선을 놓는다. 대피 판단이 조금이라도
      // 어긋나면 스스로 갇혀 죽는다.
      final failures = <String>[];
      var totalPlacements = 0;

      for (int seed = 0; seed < 12; seed++) {
        final world = GameWorld.stage(random: Random(seed), botCount: 1);
        final bot = world.actors[1];
        final result = runBot(world, bot.id, frames: 3600, seed: seed);
        totalPlacements += result.placements;

        if (result.deadAtFrame >= 0) {
          failures.add('seed $seed: ${result.deadAtFrame}프레임에 자멸');
        }
      }

      expect(failures, isEmpty, reason: failures.join(', '));
      expect(totalPlacements, greaterThan(30),
          reason: '물풍선을 거의 놓지 않았다면 자폭 검증이 무의미하다');
    });

    test('불꽃이 닿을 자리에 있으면 벗어난다', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 1), (col: 12, row: 10, team: 0)],
        withDummyEnemy: false,
      );
      final bot = world.actors[0];
      // 봇이 서 있는 줄을 훑는 물풍선을 옆 칸에 놓는다.
      world.balloons.add(Balloon(col: 5, row: 3, ownerId: 99, power: 3));
      expect(DangerMap.of(world).isSafe(3, 3), isFalse);

      runBot(world, bot.id, frames: (3.5 / kStep).round());

      expect(bot.isBubbled, isFalse, reason: '피하지 못하고 갇혔다');
      expect(bot.isDead, isFalse);
    });

    test('길을 뚫으려고 상자를 부순다', () {
      final world = GameWorld.stage(random: Random(3), botCount: 1);
      var boxesBefore = 0;
      for (int row = 0; row < world.map.height; row++) {
        for (int col = 0; col < world.map.width; col++) {
          if (world.map.tileAt(col, row) == TileType.box) boxesBefore++;
        }
      }

      runBot(world, world.actors[1].id, frames: 1800, seed: 3);

      var boxesAfter = 0;
      for (int row = 0; row < world.map.height; row++) {
        for (int col = 0; col < world.map.width; col++) {
          if (world.map.tileAt(col, row) == TileType.box) boxesAfter++;
        }
      }
      expect(boxesAfter, lessThan(boxesBefore), reason: '상자를 하나도 못 부쉈다');
    });

    test('물방울에 갇힌 동안에는 아무 입력도 내지 않는다', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 1), (col: 12, row: 10, team: 0)],
        withDummyEnemy: false,
      );
      final bot = world.actors[0];
      bot.trapInBubble();

      final brain = BotBrain(world: world, actorId: bot.id, random: Random(1));
      final intent = brain.read();

      expect(intent.isMoving, isFalse);
      expect(intent.placeBalloon, isFalse);
    });

    test('판단 사이에는 물풍선 설치가 반복되지 않는다', () {
      // read()는 프레임마다 불리지만 설치는 판단할 때 한 번만 나가야 한다.
      final world = worldWith(
        spawns: [(col: 1, row: 1, team: 1), (col: 12, row: 10, team: 0)],
        map: openMap()..setTile(2, 1, TileType.box),
        withDummyEnemy: false,
      );
      final bot = world.actors[0];
      final brain = BotBrain(world: world, actorId: bot.id, random: Random(1));

      var placements = 0;
      for (int i = 0; i < 5; i++) {
        if (brain.read().placeBalloon) placements++;
      }
      expect(placements, 1, reason: '같은 판단을 되풀이 읽어도 한 번만 설치해야 한다');
    });
  });
}
