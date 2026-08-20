import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/block_blast_controller.dart';
import '../domain/block_grid.dart';
import 'block_blast_board.dart';
import 'block_tray.dart';

/// 블록 블라스트 게임 화면.
///
/// 8x8 보드에 트레이의 조각을 드래그해 놓고, 가득 찬 행·열을 지워 점수를 얻는다.
/// 상단 셸(MainLayout)이 Scaffold를 제공하므로 여기서는 본문만 구성한다.
class BlockBlastScreen extends StatefulWidget {
  const BlockBlastScreen({super.key});

  @override
  State<BlockBlastScreen> createState() => _BlockBlastScreenState();
}

class _BlockBlastScreenState extends State<BlockBlastScreen> {
  late final BlockBlastController _controller;
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    _controller = BlockBlastController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.isGameOver && !_gameOverDialogShown) {
      _gameOverDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
    } else if (!_controller.isGameOver) {
      _gameOverDialogShown = false;
    }
  }

  void _showGameOverDialog() {
    final isNewRecord = _controller.score >= _controller.highScore;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isNewRecord ? Icons.emoji_events : Icons.flag_rounded,
                color: isNewRecord ? Colors.amber : null, size: 26),
            const SizedBox(width: 8),
            Text(isNewRecord ? '신기록!' : '게임 오버'),
          ],
        ),
        content: Text(
          '놓을 수 있는 조각이 없습니다.\n\n'
          '이번 점수: ${_controller.score}점\n'
          '최고 점수: ${_controller.highScore}점',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _controller.startNewGame();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // 보드와 트레이가 한 화면에 들어오도록 세로 여유를 넉넉히 잡는다.
    final boardSize =
        min(screenSize.width * 0.92, min(screenSize.height * 0.5, 440.0));
    final cellSize = boardSize / kBlockGridSize;

    return ChangeNotifierProvider<BlockBlastController>.value(
      value: _controller,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              _ScoreHeader(controller: _controller, width: boardSize),
              const SizedBox(height: 10),
              BlockBlastBoard(boardSize: boardSize),
              const SizedBox(height: 14),
              SizedBox(
                width: boardSize,
                child: BlockTray(
                  boardCellSize: cellSize,
                  slotSize: boardSize / 3.6,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 점수 · 최고 점수 · 콤보 표시줄
class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.controller, required this.width});

  final BlockBlastController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<BlockBlastController>();

    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScoreChip(
            icon: Icons.stars_rounded,
            label: '점수',
            value: '${state.score}',
            emphasized: true,
          ),
          if (state.comboCount > 1)
            _ScoreChip(
              icon: Icons.local_fire_department_rounded,
              label: '콤보',
              value: 'x${state.comboCount}',
              color: colorScheme.error,
            ),
          _ScoreChip(
            icon: Icons.military_tech_rounded,
            label: '최고',
            value: '${state.highScore}',
          ),
          IconButton.filledTonal(
            tooltip: '새 게임',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              padding: const EdgeInsets.all(8),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: controller.startNewGame,
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = color ?? (emphasized ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 4),
        Text('$label ', style: TextStyle(fontSize: 11, color: fg)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ],
    );
  }
}
