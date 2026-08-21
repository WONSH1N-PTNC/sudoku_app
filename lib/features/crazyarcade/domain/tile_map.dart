import 'dart:math';

/// 맵 한 칸의 종류
enum TileType {
  /// 지나갈 수 있는 빈 칸
  empty,

  /// 부술 수 없는 고정 벽
  wall,

  /// 물풍선으로 부술 수 있는 상자
  box,
}

/// 기본 스테이지 크기 (가로 15칸 x 세로 13칸, 바깥 한 줄은 테두리 벽)
const int kMapWidth = 15;
const int kMapHeight = 13;

/// 타일 격자. 좌표는 (col, row)이며 좌상단이 (0, 0)이다.
class TileMap {
  TileMap.filled(this.width, this.height, [TileType fill = TileType.empty])
      : _tiles = List.filled(width * height, fill);

  final int width;
  final int height;
  final List<TileType> _tiles;

  bool inBounds(int col, int row) =>
      col >= 0 && col < width && row >= 0 && row < height;

  TileType tileAt(int col, int row) {
    if (!inBounds(col, row)) return TileType.wall; // 맵 밖은 벽으로 취급
    return _tiles[row * width + col];
  }

  void setTile(int col, int row, TileType type) {
    if (!inBounds(col, row)) return;
    _tiles[row * width + col] = type;
  }

  /// 액터가 통과할 수 없는 칸인지 여부 (물풍선은 GameWorld에서 따로 판정한다)
  bool isBlocking(int col, int row) => tileAt(col, row) != TileType.empty;

  /// 물풍선 폭발이 상자를 부순다. 부순 경우 true.
  bool breakBox(int col, int row) {
    if (tileAt(col, row) != TileType.box) return false;
    setTile(col, row, TileType.empty);
    return true;
  }

  /// 스폰 지점 4곳 (네 모서리 안쪽)
  static const List<(int, int)> spawnPoints = [
    (1, 1),
    (kMapWidth - 2, 1),
    (1, kMapHeight - 2),
    (kMapWidth - 2, kMapHeight - 2),
  ];

  /// 기본 스테이지를 생성한다.
  ///
  /// 테두리 벽 + 짝수 좌표 기둥 + 나머지 칸에 상자를 흩뿌리는 고전 배치다.
  /// 스폰 지점과 그 인접 칸은 시작하자마자 갇히지 않도록 반드시 비워 둔다.
  /// [random]을 주입받아 같은 시드면 같은 맵이 나오므로 테스트가 재현 가능하다.
  factory TileMap.stage(Random random, {double boxRatio = 0.62}) {
    final map = TileMap.filled(kMapWidth, kMapHeight);

    for (int row = 0; row < kMapHeight; row++) {
      for (int col = 0; col < kMapWidth; col++) {
        final isBorder =
            col == 0 || row == 0 || col == kMapWidth - 1 || row == kMapHeight - 1;
        final isPillar = col % 2 == 0 && row % 2 == 0;
        if (isBorder || isPillar) {
          map.setTile(col, row, TileType.wall);
        }
      }
    }

    final reserved = _spawnSafeCells();
    for (int row = 1; row < kMapHeight - 1; row++) {
      for (int col = 1; col < kMapWidth - 1; col++) {
        if (map.tileAt(col, row) != TileType.empty) continue;
        if (reserved.contains((col, row))) continue;
        if (random.nextDouble() < boxRatio) {
          map.setTile(col, row, TileType.box);
        }
      }
    }
    return map;
  }

  /// 스폰 지점과 상하좌우 한 칸씩은 상자를 두지 않는다.
  static Set<(int, int)> _spawnSafeCells() {
    final cells = <(int, int)>{};
    for (final (col, row) in spawnPoints) {
      cells.add((col, row));
      cells.add((col + 1, row));
      cells.add((col - 1, row));
      cells.add((col, row + 1));
      cells.add((col, row - 1));
    }
    return cells;
  }
}
