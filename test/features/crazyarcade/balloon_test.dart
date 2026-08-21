import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/domain/balloon.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_actor.dart';
import 'package:sudoku_app/features/crazyarcade/domain/player_intent.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

import 'crazy_arcade_harness.dart';

void main() {
  group('물풍선 설치', () {
    test('선 자리에 설치된다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);

      expect(world.balloons, hasLength(1));
      expect(world.balloonAt(3, 3), isNotNull);
    });

    test('같은 칸에 두 개를 겹쳐 놓을 수 없다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);
      placeBalloonOnce(world, 0);

      expect(world.balloons, hasLength(1));
    });

    test('보유 개수를 넘겨 놓을 수 없다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      expect(actor.maxBalloons, 1);

      placeBalloonOnce(world, 0);
      // 옆 칸으로 이동한 뒤 하나 더 시도한다.
      advance(world, 0.35, intents: {0: const PlayerIntent(moveX: 1)});
      placeBalloonOnce(world, 0);

      expect(world.balloons, hasLength(1), reason: '최대 1개까지만 설치된다');

      actor.maxBalloons = 2;
      placeBalloonOnce(world, 0);
      expect(world.balloons, hasLength(2));
    });

    test('설치한 물풍선에서 빠져나올 수 있지만 다시 올라탈 수는 없다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      placeBalloonOnce(world, 0);

      // 물풍선 위에서 벗어난다.
      advance(world, 0.45, intents: {0: const PlayerIntent(moveX: 1)});
      expect(actor.col, greaterThan(3), reason: '자기가 놓은 물풍선은 통과할 수 있어야 한다');

      // 되돌아가려 하면 이제는 막힌다.
      final xAfterExit = actor.x;
      advance(world, 1.0, intents: {0: const PlayerIntent(moveX: -1)});
      expect(actor.x, lessThanOrEqualTo(xAfterExit));
      expect(actor.x - kActorRadius, greaterThanOrEqualTo(4.0 - 0.01),
          reason: '물풍선 칸(3열)으로는 돌아갈 수 없다');
    });
  });

  group('폭발', () {
    test('심지 시간이 지나면 터진다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);
      expect(world.explosions, isEmpty);

      advance(world, kBalloonFuse + 0.05);

      expect(world.balloons, isEmpty);
      expect(world.explosions, hasLength(1));
      expect(world.explosions.first.covers(3, 3), isTrue);
    });

    test('위력만큼 네 방향으로 뻗는다', () {
      final world = worldWith(spawns: [(col: 7, row: 6, team: 0)]);
      world.actors.first.power = 2;
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + 0.05);

      final blast = world.explosions.first;
      expect(blast.covers(9, 6), isTrue);
      expect(blast.covers(5, 6), isTrue);
      expect(blast.covers(7, 8), isTrue);
      expect(blast.covers(7, 4), isTrue);
      expect(blast.covers(10, 6), isFalse, reason: '위력을 넘어서면 닿지 않는다');
    });

    test('벽에서 멈추고 벽 뒤로는 넘어가지 않는다', () {
      final map = openMap();
      map.setTile(5, 3, TileType.wall);
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)], map: map);
      world.actors.first.power = 5;
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + 0.05);

      final blast = world.explosions.first;
      expect(blast.covers(4, 3), isTrue);
      expect(blast.covers(5, 3), isFalse, reason: '벽 칸에는 불꽃이 놓이지 않는다');
      expect(blast.covers(6, 3), isFalse, reason: '벽 뒤로는 넘어가지 않는다');
    });

    test('상자는 첫 하나만 부수고 멈춘다', () {
      final map = openMap();
      map.setTile(5, 3, TileType.box);
      map.setTile(6, 3, TileType.box);
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)], map: map);
      world.actors.first.power = 5;
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + 0.05);

      expect(world.map.tileAt(5, 3), TileType.empty, reason: '첫 상자는 부서진다');
      expect(world.map.tileAt(6, 3), TileType.box, reason: '그 뒤 상자는 남는다');
      expect(world.explosions.first.covers(5, 3), isTrue);
    });

    test('불꽃이 다른 물풍선에 닿으면 연쇄로 함께 터진다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      actor.maxBalloons = 2;
      actor.power = 2;

      placeBalloonOnce(world, 0);           // (3,3)에 설치
      advance(world, 0.5, intents: {0: const PlayerIntent(moveX: 1)});
      placeBalloonOnce(world, 0);           // 옆 칸에 설치 (심지가 더 늦게 끝난다)
      expect(world.balloons, hasLength(2));

      // 첫 번째 물풍선의 심지만 끝나는 시점까지 진행한다.
      advance(world, kBalloonFuse - 0.4);

      expect(world.balloons, isEmpty, reason: '두 번째 물풍선도 연쇄로 터져야 한다');
      expect(world.explosions, hasLength(2));
    });

    test('폭발 이펙트는 시간이 지나면 사라진다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + 0.05);
      expect(world.explosions, isNotEmpty);

      advance(world, kExplosionLife + 0.05);
      expect(world.explosions, isEmpty);
    });
  });
}
