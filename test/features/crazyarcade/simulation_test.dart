import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_actor.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_world.dart';
import 'package:sudoku_app/features/crazyarcade/domain/player_intent.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

import 'crazy_arcade_harness.dart';

/// 프레임 번호에 따라 정해진 입력을 돌려주는 각본.
/// 무작위가 아니라 재현 가능한 순서여야 결정론 검증이 성립한다.
Map<int, PlayerIntent> scriptedIntents(int frame, int actorCount) {
  final intents = <int, PlayerIntent>{};
  for (int id = 0; id < actorCount; id++) {
    final phase = (frame ~/ 20 + id) % 5;
    intents[id] = switch (phase) {
      0 => const PlayerIntent(moveX: 1),
      1 => const PlayerIntent(moveY: 1),
      2 => const PlayerIntent(moveX: -1, placeBalloon: true),
      3 => const PlayerIntent(moveY: -1),
      _ => PlayerIntent.idle,
    };
  }
  return intents;
}

/// 월드 상태를 비교 가능한 문자열로 만든다.
String snapshot(GameWorld world) {
  final buffer = StringBuffer();
  for (final actor in world.actors) {
    buffer.write('${actor.id}:${actor.x.toStringAsFixed(6)},'
        '${actor.y.toStringAsFixed(6)},${actor.state},'
        '${actor.power},${actor.maxBalloons},${actor.speed}|');
  }
  for (final balloon in world.balloons) {
    buffer.write('B${balloon.col},${balloon.row},${balloon.fuse.toStringAsFixed(6)}|');
  }
  for (final item in world.items) {
    buffer.write('I${item.col},${item.row},${item.type}|');
  }
  for (int row = 0; row < world.map.height; row++) {
    for (int col = 0; col < world.map.width; col++) {
      buffer.write(world.map.tileAt(col, row).index);
    }
  }
  return buffer.toString();
}

void runScript(GameWorld world, int frames) {
  for (int frame = 0; frame < frames; frame++) {
    world.update(kStep, scriptedIntents(frame, world.actors.length));
  }
}

void main() {
  group('GameWorld.stage', () {
    test('플레이어 1명 + 봇 3명이 서로 다른 모서리에서 시작한다', () {
      final world = GameWorld.stage(random: Random(3), botCount: 3);

      expect(world.actors, hasLength(4));
      expect(world.actors.where((a) => a.teamId == 0), hasLength(1));
      expect(world.actors.where((a) => a.teamId == 1), hasLength(3));

      final positions = world.actors.map((a) => (a.x, a.y)).toSet();
      expect(positions, hasLength(4), reason: '스폰 위치가 겹치면 안 된다');
      expect(world.result, GameResult.playing);
    });

    test('봇 수는 스폰 지점 수를 넘지 않는다', () {
      final world = GameWorld.stage(random: Random(3), botCount: 99);
      expect(world.actors.length, lessThanOrEqualTo(TileMap.spawnPoints.length));
    });
  });

  group('결정론', () {
    test('같은 시드와 같은 입력이면 결과가 완전히 같다', () {
      // 이후 단계(렌더링·AI)가 모두 이 성질에 기댄다. 시뮬레이션이 프레임률이나
      // 실행 순서에 흔들리면 버그를 재현할 수 없게 된다.
      final a = GameWorld.stage(random: Random(11), botCount: 3);
      final b = GameWorld.stage(random: Random(11), botCount: 3);

      runScript(a, 600); // 10초
      runScript(b, 600);

      expect(snapshot(a), snapshot(b));
    });

    test('시드가 다르면 맵이 달라진다', () {
      final a = GameWorld.stage(random: Random(1), botCount: 3);
      final b = GameWorld.stage(random: Random(2), botCount: 3);
      expect(snapshot(a), isNot(snapshot(b)));
    });
  });

  group('장시간 안정성', () {
    test('60초를 돌려도 액터가 맵 밖으로 나가거나 벽에 박히지 않는다', () {
      final world = GameWorld.stage(random: Random(5), botCount: 3);

      for (int frame = 0; frame < 3600; frame++) {
        world.update(kStep, scriptedIntents(frame, world.actors.length));

        for (final actor in world.actors) {
          if (actor.isDead) continue;
          expect(actor.x, greaterThan(kActorRadius));
          expect(actor.y, greaterThan(kActorRadius));
          expect(actor.x, lessThan(world.map.width - kActorRadius));
          expect(actor.y, lessThan(world.map.height - kActorRadius));
          expect(world.map.tileAt(actor.col, actor.row), isNot(TileType.wall),
              reason: 'frame $frame: 액터 ${actor.id}가 벽 안에 들어갔다');
        }
      }
    });

    test('물풍선과 폭발이 끝없이 쌓이지 않는다', () {
      final world = GameWorld.stage(random: Random(9), botCount: 3);
      runScript(world, 1800); // 30초

      // 설치 상한이 있으므로 액터 수 x 보유 개수를 넘을 수 없다.
      final cap = world.actors.fold<int>(0, (sum, a) => sum + a.maxBalloons);
      expect(world.balloons.length, lessThanOrEqualTo(cap));
      expect(world.explosions.length, lessThan(100));
    });
  });
}
