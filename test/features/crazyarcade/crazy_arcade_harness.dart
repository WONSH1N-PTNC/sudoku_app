import 'dart:math';

import 'package:sudoku_app/features/crazyarcade/domain/game_actor.dart';
import 'package:sudoku_app/features/crazyarcade/domain/game_world.dart';
import 'package:sudoku_app/features/crazyarcade/domain/player_intent.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

/// 시뮬레이션 고정 timestep (60Hz). 프레임률과 무관하게 결과가 같아야 한다.
const double kStep = 1 / 60;

/// 테두리 벽만 있고 안쪽은 전부 빈 맵. 규칙을 하나씩 떼어 보기 좋다.
TileMap openMap({int width = kMapWidth, int height = kMapHeight}) {
  final map = TileMap.filled(width, height);
  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      final isBorder =
          col == 0 || row == 0 || col == width - 1 || row == height - 1;
      if (isBorder) map.setTile(col, row, TileType.wall);
    }
  }
  return map;
}

/// 지정한 위치에 액터를 둔 월드를 만든다. 좌표는 칸의 중앙에 맞춘다.
///
/// 적 팀 액터가 하나도 없으면 GameWorld가 곧바로 승리로 판정해 시뮬레이션이
/// 멈춰 버린다. 그래서 기본적으로 맵 반대편 구석에 관전용 적을 하나 세워 둔다.
/// 액터 수나 승패 자체를 검증하는 테스트는 [withDummyEnemy]를 꺼서 쓴다.
GameWorld worldWith({
  required List<({int col, int row, int team})> spawns,
  TileMap? map,
  int seed = 1,
  bool withDummyEnemy = true,
}) {
  final actors = <Actor>[];
  for (int i = 0; i < spawns.length; i++) {
    final spawn = spawns[i];
    actors.add(Actor(
      id: i,
      teamId: spawn.team,
      x: spawn.col + 0.5,
      y: spawn.row + 0.5,
    ));
  }
  final needsEnemy = withDummyEnemy && !actors.any((a) => a.teamId != 0);
  if (needsEnemy) {
    actors.add(Actor(
      id: 999,
      teamId: 1,
      x: kMapWidth - 2 + 0.5,
      y: kMapHeight - 2 + 0.5,
    ));
  }
  return GameWorld(
    map: map ?? openMap(),
    actors: actors,
    random: Random(seed),
  );
}

/// [seconds]초 동안 같은 입력을 유지하며 고정 timestep으로 시뮬레이션한다.
void advance(
  GameWorld world,
  double seconds, {
  Map<int, PlayerIntent> intents = const {},
}) {
  final steps = (seconds / kStep).round();
  for (int i = 0; i < steps; i++) {
    world.update(kStep, intents);
  }
}

/// 물풍선 설치는 한 프레임만 true여야 한다 (누르고 있어도 연발되지 않도록).
void placeBalloonOnce(GameWorld world, int actorId) {
  world.update(kStep, {actorId: const PlayerIntent(placeBalloon: true)});
}
