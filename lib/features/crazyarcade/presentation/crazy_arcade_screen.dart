import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controller/crazy_arcade_controller.dart';
import '../domain/game_world.dart';
import 'game_painter.dart';
import 'player_input.dart';
import 'virtual_pad.dart';

/// 이 값보다 화면이 좁으면 가상 패드를 띄운다 (휴대폰 · 태블릿).
const double kVirtualPadBreakpoint = 600;

/// 크레이지 아케이드 게임 화면.
///
/// Ticker로 게임 루프를 돌리고, 렌더링은 [GamePainter]가 프레임 신호를 받아
/// 캔버스만 다시 그린다. 위젯 리빌드는 HUD 값이 실제로 바뀔 때만 일어난다.
class CrazyArcadeScreen extends StatefulWidget {
  const CrazyArcadeScreen({super.key});

  @override
  State<CrazyArcadeScreen> createState() => _CrazyArcadeScreenState();
}

class _CrazyArcadeScreenState extends State<CrazyArcadeScreen>
    with SingleTickerProviderStateMixin {
  late final CrazyArcadeController _controller;
  late final Ticker _ticker;
  final PlayerInputSource _input = PlayerInputSource();

  Duration _lastTick = Duration.zero;
  bool _resultDialogShown = false;

  /// 위젯 테스트에서 실제 게임 상태를 확인하기 위한 통로
  @visibleForTesting
  CrazyArcadeController get controllerForTest => _controller;

  @override
  void initState() {
    super.initState();
    _controller = CrazyArcadeController();
    _controller.inputs[CrazyArcadeController.playerId] = _input;
    _controller.result.addListener(_onResultChanged);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    // 로비로 나가도 루프가 계속 돌면 배터리와 CPU를 먹는다. 반드시 멈춘다.
    _ticker.dispose();
    _controller.result.removeListener(_onResultChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _controller.advanceFrame(dt);
  }

  void _onResultChanged() {
    final result = _controller.result.value;
    if (result == GameResult.playing) {
      _resultDialogShown = false;
      return;
    }
    if (_resultDialogShown) return;
    _resultDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showResultDialog(result);
    });
  }

  void _showResultDialog(GameResult result) {
    final won = result == GameResult.victory;
    _controller.paused = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              won ? Icons.emoji_events : Icons.sentiment_dissatisfied_rounded,
              color: won ? Colors.amber : null,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(won ? '승리!' : '패배'),
          ],
        ),
        content: Text(
          won
              ? '상대를 모두 물리쳤습니다! (${_controller.stats.value.seconds}초)'
              : '물방울에서 빠져나오지 못했습니다.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _controller.paused = false;
              _input.clearHeldInput();
              _controller.restart();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 하기'),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    return _input.handleKeyEvent(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showPad =
        MediaQuery.of(context).size.shortestSide < kVirtualPadBreakpoint;

    return FocusScope(
      autofocus: true,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        // 포커스를 잃으면 키가 눌린 채로 남아 캐릭터가 계속 움직인다.
        onFocusChange: (hasFocus) {
          if (!hasFocus) _input.clearHeldInput();
        },
        child: Stack(
          children: [
            // 게임 캔버스. 프레임 신호로만 다시 그려지고 리빌드되지 않는다.
            Positioned.fill(
              child: CustomPaint(
                painter: GamePainter(
                  controller: _controller,
                  colorScheme: colorScheme,
                  repaint: _controller.frames,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: _Hud(controller: _controller),
            ),
            if (showPad) ...[
              Positioned(
                left: 16,
                bottom: 16,
                child: VirtualJoystick(size: 130, onChanged: _input.setStick),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: BalloonButton(size: 92, onPressed: _input.requestPlace),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 상단 정보 표시줄.
///
/// [CrazyArcadeController.stats]는 레코드라 값이 실제로 바뀔 때만 알림이 나간다.
/// 덕분에 초당 60번이 아니라 능력치나 경과 초가 변할 때만 이 부분이 리빌드된다.
class _Hud extends StatelessWidget {
  const _Hud({required this.controller});

  final CrazyArcadeController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<GameStats>(
      valueListenable: controller.stats,
      builder: (context, stats, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // 좁은 화면에서는 글자 라벨을 접는다. 그대로 두면 넘쳐서 잘린다.
            final compact = constraints.maxWidth < 420;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(
                    icon: Icons.whatshot_rounded,
                    label: '위력',
                    value: '${stats.power}',
                    showLabel: !compact,
                  ),
                  _Stat(
                    icon: Icons.water_drop_rounded,
                    label: '개수',
                    value: '${stats.maxBalloons}',
                    showLabel: !compact,
                  ),
                  _Stat(
                    icon: Icons.person_rounded,
                    label: '남은 상대',
                    value: '${stats.enemiesLeft}',
                    showLabel: !compact,
                  ),
                  _Stat(
                    icon: Icons.timer_outlined,
                    label: '시간',
                    value: '${stats.seconds}s',
                    showLabel: !compact,
                  ),
                  IconButton.filledTonal(
                    tooltip: '새 게임',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: controller.restart,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final String value;

  /// 폭이 모자라면 아이콘과 값만 남긴다.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        if (showLabel)
          Text(
            '$label ',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
