import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/blockblast/domain/block_grid.dart';
import 'package:sudoku_app/features/blockblast/domain/block_piece.dart';

BlockPiece piece(List<String> pattern) => BlockPiece.fromPattern(pattern, 0);

final single = piece(['X']);
final square2 = piece(['XX', 'XX']);
final line5 = piece(['XXXXX']);

/// (row, col)부터 가로로 [count]칸을 직접 채운다.
void fillRow(BlockGrid grid, int row, int fromCol, int count) {
  for (int i = 0; i < count; i++) {
    grid.fillCell(row, fromCol + i, 1);
  }
}

void main() {
  group('BlockPiece.fromPattern', () {
    test('X 위치만 칸으로 인식하고 크기를 계산한다', () {
      final l = piece(['X.', 'XX']);
      expect(l.cells, containsAll(<(int, int)>[(0, 0), (1, 0), (1, 1)]));
      expect(l.cellCount, 3);
      expect(l.width, 2);
      expect(l.height, 2);
    });
  });

  group('canPlace', () {
    test('빈 보드에는 놓을 수 있다', () {
      expect(BlockGrid().canPlace(square2, 0, 0), isTrue);
    });

    test('보드 밖으로 나가면 놓을 수 없다', () {
      final grid = BlockGrid();
      expect(grid.canPlace(line5, 0, kBlockGridSize - 4), isFalse);
      expect(grid.canPlace(single, -1, 0), isFalse);
      expect(grid.canPlace(single, 0, kBlockGridSize), isFalse);
    });

    test('이미 채워진 칸과 겹치면 놓을 수 없다', () {
      final grid = BlockGrid();
      grid.fillCell(1, 1, 0);
      expect(grid.canPlace(square2, 0, 0), isFalse);
      expect(grid.canPlace(square2, 2, 2), isTrue);
    });
  });

  group('place', () {
    test('놓은 자리에 조각의 색이 채워진다', () {
      final grid = BlockGrid();
      grid.place(BlockPiece.fromPattern(['XX'], 3), 4, 4, comboCount: 1);
      expect(grid.cellAt(4, 4), 3);
      expect(grid.cellAt(4, 5), 3);
      expect(grid.isFilled(4, 6), isFalse);
    });

    test('놓을 수 없는 위치면 예외를 던진다', () {
      final grid = BlockGrid();
      grid.fillCell(0, 0, 0);
      expect(() => grid.place(single, 0, 0, comboCount: 1), throwsStateError);
    });

    test('가득 찬 행이 지워진다', () {
      final grid = BlockGrid();
      fillRow(grid, 3, 0, kBlockGridSize - 1);
      final result = grid.place(single, 3, kBlockGridSize - 1, comboCount: 1);

      expect(result.clearedRows, [3]);
      expect(result.clearedCols, isEmpty);
      for (int c = 0; c < kBlockGridSize; c++) {
        expect(grid.isFilled(3, c), isFalse);
      }
    });

    test('행과 열이 동시에 완성되면 둘 다 지워진다', () {
      // 행을 먼저 지우고 나서 열을 판정하면, 지워진 행 때문에 열이 누락된다.
      final grid = BlockGrid();
      for (int c = 0; c < kBlockGridSize - 1; c++) {
        grid.fillCell(0, c, 1);
      }
      for (int r = 1; r < kBlockGridSize; r++) {
        grid.fillCell(r, kBlockGridSize - 1, 1);
      }
      // 마지막 한 칸이 0행과 마지막 열을 동시에 완성시킨다.
      final result = grid.place(single, 0, kBlockGridSize - 1, comboCount: 1);

      expect(result.clearedRows, [0]);
      expect(result.clearedCols, [kBlockGridSize - 1]);
      expect(result.clearedLineCount, 2);
    });
  });

  group('scoreForLines', () {
    test('줄을 못 지우면 0점이다', () {
      expect(BlockGrid.scoreForLines(0, 1), 0);
    });

    test('첫 줄 100점, 추가 줄마다 200점', () {
      expect(BlockGrid.scoreForLines(1, 1), 100);
      expect(BlockGrid.scoreForLines(2, 1), 300);
      expect(BlockGrid.scoreForLines(3, 1), 500);
    });

    test('콤보 단계마다 50%씩 가산된다', () {
      expect(BlockGrid.scoreForLines(1, 1), 100);
      expect(BlockGrid.scoreForLines(1, 2), 150);
      expect(BlockGrid.scoreForLines(1, 3), 200);
    });
  });

  group('canPlaceAnywhere', () {
    test('빈 보드에서는 어떤 조각이든 놓을 수 있다', () {
      final grid = BlockGrid();
      expect(grid.canPlaceAnywhere(line5), isTrue);
      expect(grid.canPlaceAnywhere(square2), isTrue);
    });

    test('세 칸 연속 빈 행이 없으면 3x3 조각을 놓을 수 없다', () {
      final grid = BlockGrid();
      // 2행과 5행을 막아 세 행 연속으로 비는 구간을 없앤다.
      for (final row in [2, 5]) {
        fillRow(grid, row, 0, kBlockGridSize);
      }
      expect(grid.canPlaceAnywhere(piece(['XXX', 'XXX', 'XXX'])), isFalse);
      expect(grid.canPlaceAnywhere(square2), isTrue);
    });
  });
}
