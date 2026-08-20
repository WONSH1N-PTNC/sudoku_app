import 'package:flutter/material.dart';

import '../domain/block_piece.dart';

/// 조각 팔레트. [kBlockColorCount]개의 색을 테마와 무관하게 일정하게 유지해
/// 같은 색 조각이 보드에서도 같은 색으로 보이도록 한다.
const List<Color> kBlockPalette = [
  Color(0xFF4F6DF5), // 파랑
  Color(0xFF2FB89B), // 청록
  Color(0xFFF2A93B), // 주황
  Color(0xFFE05C6E), // 분홍
  Color(0xFF8A6BE2), // 보라
  Color(0xFF54B04A), // 초록
];

Color blockColor(int colorIndex) =>
    kBlockPalette[colorIndex % kBlockPalette.length];

/// 보드 칸 · 조각 칸을 그리는 공통 위젯.
class BlockCell extends StatelessWidget {
  const BlockCell({
    super.key,
    required this.size,
    this.colorIndex,
    this.ghost = false,
    this.invalid = false,
  });

  /// 한 변의 픽셀 크기
  final double size;

  /// null이면 빈 칸
  final int? colorIndex;

  /// 드래그 미리보기(반투명) 여부
  final bool ghost;

  /// 놓을 수 없는 위치임을 표시할지 여부
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final index = colorIndex;

    Color fill;
    if (invalid) {
      fill = colorScheme.error.withValues(alpha: 0.35);
    } else if (index == null) {
      fill = colorScheme.surfaceContainerHighest;
    } else {
      fill = blockColor(index).withValues(alpha: ghost ? 0.45 : 1.0);
    }

    // 칸이 실제로 차지하는 크기는 정확히 size여야 한다. 간격을 margin으로 주면
    // 그만큼 폭이 커져 한 줄에 8칸을 배치할 때 보드 밖으로 넘친다.
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.04),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(size * 0.2),
            border: index == null && !invalid
                ? Border.all(color: colorScheme.outlineVariant, width: 0.5)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 조각 하나를 격자 형태로 그린다 (트레이 · 드래그 피드백 공용).
class BlockPieceView extends StatelessWidget {
  const BlockPieceView({
    super.key,
    required this.piece,
    required this.cellSize,
    this.opacity = 1.0,
  });

  final BlockPiece piece;
  final double cellSize;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final filled = piece.cells.toSet();

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: piece.width * cellSize,
        height: piece.height * cellSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < piece.height; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int c = 0; c < piece.width; c++)
                    filled.contains((r, c))
                        ? BlockCell(size: cellSize, colorIndex: piece.colorIndex)
                        : SizedBox(width: cellSize, height: cellSize),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
