import 'dart:math';

import 'balloon.dart';
import 'game_actor.dart';
import 'item.dart';
import 'player_intent.dart';
import 'tile_map.dart';

/// 한 판의 진행 상태
enum GameResult { playing, victory, defeat }

/// 상자를 부쉈을 때 아이템이 나올 확률
const double kItemDropChance = 0.32;

/// 크레이지 아케이드 한 판의 시뮬레이션.
///
/// Flutter에 의존하지 않는 순수 Dart이며, [update]를 고정 timestep으로 반복
/// 호출하는 것만으로 게임이 진행된다. 렌더링·입력 장치와 완전히 분리되어 있어
/// 각본대로 [PlayerIntent]를 주입하면 결정론적으로 테스트할 수 있다.
class GameWorld {
  GameWorld({
    required this.map,
    required this.actors,
    required Random random,
    this.playerTeamId = 0,
  }) : _random = random;

  /// 기본 스테이지에 플레이어 1명과 봇 [botCount]명을 각 모서리에 배치한다.
  factory GameWorld.stage({required Random random, int botCount = 3}) {
    final map = TileMap.stage(random);
    final actors = <Actor>[];
    final spawns = TileMap.spawnPoints;
    final count = (botCount + 1).clamp(1, spawns.length);

    for (int i = 0; i < count; i++) {
      final (col, row) = spawns[i];
      actors.add(Actor(
        id: i,
        teamId: i == 0 ? 0 : 1, // 0번이 플레이어, 나머지는 적 팀
        x: col + 0.5,
        y: row + 0.5,
      ));
    }
    return GameWorld(map: map, actors: actors, random: random);
  }

  final TileMap map;
  final List<Actor> actors;
  final Random _random;

  /// 이 팀이 전멸하면 패배, 나머지 팀이 전멸하면 승리
  final int playerTeamId;

  final List<Balloon> balloons = [];
  final List<Explosion> explosions = [];
  final List<Item> items = [];

  /// 시작 후 경과 시간 (초)
  double elapsed = 0;

  Actor? actorById(int id) {
    for (final actor in actors) {
      if (actor.id == id) return actor;
    }
    return null;
  }

  Balloon? balloonAt(int col, int row) {
    for (final balloon in balloons) {
      if (balloon.col == col && balloon.row == row) return balloon;
    }
    return null;
  }

  Item? itemAt(int col, int row) {
    for (final item in items) {
      if (item.col == col && item.row == row) return item;
    }
    return null;
  }

  GameResult get result {
    final allyLeft =
        actors.any((a) => a.teamId == playerTeamId && !a.isDead);
    final enemyLeft =
        actors.any((a) => a.teamId != playerTeamId && !a.isDead);
    if (!allyLeft) return GameResult.defeat;
    if (!enemyLeft) return GameResult.victory;
    return GameResult.playing;
  }

  /// 시뮬레이션을 [dt]초만큼 전진시킨다.
  ///
  /// [intents]는 액터 id별 이번 프레임 입력이며, 빠진 액터는 [PlayerIntent.idle]로 본다.
  /// 순서가 중요하다. 폭발을 먼저 처리해야 같은 프레임에 설치된 물풍선이
  /// 곧바로 연쇄에 휘말리는 일이 없고, 피해 판정을 마지막에 두어야
  /// 이동으로 불꽃에 뛰어든 액터가 같은 프레임에 판정된다.
  void update(double dt, Map<int, PlayerIntent> intents) {
    if (result != GameResult.playing) return;
    elapsed += dt;

    _advanceBalloons(dt);
    _advanceExplosions(dt);
    _updateBalloonPassability();
    _moveActors(dt, intents);
    _placeBalloons(intents);
    _pickUpItems();
    _applyExplosionDamage();
    _advanceBubbles(dt);
  }

  // ── 물풍선 · 폭발 ──────────────────────────────────────────────

  /// 심지를 태우고, 다 탄 물풍선을 연쇄까지 포함해 터뜨린다.
  void _advanceBalloons(double dt) {
    for (final balloon in balloons) {
      balloon.fuse -= dt;
    }

    final queue = balloons.where((b) => b.fuse <= 0).toList();
    while (queue.isNotEmpty) {
      final balloon = queue.removeAt(0);
      // 이미 다른 연쇄로 처리된 물풍선은 건너뛴다.
      if (!balloons.remove(balloon)) continue;
      final cells = _explosionCells(balloon, queue.add);
      explosions.add(Explosion(cells: cells, ownerId: balloon.ownerId));
    }
  }

  /// 폭발이 덮는 칸을 계산한다. 상자는 첫 하나만 부수고 멈추며,
  /// 다른 물풍선에 닿으면 [chain]으로 넘겨 즉시 연쇄시킨다.
  List<(int, int)> _explosionCells(Balloon balloon, void Function(Balloon) chain) {
    final cells = <(int, int)>[(balloon.col, balloon.row)];
    const directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];

    for (final (dc, dr) in directions) {
      for (int step = 1; step <= balloon.power; step++) {
        final col = balloon.col + dc * step;
        final row = balloon.row + dr * step;
        if (!map.inBounds(col, row)) break;

        final tile = map.tileAt(col, row);
        if (tile == TileType.wall) break;

        if (tile == TileType.box) {
          map.breakBox(col, row);
          _maybeDropItem(col, row);
          cells.add((col, row));
          break; // 상자 뒤로는 불꽃이 뻗지 않는다
        }

        cells.add((col, row));

        final other = balloonAt(col, row);
        if (other != null) {
          chain(other);
          break;
        }
      }
    }
    return cells;
  }

  void _maybeDropItem(int col, int row) {
    if (_random.nextDouble() >= kItemDropChance) return;
    final type = ItemType.values[_random.nextInt(ItemType.values.length)];
    items.add(Item(col: col, row: row, type: type));
  }

  void _advanceExplosions(double dt) {
    for (final explosion in explosions) {
      explosion.life -= dt;
    }
    explosions.removeWhere((explosion) => explosion.life <= 0);
  }

  /// 물풍선 위에서 완전히 벗어난 액터는 통과 권한을 잃는다.
  void _updateBalloonPassability() {
    for (final balloon in balloons) {
      balloon.passableActorIds.removeWhere((id) {
        final actor = actorById(id);
        return actor == null || !_overlapsCell(actor, balloon.col, balloon.row);
      });
    }
  }

  // ── 이동 · 충돌 ────────────────────────────────────────────────

  /// 액터의 사각 판정 영역이 (col, row) 칸과 겹치는지
  bool _overlapsCell(Actor actor, int col, int row) {
    return actor.x + kActorRadius > col &&
        actor.x - kActorRadius < col + 1 &&
        actor.y + kActorRadius > row &&
        actor.y - kActorRadius < row + 1;
  }

  /// (nx, ny)로 옮겼을 때 벽 · 상자 · 물풍선에 걸리지 않는지
  bool _canOccupy(Actor actor, double nx, double ny) {
    final colMin = (nx - kActorRadius).floor();
    final colMax = (nx + kActorRadius).floor();
    final rowMin = (ny - kActorRadius).floor();
    final rowMax = (ny + kActorRadius).floor();

    for (int row = rowMin; row <= rowMax; row++) {
      for (int col = colMin; col <= colMax; col++) {
        if (map.isBlocking(col, row)) return false;
        final balloon = balloonAt(col, row);
        if (balloon != null && !balloon.passableActorIds.contains(actor.id)) {
          return false;
        }
      }
    }
    return true;
  }

  void _moveActors(double dt, Map<int, PlayerIntent> intents) {
    for (final actor in actors) {
      if (!actor.canAct) continue;
      final intent = (intents[actor.id] ?? PlayerIntent.idle).normalized();
      if (!intent.isMoving) continue;

      final step = actor.speed * dt;

      if (intent.moveX != 0) {
        final nx = actor.x + intent.moveX * step;
        if (_canOccupy(actor, nx, actor.y)) {
          actor.x = nx;
        } else {
          _slipTowardLane(actor, step, horizontal: true);
        }
      }

      if (intent.moveY != 0) {
        final ny = actor.y + intent.moveY * step;
        if (_canOccupy(actor, actor.x, ny)) {
          actor.y = ny;
        } else {
          _slipTowardLane(actor, step, horizontal: false);
        }
      }
    }
  }

  /// 통로에 살짝 어긋나 모서리에 걸렸을 때 통로 중앙 쪽으로 보정한다.
  ///
  /// 이 보정이 없으면 칸에 정확히 정렬되지 않은 상태로는 좁은 통로에 들어가지
  /// 못해 조작이 답답해진다. 원작에서 모서리를 스치듯 도는 감각을 만든다.
  void _slipTowardLane(Actor actor, double step, {required bool horizontal}) {
    // 가로로 막혔으면 세로 위치를, 세로로 막혔으면 가로 위치를 정렬한다.
    final current = horizontal ? actor.y : actor.x;
    final laneCenter = current.floor() + 0.5;
    final delta = laneCenter - current;
    if (delta.abs() < 1e-6) return;

    final move = delta.abs() < step ? delta : step * (delta < 0 ? -1 : 1);
    final nx = horizontal ? actor.x : actor.x + move;
    final ny = horizontal ? actor.y + move : actor.y;
    if (_canOccupy(actor, nx, ny)) {
      actor.x = nx;
      actor.y = ny;
    }
  }

  // ── 설치 · 아이템 · 피해 ───────────────────────────────────────

  void _placeBalloons(Map<int, PlayerIntent> intents) {
    for (final actor in actors) {
      if (!actor.canAct) continue;
      final intent = intents[actor.id] ?? PlayerIntent.idle;
      if (!intent.placeBalloon) continue;

      final col = actor.col;
      final row = actor.row;
      if (map.isBlocking(col, row)) continue;
      if (balloonAt(col, row) != null) continue;

      final active = balloons.where((b) => b.ownerId == actor.id).length;
      if (active >= actor.maxBalloons) continue;

      final balloon = Balloon(
        col: col,
        row: row,
        ownerId: actor.id,
        power: actor.power,
      );
      // 설치 순간 겹쳐 있던 액터는 물풍선에서 빠져나올 수 있어야 한다.
      for (final other in actors) {
        if (_overlapsCell(other, col, row)) {
          balloon.passableActorIds.add(other.id);
        }
      }
      balloons.add(balloon);
    }
  }

  void _pickUpItems() {
    items.removeWhere((item) {
      for (final actor in actors) {
        if (!actor.canAct) continue;
        if (actor.col != item.col || actor.row != item.row) continue;
        _applyItem(actor, item.type);
        return true;
      }
      return false;
    });
  }

  void _applyItem(Actor actor, ItemType type) {
    switch (type) {
      case ItemType.power:
        actor.power = (actor.power + 1).clamp(1, kMaxPower);
      case ItemType.count:
        actor.maxBalloons = (actor.maxBalloons + 1).clamp(1, kMaxBalloons);
      case ItemType.speed:
        actor.speed = (actor.speed + kSpeedIncrement).clamp(kBaseSpeed, kMaxSpeed);
    }
  }

  /// 불꽃에 닿은 액터를 물방울에 가둔다. 중심이 올라간 칸으로 판정한다.
  void _applyExplosionDamage() {
    if (explosions.isEmpty) return;
    for (final actor in actors) {
      if (!actor.isAlive) continue;
      final hit = explosions.any((e) => e.covers(actor.col, actor.row));
      if (hit) actor.trapInBubble();
    }
  }

  /// 물방울 시간을 줄이고, 접촉에 따른 구조 · 탈락을 처리한다.
  void _advanceBubbles(double dt) {
    for (final trapped in actors) {
      if (!trapped.isBubbled) continue;

      // 접촉 판정을 먼저 한다. 같은 편이 닿으면 구조, 다른 편이면 즉시 탈락.
      Actor? rescuer;
      Actor? finisher;
      for (final other in actors) {
        if (other.id == trapped.id || !other.isAlive) continue;
        if (!_actorsOverlap(trapped, other)) continue;
        if (other.teamId == trapped.teamId) {
          rescuer = other;
        } else {
          finisher = other;
        }
      }

      if (rescuer != null) {
        trapped.rescue();
        continue;
      }
      if (finisher != null) {
        trapped.eliminate();
        continue;
      }

      trapped.bubbleTimer -= dt;
      if (trapped.bubbleTimer <= 0) trapped.eliminate();
    }
  }

  bool _actorsOverlap(Actor a, Actor b) {
    return (a.x - b.x).abs() < kActorRadius * 2 &&
        (a.y - b.y).abs() < kActorRadius * 2;
  }
}
