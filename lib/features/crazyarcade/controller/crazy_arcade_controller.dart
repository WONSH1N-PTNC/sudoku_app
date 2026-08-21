import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/bot_brain.dart';
import '../domain/game_actor.dart';
import '../domain/game_world.dart';
import '../domain/input_source.dart';
import '../domain/player_intent.dart';

/// 시뮬레이션 고정 timestep (60Hz).
///
/// 프레임률이 흔들려도 같은 입력이면 같은 결과가 나오도록 항상 이 간격으로만
/// 시뮬레이션을 전진시킨다. 도메인 테스트가 기대는 성질이기도 하다.
const double kFixedStep = 1 / 60;

/// 한 프레임에 반영할 수 있는 최대 시간.
/// 탭을 다시 활성화했을 때 큰 dt가 들어와 한 번에 수십 프레임이 돌지 않게 막는다.
const double kMaxFrameDelta = 0.25;

/// HUD에 표시할 값들. 레코드라 값이 실제로 바뀔 때만 알림이 나간다.
typedef GameStats = ({
  int power,
  int maxBalloons,
  int enemiesLeft,
  int seconds,
  ActorState playerState,
});

/// 게임 루프를 돌리고 화면과 시뮬레이션을 이어 준다.
///
/// 렌더링은 [frames]를 구독하는 CustomPainter가 담당하므로 프레임마다
/// 위젯이 리빌드되지 않는다. HUD처럼 실제로 값이 변할 때만 갱신하면 되는 것은
/// [stats]를 쓴다.
class CrazyArcadeController {
  CrazyArcadeController({Random? random, this.botCount = 3})
      : _random = random ?? Random() {
    _startWorld();
  }

  final Random _random;
  final int botCount;

  late GameWorld world;

  /// 플레이어 액터 id (0번 고정)
  static const int playerId = 0;

  final _FrameNotifier _frames = _FrameNotifier();

  /// 프레임마다 발신. CustomPainter의 repaint에 연결한다.
  Listenable get frames => _frames;

  late final ValueNotifier<GameResult> result =
      ValueNotifier(GameResult.playing);

  late final ValueNotifier<GameStats> stats = ValueNotifier(_readStats());

  /// 액터 id별 입력 소스. 아직 AI가 없는 봇은 IdleInputSource로 둔다.
  final Map<int, InputSource> inputs = {};

  /// 설치 요청은 한 프레임에 소비되지 않을 수 있으므로 처리될 때까지 들고 있는다.
  final Map<int, bool> _pendingPlace = {};

  double _accumulator = 0;
  bool paused = false;

  void _startWorld() {
    world = GameWorld.stage(random: _random, botCount: botCount);
    _accumulator = 0;
    _pendingPlace.clear();
    for (final actor in world.actors) {
      if (actor.id == playerId) {
        // 플레이어 입력 소스는 화면이 붙여 주므로 덮어쓰지 않는다.
        inputs.putIfAbsent(actor.id, () => const IdleInputSource());
      } else {
        // 봇의 두뇌는 월드를 참조하므로 새 판마다 새로 만들어야 한다.
        inputs[actor.id] =
            BotBrain(world: world, actorId: actor.id, random: _random);
      }
    }
  }

  Actor? get player => world.actorById(playerId);

  void restart() {
    _startWorld();
    result.value = GameResult.playing;
    stats.value = _readStats();
    _frames.tick();
  }

  /// 실제 경과 시간 [dt]만큼 게임을 전진시킨다. Ticker가 매 프레임 호출한다.
  void advanceFrame(double dt) {
    if (paused || result.value != GameResult.playing) return;

    // 입력은 프레임마다 한 번만 읽는다. 설치 요청은 실제로 반영될 때까지 유지된다.
    final axes = <int, PlayerIntent>{};
    for (final actor in world.actors) {
      final intent = (inputs[actor.id] ?? const IdleInputSource()).read();
      axes[actor.id] = intent;
      if (intent.placeBalloon) _pendingPlace[actor.id] = true;
    }

    _accumulator += dt.clamp(0.0, kMaxFrameDelta);
    while (_accumulator >= kFixedStep) {
      world.update(kFixedStep, _buildIntents(axes));
      _pendingPlace.clear(); // 설치는 한 번만 반영한다
      _accumulator -= kFixedStep;
    }

    _frames.tick();
    stats.value = _readStats();
    result.value = world.result;
  }

  Map<int, PlayerIntent> _buildIntents(Map<int, PlayerIntent> axes) {
    return axes.map((id, intent) => MapEntry(
          id,
          PlayerIntent(
            moveX: intent.moveX,
            moveY: intent.moveY,
            placeBalloon: _pendingPlace[id] ?? false,
          ),
        ));
  }

  GameStats _readStats() {
    final me = world.actorById(playerId);
    return (
      power: me?.power ?? 0,
      maxBalloons: me?.maxBalloons ?? 0,
      enemiesLeft:
          world.actors.where((a) => a.teamId != world.playerTeamId && !a.isDead).length,
      seconds: world.elapsed.floor(),
      playerState: me?.state ?? ActorState.dead,
    );
  }

  void dispose() {
    _frames.dispose();
    result.dispose();
    stats.dispose();
  }
}

/// 프레임 신호만 전달하는 최소 Listenable
class _FrameNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}
