import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controller/block_blast_controller.dart';
import '../domain/block_piece.dart';
import 'block_colors.dart';
import 'block_drag.dart';

/// 하단 조각 트레이. 세 조각을 제시하고 드래그 소스 역할을 한다.
class BlockTray extends StatelessWidget {
  const BlockTray({
    super.key,
    required this.boardCellSize,
    required this.slotSize,
  });

  /// 보드의 칸 크기. 드래그 피드백을 보드와 같은 배율로 그려 착지 지점이 어긋나지 않게 한다.
  final double boardCellSize;

  /// 트레이 슬롯 하나의 한 변 크기
  final double slotSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = context.watch<BlockBlastController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < controller.tray.length; i++)
            SizedBox(
              width: slotSize,
              height: slotSize,
              child: Center(
                child: _buildSlot(controller, i, controller.tray[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlot(BlockBlastController controller, int index, BlockPiece? piece) {
    if (piece == null) return const SizedBox.shrink();

    // 조각이 슬롯을 넘치지 않도록 축소해서 보여준다.
    final longestSide = piece.width > piece.height ? piece.width : piece.height;
    final trayCellSize = (slotSize / longestSide).clamp(6.0, boardCellSize);
    final canPlay = controller.grid.canPlaceAnywhere(piece);

    final view = BlockPieceView(
      piece: piece,
      cellSize: trayCellSize,
      // 놓을 자리가 없는 조각은 흐리게 표시해 게임 오버 임박을 알린다.
      opacity: canPlay ? 1.0 : 0.35,
    );

    if (!canPlay) return view;

    // 조각이 슬롯보다 작아도 슬롯 어디를 잡든 끌 수 있게 영역을 넓힌다.
    // 모바일에서 작은 조각을 정확히 짚기 어려운 문제를 줄여준다.
    Widget fillSlot(Widget child) =>
        SizedBox(width: slotSize, height: slotSize, child: Center(child: child));

    final data = BlockDragData(trayIndex: index, piece: piece);
    return Draggable<BlockDragData>(
      data: data,
      // 조각을 그리는 위젯(SizedBox·DecoratedBox)은 히트 테스트에 참여하지 않는다.
      // 기본값(deferToChild)이면 조각의 빈 칸이나 칸 경계를 짚었을 때 드래그가
      // 아예 시작되지 않는다. 슬롯 전체를 잡을 수 있도록 opaque로 둔다.
      hitTestBehavior: HitTestBehavior.opaque,
      // 포인터 위치를 기준으로 삼아야 보드에서 착지 칸을 정확히 역산할 수 있다.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // 드롭 대상 판정(히트 테스트)은 기본적으로 손가락 위치에서 일어난다.
      // 조각은 손가락보다 위에 그려지므로, 하단 줄을 조준하면 손가락이 보드 밖으로
      // 내려가 드롭이 무시된다. 판정 지점을 조각 위치로 함께 옮겨 이를 막는다.
      feedbackOffset: blockDragLift(piece, boardCellSize),
      onDragEnd: (_) => controller.clearPreview(),
      onDraggableCanceled: (velocity, offset) => controller.clearPreview(),
      feedback: Transform.translate(
        offset: blockDragLift(piece, boardCellSize),
        child: BlockPieceView(piece: piece, cellSize: boardCellSize),
      ),
      childWhenDragging: fillSlot(
        BlockPieceView(piece: piece, cellSize: trayCellSize, opacity: 0.25),
      ),
      child: fillSlot(view),
    );
  }
}
