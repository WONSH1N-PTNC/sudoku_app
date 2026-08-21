import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/domain/tile_map.dart';

void main() {
  group('TileMap', () {
    test('맵 밖은 벽으로 취급해 경계 검사를 단순화한다', () {
      final map = TileMap.filled(5, 5);
      expect(map.tileAt(-1, 0), TileType.wall);
      expect(map.tileAt(0, -1), TileType.wall);
      expect(map.tileAt(5, 0), TileType.wall);
      expect(map.inBounds(-1, 0), isFalse);
    });

    test('상자만 부술 수 있다', () {
      final map = TileMap.filled(5, 5);
      map.setTile(1, 1, TileType.box);
      map.setTile(2, 2, TileType.wall);

      expect(map.breakBox(1, 1), isTrue);
      expect(map.tileAt(1, 1), TileType.empty);
      expect(map.breakBox(2, 2), isFalse, reason: '고정 벽은 부술 수 없다');
      expect(map.breakBox(3, 3), isFalse, reason: '빈 칸은 부술 것이 없다');
    });
  });

  group('TileMap.stage', () {
    test('테두리는 모두 벽이다', () {
      final map = TileMap.stage(Random(1));
      for (int col = 0; col < kMapWidth; col++) {
        expect(map.tileAt(col, 0), TileType.wall);
        expect(map.tileAt(col, kMapHeight - 1), TileType.wall);
      }
      for (int row = 0; row < kMapHeight; row++) {
        expect(map.tileAt(0, row), TileType.wall);
        expect(map.tileAt(kMapWidth - 1, row), TileType.wall);
      }
    });

    test('짝수 좌표에 고정 기둥이 선다', () {
      final map = TileMap.stage(Random(1));
      expect(map.tileAt(2, 2), TileType.wall);
      expect(map.tileAt(4, 6), TileType.wall);
    });

    test('스폰 지점과 인접 칸은 어떤 시드에서도 비어 있다', () {
      // 시작하자마자 갇히면 게임이 성립하지 않으므로 여러 시드로 확인한다.
      for (int seed = 0; seed < 30; seed++) {
        final map = TileMap.stage(Random(seed));
        for (final (col, row) in TileMap.spawnPoints) {
          expect(map.tileAt(col, row), TileType.empty,
              reason: 'seed $seed: 스폰 ($col,$row)');
          // 상하좌우 중 벽이 아닌 칸은 반드시 비어 있어야 한다 (탈출로 확보)
          for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final tile = map.tileAt(col + dc, row + dr);
            expect(tile == TileType.empty || tile == TileType.wall, isTrue,
                reason: 'seed $seed: 스폰 인접 (${col + dc},${row + dr})에 상자가 있으면 안 된다');
          }
        }
      }
    });

    test('같은 시드는 같은 맵을 만든다', () {
      final a = TileMap.stage(Random(42));
      final b = TileMap.stage(Random(42));
      for (int row = 0; row < kMapHeight; row++) {
        for (int col = 0; col < kMapWidth; col++) {
          expect(a.tileAt(col, row), b.tileAt(col, row));
        }
      }
    });
  });
}
