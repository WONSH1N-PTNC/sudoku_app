import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/block_blast_controller.dart';
import '../domain/block_grid.dart';
import 'block_colors.dart';
import 'block_drag.dart';

/// 8x8 보드. 트레이에서 드래그해 온 조각을 받는 드롭 타깃이다.
class BlockBlastBoard extends StatefulWidget {
  const BlockBlastBoard({super.key, required this.boardSize});

  /// 보드 한 변의 픽셀 크기 (정사각형)
  final double boardSize;

  @override
  State<BlockBlastBoard> createState() => _BlockBlastBoardState();
}

class _BlockBlastBoardState extends State<BlockBlastBoard> {
  final GlobalKey _gridKey = GlobalKey();

  double get _cellSize => widget.boardSize / kBlockGridSize;

  /// 드래그 중인 조각의 좌상단이 어느 칸에 해당하는지 계산한다.
  (int, int)? _cellFor(BlockDragData data, Offset pointerGlobal) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;

    final topLeft = pointerGlobal + blockDragLift(data.piece, _cellSize);
    final local = box.globalToLocal(topLeft);
    // round를 쓰면 칸 경계에 살짝 못 미쳐도 가까운 칸으로 붙어 조작이 관대해진다.
    return ((local.dy / _cellSize).round(), (local.dx / _cellSize).round());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = context.watch<BlockBlastController>();

    return DragTarget<BlockDragData>(
      onMove: (details) {
        final cell = _cellFor(details.data, details.offset);
        if (cell == null) return;
        controller.updatePreview(details.data.piece, cell.$1, cell.$2);
      },
      onLeave: (_) => controller.clearPreview(),
      onAcceptWithDetails: (details) {
        final cell = _cellFor(details.data, details.offset);
        controller.clearPreview();
        if (cell == null) return;
        controller.placePiece(details.data.trayIndex, cell.$1, cell.$2);
      },
      builder: (context, candidate, rejected) {
        return Container(
          key: _gridKey,
          width: widget.boardSize,
          height: widget.boardSize,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(_cellSize * 0.25),
            // 테두리를 주면 내부 폭이 그만큼 줄어 8칸이 들어가지 못한다.
            // 배경색만으로 보드 영역을 구분한다.
          ),
          child: Column(
            children: [
              for (int r = 0; r < kBlockGridSize; r++)
                Row(
                  children: [
                    for (int c = 0; c < kBlockGridSize; c++)
                      _buildCell(controller, r, c),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(BlockBlastController controller, int row, int col) {
    final filled = controller.grid.isFilled(row, col);
    final preview = controller.preview;
    final previewPiece = controller.previewPiece;

    // 미리보기 조각이 이 칸을 덮는지 확인한다.
    bool covered = false;
    if (preview != null && previewPiece != null) {
      covered = previewPiece.cells
          .any((cell) => preview.row + cell.$1 == row && preview.col + cell.$2 == col);
    }

    if (covered && !filled) {
      return BlockCell(
        size: _cellSize,
        colorIndex: preview!.valid ? previewPiece!.colorIndex : null,
        ghost: true,
        invalid: !preview.valid,
      );
    }

    return BlockCell(
      size: _cellSize,
      colorIndex: filled ? controller.grid.cellAt(row, col) : null,
    );
  }
}
