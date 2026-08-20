import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/sudoku/domain/difficulty.dart';
import 'package:sudoku_app/features/sudoku/domain/sudoku_generator.dart';
import 'package:sudoku_app/features/sudoku/domain/sudoku_rules.dart';

/// 보드 전체가 스도쿠 규칙을 만족하며 빈 칸이 없는지 확인한다.
bool isValidCompleteBoard(List<List<int>> grid) {
  for (int r = 0; r < kBoardSize; r++) {
    for (int c = 0; c < kBoardSize; c++) {
      if (grid[r][c] == 0) return false;
      if (hasConflictAt(grid, r, c, grid[r][c], ignoreSelf: true)) return false;
    }
  }
  return true;
}

void main() {
  group('hasConflictAt', () {
    List<List<int>> emptyGrid() =>
        List.generate(kBoardSize, (_) => List.filled(kBoardSize, 0));

    test('빈 칸(0)은 충돌로 보지 않는다', () {
      expect(hasConflictAt(emptyGrid(), 0, 0, 0), isFalse);
    });

    test('같은 행의 중복을 잡아낸다', () {
      final grid = emptyGrid();
      grid[0][5] = 7;
      expect(hasConflictAt(grid, 0, 0, 7), isTrue);
    });

    test('같은 열의 중복을 잡아낸다', () {
      final grid = emptyGrid();
      grid[8][3] = 4;
      expect(hasConflictAt(grid, 0, 3, 4), isTrue);
    });

    test('같은 3x3 박스의 중복을 잡아낸다', () {
      final grid = emptyGrid();
      grid[4][4] = 2;
      expect(hasConflictAt(grid, 3, 3, 2), isTrue);
    });

    test('다른 박스·행·열이면 충돌이 아니다', () {
      final grid = emptyGrid();
      grid[0][0] = 9;
      expect(hasConflictAt(grid, 4, 4, 9), isFalse);
    });

    test('ignoreSelf는 자기 자신을 비교에서 제외한다', () {
      final grid = emptyGrid();
      grid[2][2] = 5;
      expect(hasConflictAt(grid, 2, 2, 5), isTrue);
      expect(hasConflictAt(grid, 2, 2, 5, ignoreSelf: true), isFalse);
    });
  });

  group('SudokuGenerator', () {
    test('모든 난이도에서 정답 보드는 완전하고 유효하다', () {
      for (final info in kDifficultyLevels) {
        final puzzle = SudokuGenerator.generate(info.level);
        expect(isValidCompleteBoard(puzzle.solution), isTrue,
            reason: '레벨 ${info.level}의 정답 보드가 유효하지 않음');
      }
    });

    test('난이도별로 정의된 힌트 개수만큼 칸이 채워진다', () {
      for (final info in kDifficultyLevels) {
        final puzzle = SudokuGenerator.generate(info.level);
        final filled = puzzle.initialBoard
            .expand((row) => row)
            .where((v) => v != 0)
            .length;
        expect(filled, info.filledCells, reason: '레벨 ${info.level}');
      }
    });

    test('초기 보드의 힌트는 정답 보드와 일치한다', () {
      final puzzle = SudokuGenerator.generate(5);
      for (int r = 0; r < kBoardSize; r++) {
        for (int c = 0; c < kBoardSize; c++) {
          if (puzzle.initialBoard[r][c] != 0) {
            expect(puzzle.initialBoard[r][c], puzzle.solution[r][c]);
          }
        }
      }
    });

    test('정의되지 않은 레벨은 레벨 1로 안전하게 대체된다', () {
      expect(SudokuGenerator.generate(999).levelInfo.level, 1);
      expect(SudokuGenerator.generate(0).levelInfo.level, 1);
      expect(SudokuGenerator.generate(-3).levelInfo.level, 1);
    });
  });

  group('difficultyForLevel', () {
    test('레벨 값으로 올바른 항목을 찾는다', () {
      expect(difficultyForLevel(10).title, '마스터');
      expect(difficultyForLevel(1).filledCells, 62);
    });

    test('없는 레벨은 예외 대신 레벨 1을 돌려준다', () {
      expect(difficultyForLevel(42).level, 1);
    });
  });
}
