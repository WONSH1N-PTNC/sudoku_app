import 'tile_map.dart';

/// 물풍선 하나가 덮는 칸을 계산한다.
///
/// 이 규칙은 반드시 한 곳에만 있어야 한다. 시뮬레이션이 실제로 터뜨리는 범위와
/// AI가 예측하는 위험 범위가 조금이라도 어긋나면 봇이 자기 물풍선에 휘말린다.
///
/// - 벽을 만나면 그 앞에서 멈춘다 (벽 칸은 포함하지 않는다).
/// - 상자는 그 칸까지 덮고 멈춘다 (뒤로는 뻗지 않는다).
/// - 다른 물풍선을 만나면 그 칸까지 덮고 멈추며 연쇄 대상으로 알린다.
List<(int, int)> blastCells(
  TileMap map,
  int col,
  int row,
  int power, {
  bool Function(int col, int row)? hasBalloon,
  void Function(int col, int row)? onBox,
  void Function(int col, int row)? onBalloon,
}) {
  final cells = <(int, int)>[(col, row)];
  const directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  for (final (dc, dr) in directions) {
    for (int step = 1; step <= power; step++) {
      final c = col + dc * step;
      final r = row + dr * step;
      if (!map.inBounds(c, r)) break;

      final tile = map.tileAt(c, r);
      if (tile == TileType.wall) break;

      if (tile == TileType.box) {
        onBox?.call(c, r);
        cells.add((c, r));
        break;
      }

      cells.add((c, r));

      if (hasBalloon?.call(c, r) ?? false) {
        onBalloon?.call(c, r);
        break;
      }
    }
  }
  return cells;
}
