import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controller/sudoku_controller.dart';
import '../domain/difficulty.dart';
import '../domain/sudoku_rules.dart';
import 'sudoku_board.dart';

/// 스도쿠 게임 화면.
///
/// [SudokuController]를 자체적으로 생성 · 소유하며, 상단 셸(MainLayout)이
/// Scaffold와 네비게이션 바를 제공하므로 여기서는 본문 콘텐츠만 구성한다.
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late final SudokuController _controller;
  bool _completionDialogShown = false;

  // 숫자키(숫자패드 포함) → 입력할 숫자 매핑.
  // LogicalKeyboardKey는 커스텀 ==/hashCode를 가져 const map의 키로 쓸 수 없으므로 static final로 선언한다.
  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit1: 1, LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.digit2: 2, LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.digit3: 3, LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.digit4: 4, LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.digit5: 5, LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.digit6: 6, LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.digit7: 7, LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.digit8: 8, LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.digit9: 9, LogicalKeyboardKey.numpad9: 9,
  };

  // 방향키 → (행 증분, 열 증분). LogicalKeyboardKey는 const map 키로 쓸 수 없어 static final로 둔다.
  static final Map<LogicalKeyboardKey, (int, int)> _arrowKeys = {
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
  };

  @override
  void initState() {
    super.initState();
    _controller = SudokuController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 완료 상태로 전환되는 순간을 감지해 축하 다이얼로그를 한 번만 띄운다.
  void _onControllerChanged() {
    if (_controller.isCompleted && !_completionDialogShown) {
      _completionDialogShown = true;
      // notifyListeners()가 빌드 도중 호출될 가능성에 대비해 프레임 종료 후 표시한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCompletionDialog();
      });
    } else if (!_controller.isCompleted) {
      _completionDialogShown = false;
    }
  }

  void _showCompletionDialog() {
    final info = _controller.levelInfo;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('축하합니다!'),
          ],
        ),
        content: Text(
          '레벨 ${_controller.currentLevel} (${info.title}) 스도쿠를 '
          '${_controller.elapsedLabel} 만에 완성했습니다!',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (_controller.currentLevel < kDifficultyLevels.length)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _controller.startNewGame(_controller.currentLevel + 1);
              },
              icon: const Icon(Icons.arrow_forward),
              label: Text('레벨 ${_controller.currentLevel + 1} 도전'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _controller.startNewGame(_controller.currentLevel);
            },
            child: const Text('새 게임'),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // KeyDownEvent(최초 입력)뿐 아니라 KeyRepeatEvent(길게 눌러 반복 입력)도 처리해야
    // 키를 누르고 있을 때 숫자 입력/이동이 계속 반복된다.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    final digit = _digitKeys[key];
    if (digit != null) {
      _controller.inputNumber(digit);
      return KeyEventResult.handled;
    }

    // 지우기 (Backspace, Delete, 숫자 0)
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      _controller.inputNumber(0);
      return KeyEventResult.handled;
    }

    final move = _arrowKeys[key];
    if (move != null) {
      _controller.moveSelection(move.$1, move.$2);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final boardSize =
        min(screenSize.width * 0.9, min(screenSize.height * 0.52, 450.0));

    return ChangeNotifierProvider<SudokuController>.value(
      value: _controller,
      // 게임 영역이 방향키 포커스를 독점하도록 FocusScope로 감싼다.
      // (상단 네비게이션 바 버튼은 canRequestFocus: false로 트래버설에서 제외)
      child: FocusScope(
        autofocus: true,
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Column(
            children: [
              _SudokuControlPanel(controller: _controller),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SudokuBoard(boardSize: boardSize),
                        const SizedBox(height: 16),
                        _SudokuNumberPad(controller: _controller),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상단 난이도 설정 패널 (난이도 선택 · 게임 제어 · 진행 정보)
class _SudokuControlPanel extends StatelessWidget {
  const _SudokuControlPanel({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<SudokuController>();
    final currentInfo = state.levelInfo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colorScheme.primaryContainer, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded,
                    size: 20, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.currentLevel,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    items: kDifficultyLevels.map((info) {
                      return DropdownMenuItem<int>(
                        value: info.level,
                        child: Text(
                          '레벨 ${info.level} (${info.title}) - ${info.filledCells}칸 채움',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (newLevel) {
                      if (newLevel != null && newLevel != state.currentLevel) {
                        controller.startNewGame(newLevel);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: '새 게임 생성',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => controller.startNewGame(state.currentLevel),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: '처음 상태로 초기화',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.tertiaryContainer,
                  foregroundColor: colorScheme.onTertiaryContainer,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                onPressed: controller.resetCurrentGame,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 레벨 빠른 선택 칩 바
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kDifficultyLevels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final info = kDifficultyLevels[index];
                final isSelected = info.level == state.currentLevel;
                return ChoiceChip(
                  label: Text('Lv.${info.level} (${info.filledCells})'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color:
                        isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (selected) {
                    if (selected && info.level != state.currentLevel) {
                      controller.startNewGame(info.level);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // 진행 정보 바 (채움 / 빈칸 / 경과 시간)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9×9 보드 채워진 숫자: ${currentInfo.filledCells}개',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                '남은 빈칸: ${currentInfo.emptyCells}개',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 13, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    state.elapsedLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 하단 숫자 입력 패드 (1~9 + 지우기)
class _SudokuNumberPad extends StatelessWidget {
  const _SudokuNumberPad({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          ...List.generate(kBoardSize, (index) {
            final number = index + 1;
            return SizedBox(
              width: 40,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.onSurface,
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                onPressed: () => controller.inputNumber(number),
                child: Text('$number',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            );
          }),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.backspace_outlined, size: 20),
              onPressed: () => controller.inputNumber(0),
            ),
          ),
        ],
      ),
    );
  }
}
