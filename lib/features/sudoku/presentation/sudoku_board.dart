import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/sudoku_controller.dart';
import '../domain/sudoku_rules.dart';

/// 스도쿠 9x9 보드 그리드.
///
/// 상태는 소유하지 않고 [SudokuController]를 구독해 렌더링만 담당한다.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({super.key, required this.boardSize});

  /// 보드 한 변의 픽셀 크기 (정사각형)
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = context.watch<SudokuController>();
    final selection = controller.selectedCell;
    final selectedVal =
        selection != null ? controller.cellAt(selection.row, selection.col) : 0;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: colorScheme.outline, width: 2.5),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kBoardSize,
          ),
          itemCount: kTotalCells,
          itemBuilder: (context, index) {
            final row = index ~/ kBoardSize;
            final col = index % kBoardSize;
            final val = controller.cellAt(row, col);
            final isInitial = controller.isInitialCell(row, col);
            final hasConflict = controller.hasConflict(row, col);
            final isSelected =
                selection != null && row == selection.row && col == selection.col;

            // 관련 영역 하이라이트 (같은 행, 같은 열, 같은 3x3 박스)
            final isRelated = selection != null &&
                (row == selection.row ||
                    col == selection.col ||
                    (row ~/ kBoxSize == selection.row ~/ kBoxSize &&
                        col ~/ kBoxSize == selection.col ~/ kBoxSize));
            // 같은 숫자 하이라이트
            final isSameNumber =
                val != 0 && selectedVal != 0 && val == selectedVal;

            Color cellBgColor = colorScheme.surface;
            if (isSelected) {
              cellBgColor = colorScheme.primary.withValues(alpha: 0.4);
            } else if (hasConflict && !isInitial) {
              cellBgColor = colorScheme.errorContainer;
            } else if (isSameNumber) {
              cellBgColor = colorScheme.primaryContainer;
            } else if (isRelated) {
              cellBgColor = colorScheme.primaryContainer.withValues(alpha: 0.4);
            } else if (isInitial) {
              cellBgColor = colorScheme.surfaceContainerLow;
            }

            return GestureDetector(
              onTap: () => controller.selectCell(row, col),
              child: Container(
                decoration: BoxDecoration(
                  color: cellBgColor,
                  border: Border(
                    top: _cellBorder(colorScheme, row % kBoxSize == 0),
                    left: _cellBorder(colorScheme, col % kBoxSize == 0),
                    right: _cellBorder(colorScheme, col == kBoardSize - 1),
                    bottom: _cellBorder(colorScheme, row == kBoardSize - 1),
                  ),
                ),
                child: Center(
                  child: Text(
                    val == 0 ? '' : '$val',
                    style: TextStyle(
                      fontSize: boardSize / 20,
                      fontWeight: isInitial ? FontWeight.w900 : FontWeight.bold,
                      color: isInitial
                          ? colorScheme.onSurface
                          : (hasConflict ? colorScheme.error : colorScheme.primary),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 3x3 박스 경계와 보드 바깥 테두리는 굵게, 나머지 칸 경계는 얇게 그린다.
  BorderSide _cellBorder(ColorScheme colorScheme, bool isBoundary) {
    return BorderSide(
      width: isBoundary ? 2.0 : 0.5,
      color: isBoundary ? colorScheme.outline : colorScheme.outlineVariant,
    );
  }
}
