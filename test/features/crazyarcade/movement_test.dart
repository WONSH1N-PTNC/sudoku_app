import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_actor.dart';
import 'package:sudoku_app/features/crazyarcade/domain/player_intent.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

import 'crazy_arcade_harness.dart';

void main() {
  group('이동', () {
    test('입력이 없으면 제자리에 있다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      final (x, y) = (actor.x, actor.y);

      advance(world, 1.0);

      expect(actor.x, x);
      expect(actor.y, y);
    });

    test('속도 x 시간만큼 이동한다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      final startX = actor.x;

      advance(world, 0.5, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.x - startX, closeTo(actor.speed * 0.5, 0.05));
      expect(actor.y, 3.5, reason: '가로 이동은 세로 위치를 바꾸지 않는다');
    });

    test('대각선 입력이 축 이동보다 빨라지지 않는다', () {
      final straight = worldWith(spawns: [(col: 6, row: 6, team: 0)]);
      final diagonal = worldWith(spawns: [(col: 6, row: 6, team: 0)]);

      advance(straight, 0.3, intents: {0: const PlayerIntent(moveX: 1)});
      advance(diagonal, 0.3, intents: {0: const PlayerIntent(moveX: 1, moveY: 1)});

      final straightDist = straight.actors.first.x - 6.5;
      final d = diagonal.actors.first;
      final diagonalDist =
          ((d.x - 6.5) * (d.x - 6.5) + (d.y - 6.5) * (d.y - 6.5));
      expect(diagonalDist, lessThanOrEqualTo(straightDist * straightDist + 0.01));
    });

    test('벽을 통과하지 못한다', () {
      final world = worldWith(spawns: [(col: 1, row: 1, team: 0)]);
      final actor = world.actors.first;

      // 왼쪽 테두리 벽을 향해 계속 밀어붙인다.
      advance(world, 2.0, intents: {0: const PlayerIntent(moveX: -1)});

      expect(actor.x, greaterThanOrEqualTo(1.0 + kActorRadius - 0.001));
      expect(world.map.tileAt(0, 1), TileType.wall);
    });

    test('상자에 막힌다', () {
      final map = openMap();
      map.setTile(5, 3, TileType.box);
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)], map: map);
      final actor = world.actors.first;

      advance(world, 2.0, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.x, lessThan(5.0));
      expect(world.map.tileAt(5, 3), TileType.box, reason: '이동으로 상자가 부서지면 안 된다');
    });

    test('통로에 어긋나 있어도 모서리 보정으로 좁은 길에 들어간다', () {
      // 3행만 뚫린 가로 통로를 만들고, 액터를 살짝 어긋나게 둔다.
      final map = openMap();
      for (int col = 4; col < 10; col++) {
        map.setTile(col, 2, TileType.wall);
        map.setTile(col, 4, TileType.wall);
      }
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)], map: map);
      final actor = world.actors.first;
      actor.y = 3.25; // 통로 중앙에서 벗어난 상태

      advance(world, 1.5, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.x, greaterThan(5.0), reason: '보정이 없으면 입구에서 걸려 못 들어간다');
      // 보정은 막혀 있는 동안만 작동하므로 정중앙까지 붙지는 않는다.
      // 통로(3행) 안에 완전히 들어왔는지만 확인하면 충분하다.
      expect(actor.y - kActorRadius, greaterThanOrEqualTo(3.0));
      expect(actor.y + kActorRadius, lessThanOrEqualTo(4.0));
    });

    test('물방울에 갇힌 액터는 움직이지 않는다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      actor.trapInBubble();
      final startX = actor.x;

      advance(world, 0.5, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.x, startX);
    });

    test('이동한 방향을 바라본다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;

      advance(world, 0.2, intents: {0: const PlayerIntent(moveX: 1)});
      expect(actor.facingX, 1);
      expect(actor.facingY, 0);

      advance(world, 0.2, intents: {0: const PlayerIntent(moveY: -1)});
      expect(actor.facingY, -1);

      // 입력을 놓아도 마지막 방향을 유지한다.
      advance(world, 0.2);
      expect(actor.facingY, -1);
    });

    test('벽에 막혀도 바라보는 방향은 바뀐다', () {
      final world = worldWith(spawns: [(col: 1, row: 1, team: 0)]);
      final actor = world.actors.first;

      advance(world, 0.3, intents: {0: const PlayerIntent(moveX: -1)});

      expect(actor.facingX, -1, reason: '벽을 향해도 그쪽을 봐야 한다');
    });
  });
}
