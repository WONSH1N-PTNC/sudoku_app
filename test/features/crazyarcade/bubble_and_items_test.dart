import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/domain/balloon.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_actor.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_world.dart';
import 'package:sudoku_app/features/crazyarcade/domain/item.dart';
import 'package:sudoku_app/features/crazyarcade/domain/player_intent.dart';

import 'crazy_arcade_harness.dart';

void main() {
  group('물방울', () {
    test('불꽃에 닿으면 갇힌다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + 0.05);

      expect(world.actors.first.state, ActorState.bubbled);
      expect(world.actors.first.bubbleTimer, closeTo(kBubbleDuration, 0.1));
    });

    test('제한시간이 지나면 탈락한다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      placeBalloonOnce(world, 0);
      advance(world, kBalloonFuse + kBubbleDuration + 0.2);

      expect(world.actors.first.state, ActorState.dead);
    });

    test('같은 편이 닿으면 구조된다', () {
      final world = worldWith(spawns: [
        (col: 3, row: 3, team: 0),
        (col: 6, row: 3, team: 0),
      ]);
      final victim = world.actors[0];
      final ally = world.actors[1];

      victim.trapInBubble();
      expect(victim.isBubbled, isTrue);

      // 같은 편이 걸어와 물방울을 터뜨린다.
      advance(world, 1.5, intents: {1: const PlayerIntent(moveX: -1)});

      expect(victim.state, ActorState.alive, reason: '아군 접촉으로 부활해야 한다');
      expect(ally.isAlive, isTrue);
    });

    test('다른 편이 닿으면 즉시 탈락한다', () {
      final world = worldWith(spawns: [
        (col: 3, row: 3, team: 0),
        (col: 6, row: 3, team: 1),
      ]);
      final victim = world.actors[0];
      victim.trapInBubble();

      advance(world, 1.5, intents: {1: const PlayerIntent(moveX: -1)});

      expect(victim.state, ActorState.dead, reason: '적 접촉은 마무리 공격이다');
    });

    test('갇힌 동안에는 물풍선을 놓을 수 없다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      world.actors.first.trapInBubble();

      placeBalloonOnce(world, 0);

      expect(world.balloons, isEmpty);
    });
  });

  group('아이템', () {
    test('밟으면 효과가 적용되고 사라진다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      world.items.add(Item(col: 5, row: 3, type: ItemType.power));
      final beforePower = actor.power;

      advance(world, 1.0, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.power, beforePower + 1);
      expect(world.items, isEmpty);
    });

    test('종류별로 다른 능력치가 오른다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      final beforeSpeed = actor.speed;
      final beforeCount = actor.maxBalloons;

      world.items.add(Item(col: 4, row: 3, type: ItemType.speed));
      advance(world, 0.6, intents: {0: const PlayerIntent(moveX: 1)});
      expect(actor.speed, greaterThan(beforeSpeed));

      world.items.add(Item(col: 6, row: 3, type: ItemType.count));
      advance(world, 1.0, intents: {0: const PlayerIntent(moveX: 1)});
      expect(actor.maxBalloons, beforeCount + 1);
    });

    test('능력치는 상한을 넘지 않는다', () {
      final world = worldWith(spawns: [(col: 3, row: 3, team: 0)]);
      final actor = world.actors.first;
      actor.power = kMaxPower;
      world.items.add(Item(col: 4, row: 3, type: ItemType.power));

      advance(world, 0.6, intents: {0: const PlayerIntent(moveX: 1)});

      expect(actor.power, kMaxPower);
    });
  });

  group('승패', () {
    test('적이 모두 탈락하면 승리', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 0), (col: 9, row: 9, team: 1)],
        withDummyEnemy: false,
      );
      expect(world.result, GameResult.playing);

      world.actors[1].eliminate();
      expect(world.result, GameResult.victory);
    });

    test('플레이어 팀이 모두 탈락하면 패배', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 0), (col: 9, row: 9, team: 1)],
        withDummyEnemy: false,
      );

      world.actors[0].eliminate();
      expect(world.result, GameResult.defeat);
    });

    test('갇혀 있을 뿐이면 아직 진행 중이다', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 0), (col: 9, row: 9, team: 1)],
        withDummyEnemy: false,
      );

      world.actors[0].trapInBubble();
      expect(world.result, GameResult.playing,
          reason: '구조될 수 있으므로 패배가 아니다');
    });

    test('승부가 끝나면 시뮬레이션이 멈춘다', () {
      final world = worldWith(
        spawns: [(col: 3, row: 3, team: 0), (col: 9, row: 9, team: 1)],
        withDummyEnemy: false,
      );
      world.actors[1].eliminate();
      final x = world.actors[0].x;

      advance(world, 1.0, intents: {0: const PlayerIntent(moveX: 1)});

      expect(world.actors[0].x, x);
    });
  });
}
