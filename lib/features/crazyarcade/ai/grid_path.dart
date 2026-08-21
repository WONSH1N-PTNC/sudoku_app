/// 봇이 지나갈 수 있는 칸인지 판정한다.
///
/// [steps]는 시작점에서 그 칸까지의 걸음 수다. 불꽃을 피해 달아날 때는
/// "몇 걸음 뒤에 도착하는가"에 따라 지나갈 수 있는지가 달라지므로 함께 넘긴다.
typedef Passable = bool Function(int col, int row, int steps);

/// 한 지점에서 출발한 너비 우선 탐색 결과.
///
/// 걸음 수와 되짚어 갈 부모를 함께 들고 있어, 목표까지의 거리뿐 아니라
/// "지금 어느 쪽으로 한 걸음 떼야 하는지"를 바로 알 수 있다.
class PathField {
  PathField._(this.width, this.height, this.startCol, this.startRow, this._steps,
      this._parent);

  final int width;
  final int height;
  final int startCol;
  final int startRow;
  final List<int> _steps;
  final List<int> _parent;

  int _index(int col, int row) => row * width + col;

  bool _inBounds(int col, int row) =>
      col >= 0 && col < width && row >= 0 && row < height;

  /// 시작점에서 (col, row)까지의 걸음 수. 갈 수 없으면 -1.
  int stepsTo(int col, int row) {
    if (!_inBounds(col, row)) return -1;
    return _steps[_index(col, row)];
  }

  bool canReach(int col, int row) => stepsTo(col, row) >= 0;

  /// (col, row)로 가기 위해 지금 떼야 할 첫 걸음의 방향.
  ///
  /// 목표에서 부모를 거슬러 올라가 시작점 바로 다음 칸을 찾는다.
  /// 갈 수 없거나 이미 도착했으면 null.
  (int, int)? firstStepTo(int col, int row) {
    if (!canReach(col, row)) return null;
    var current = _index(col, row);
    final start = _index(startCol, startRow);
    if (current == start) return null;

    while (_parent[current] != start) {
      current = _parent[current];
      if (current < 0) return null;
    }
    final nextCol = current % width;
    final nextRow = current ~/ width;
    return (nextCol - startCol, nextRow - startRow);
  }

  /// 조건에 맞는 칸 중 가장 가까운 곳을 찾는다.
  (int, int)? nearestWhere(bool Function(int col, int row) test) {
    var bestSteps = -1;
    (int, int)? best;
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final steps = _steps[_index(col, row)];
        if (steps < 0) continue;
        if (!test(col, row)) continue;
        if (best == null || steps < bestSteps) {
          bestSteps = steps;
          best = (col, row);
        }
      }
    }
    return best;
  }
}

/// (startCol, startRow)에서 출발하는 너비 우선 탐색.
PathField breadthFirst(
  int width,
  int height,
  int startCol,
  int startRow,
  Passable passable,
) {
  final steps = List.filled(width * height, -1);
  final parent = List.filled(width * height, -1);
  final start = startRow * width + startCol;

  steps[start] = 0;
  final queue = <int>[start];
  var head = 0;

  const directions = [(1, 0), (-1, 0), (0, 1), (0, -1)];
  while (head < queue.length) {
    final current = queue[head++];
    final col = current % width;
    final row = current ~/ width;

    for (final (dc, dr) in directions) {
      final nextCol = col + dc;
      final nextRow = row + dr;
      if (nextCol < 0 || nextCol >= width || nextRow < 0 || nextRow >= height) {
        continue;
      }
      final next = nextRow * width + nextCol;
      if (steps[next] >= 0) continue;
      if (!passable(nextCol, nextRow, steps[current] + 1)) continue;

      steps[next] = steps[current] + 1;
      parent[next] = current;
      queue.add(next);
    }
  }

  return PathField._(width, height, startCol, startRow, steps, parent);
}
