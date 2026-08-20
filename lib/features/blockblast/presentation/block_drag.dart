import 'package:flutter/widgets.dart';

import '../domain/block_piece.dart';

/// 트레이에서 보드로 드래그되는 데이터
class BlockDragData {
  const BlockDragData({required this.trayIndex, required this.piece});

  final int trayIndex;
  final BlockPiece piece;
}

/// 드래그 피드백을 손가락/커서 위치에서 얼마나 띄울지 계산한다.
///
/// Draggable에 pointerDragAnchorStrategy를 쓰면 피드백의 좌상단이 포인터에 붙는다.
/// 그대로 두면 손가락이 조각을 가리므로 가로는 가운데 정렬, 세로는 위로 올린다.
/// 보드에서 착지 칸을 계산할 때도 이 값을 동일하게 더해 좌표를 맞춘다.
Offset blockDragLift(BlockPiece piece, double cellSize) => Offset(
      -piece.width * cellSize / 2,
      -piece.height * cellSize - cellSize * 0.6,
    );
