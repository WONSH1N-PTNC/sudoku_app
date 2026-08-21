import 'dart:math';

import '../domain/balloon.dart';
import '../domain/blast.dart';
import '../domain/game_actor.dart';
import '../domain/game_world.dart';
import '../domain/input_source.dart';
import '../domain/player_intent.dart';
import '../domain/tile_map.dart';
import 'danger_map.dart';
import 'grid_path.dart';

/// 대피 경로를 고를 때 남겨 두는 여유 시간 (초).
///
/// 도착 시각과 폭발 시각이 딱 맞으면 실제로는 걸린다. 모서리 보정이나
/// 미세한 속도 차이를 감안해 이만큼 먼저 도착할 수 있는 칸만 안전하다고 본다.
const double kEscapeMargin = 0.35;

/// 봇이 판단을 다시 내리는 간격 (초).
/// 매 프레임 다시 계산하면 낭비이고, 사람처럼 약간의 반응 지연도 생긴다.
const double kThinkInterval = 0.12;

/// 대피 시간을 계산할 때 실제 속도를 이만큼으로 낮춰 잡는다.
///
/// 경로 탐색은 칸에서 칸으로 곧장 걷는다고 보지만, 실제로는 판단 간격 동안
/// 같은 방향으로 밀고 가느라 코너에서 시간을 흘리고 모서리 보정 중에는
/// 전진이 멈춘다. 넉넉하게 잡지 않으면 봇이 아슬아슬하게 늦어 자멸한다.
const double kSpeedSafetyFactor = 0.7;

/// 크레이지 아케이드 AI 봇.
///
/// 키보드나 가상 패드와 똑같이 [PlayerIntent]만 만들어 낸다. 시뮬레이션은
/// 이것이 사람인지 봇인지 알지 못한다.
///
/// 판단 우선순위는 단순하다.
/// 1. 지금 서 있는 칸이 위험하면 무조건 대피한다.
/// 2. 놓을 값어치가 있고 놓고도 살아 나갈 수 있으면 물풍선을 놓는다.
/// 3. 아이템 → 적 → 상자 순으로 목표를 정해 이동한다.
class BotBrain implements InputSource {
  BotBrain({
    required this.world,
    required this.actorId,
    Random? random,
    this.thinkInterval = kThinkInterval,
  }) : _random = random ?? Random();

  final GameWorld world;
  final int actorId;
  final Random _random;
  final double thinkInterval;

  double _lastThinkAt = double.negativeInfinity;
  PlayerIntent _plan = PlayerIntent.idle;

  /// 대피 중 목표로 삼은 안전한 칸.
  ///
  /// 판단마다 가장 가까운 안전 칸을 새로 고르면 목표가 계속 바뀌어 제자리에서
  /// 흔들린다. 한 번 정한 대피처는 도착하거나 위험해질 때까지 지킨다.
  (int, int)? _refuge;

  @override
  PlayerIntent read() {
    final me = world.actorById(actorId);
    if (me == null || !me.canAct) return PlayerIntent.idle;

    if (world.elapsed - _lastThinkAt < thinkInterval) {
      // 같은 판단을 되풀이 읽어도 물풍선이 연발되지 않도록 설치는 뺀다.
      return PlayerIntent(moveX: _plan.moveX, moveY: _plan.moveY);
    }
    _lastThinkAt = world.elapsed;
    _plan = _decide(me);
    return _plan;
  }

  PlayerIntent _decide(Actor me) {
    final danger = DangerMap.of(world);

    // 1. 발밑이 위험하면 다른 무엇보다 대피가 먼저다.
    if (!danger.isSafe(me.col, me.row)) {
      return _escape(me, danger) ?? PlayerIntent.idle;
    }
    _refuge = null; // 안전해졌으니 대피처를 놓아 준다.

    // 2. 놓을 값어치가 있고 살아 나갈 수 있을 때만 놓는다.
    if (_isWorthPlacing(me) && _canEscapeAfterPlacing(me)) {
      return const PlayerIntent(placeBalloon: true);
    }

    // 3. 목표를 향해 이동한다.
    return _approach(me, danger) ?? PlayerIntent.idle;
  }

  /// 봇이 밟고 지나갈 수 있는 칸인지 (벽 · 상자 · 물풍선은 통과 불가)
  bool _walkable(int col, int row) {
    if (world.map.isBlocking(col, row)) return false;
    return world.balloonAt(col, row) == null;
  }

  /// 도착 시각보다 늦게 터지는 칸만 지나가는 탐색.
  ///
  /// 이 탐색으로 닿은 칸은 실제로 걸어가도 불꽃에 휘말리지 않는다.
  /// [extraDelay]는 출발까지 걸리는 시간이다. 물풍선을 놓는 판단을 할 때는
  /// 다음 판단이 와야 비로소 달아나기 시작하므로 그만큼을 더해 둔다.
  PathField _safeField(Actor me, DangerMap danger, {double extraDelay = 0}) {
    final speed = (me.speed <= 0 ? kBaseSpeed : me.speed) * kSpeedSafetyFactor;
    return breadthFirst(
      world.map.width,
      world.map.height,
      me.col,
      me.row,
      (col, row, steps) {
        if (!_walkable(col, row)) return false;
        final arrival = extraDelay + steps / speed;
        return danger.timeToBlast(col, row) > arrival + kEscapeMargin;
      },
    );
  }

  /// 안전한 칸으로 한 걸음.
  ///
  /// 한 번 정한 대피처는 계속 지킨다. 판단마다 새로 고르면 후보가 엎치락뒤치락하며
  /// 제자리에서 떨다가 불꽃에 휘말린다.
  PlayerIntent? _escape(Actor me, DangerMap danger) {
    final field = _safeField(me, danger);

    final held = _refuge;
    if (held != null &&
        danger.isSafe(held.$1, held.$2) &&
        field.canReach(held.$1, held.$2)) {
      final step = _stepToward(field, held);
      if (step != null) return step;
    }

    final refuge = field.nearestWhere((col, row) => danger.isSafe(col, row));
    _refuge = refuge;
    if (refuge == null) return null;
    return _stepToward(field, refuge);
  }

  /// 지금 자리에 놓으면 상자를 부수거나 적을 노릴 수 있는가
  bool _isWorthPlacing(Actor me) {
    if (world.balloonAt(me.col, me.row) != null) return false;
    final active = world.balloons.where((b) => b.ownerId == me.id).length;
    if (active >= me.maxBalloons) return false;

    final cells = blastCells(
      world.map,
      me.col,
      me.row,
      me.power,
      hasBalloon: (col, row) => world.balloonAt(col, row) != null,
    );

    for (final (col, row) in cells) {
      if (world.map.tileAt(col, row) == TileType.box) return true;
      for (final other in world.actors) {
        if (other.id == me.id || other.teamId == me.teamId) continue;
        if (!other.isAlive) continue;
        if (other.col == col && other.row == row) return true;
      }
    }
    return false;
  }

  /// 여기에 놓았다고 가정했을 때 빠져나갈 안전한 칸이 있는지 미리 확인한다.
  /// 봇이 자기 물풍선에 갇히지 않는 이유가 이 검사다.
  bool _canEscapeAfterPlacing(Actor me) {
    final hypothetical = Balloon(
      col: me.col,
      row: me.row,
      ownerId: me.id,
      power: me.power,
    );
    final danger = DangerMap.of(world, extraBalloon: hypothetical);
    // 놓기로 결정한 프레임에는 제자리에 서 있고, 다음 판단이 와야 달아나기 시작한다.
    final field = _safeField(me, danger, extraDelay: thinkInterval * 2);
    return field.nearestWhere((col, row) => danger.isSafe(col, row)) != null;
  }

  /// 아이템 → 적 → 상자 옆 순으로 목표를 정해 한 걸음 옮긴다.
  PlayerIntent? _approach(Actor me, DangerMap danger) {
    final field = _safeField(me, danger);

    final item = field.nearestWhere((col, row) => world.itemAt(col, row) != null);
    if (item != null) return _stepToward(field, item);

    final enemy = field.nearestWhere((col, row) {
      for (final other in world.actors) {
        if (other.teamId == me.teamId || !other.isAlive) continue;
        if (other.col == col && other.row == row) return true;
      }
      return false;
    });
    if (enemy != null) return _stepToward(field, enemy);

    final besideBox = field.nearestWhere(_isNextToBox);
    if (besideBox != null) return _stepToward(field, besideBox);

    return _wander(field);
  }

  bool _isNextToBox(int col, int row) {
    const directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];
    for (final (dc, dr) in directions) {
      if (world.map.tileAt(col + dc, row + dr) == TileType.box) return true;
    }
    return false;
  }

  /// 목표가 없을 때 제자리에 굳지 않도록 갈 수 있는 곳으로 흩어진다.
  PlayerIntent? _wander(PathField field) {
    final candidates = <(int, int)>[];
    for (int row = 0; row < world.map.height; row++) {
      for (int col = 0; col < world.map.width; col++) {
        final steps = field.stepsTo(col, row);
        if (steps > 0 && steps <= 6) candidates.add((col, row));
      }
    }
    if (candidates.isEmpty) return null;
    return _stepToward(field, candidates[_random.nextInt(candidates.length)]);
  }

  PlayerIntent? _stepToward(PathField field, (int, int) target) {
    final step = field.firstStepTo(target.$1, target.$2);
    if (step == null) return null;
    return PlayerIntent(
      moveX: step.$1.toDouble(),
      moveY: step.$2.toDouble(),
    );
  }
}
