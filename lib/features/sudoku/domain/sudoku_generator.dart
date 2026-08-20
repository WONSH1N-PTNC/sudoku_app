import 'dart:math';

import 'difficulty.dart';
import 'sudoku_rules.dart';

/// 생성된 퍼즐 한 판 (초기 보드 / 정답 보드 / 난이도 정보)
class SudokuPuzzle {
  final List<List<int>> initialBoard;
  final List<List<int>> solution;
  final DifficultyInfo levelInfo;

  SudokuPuzzle({
    required this.initialBoard,
    required this.solution,
    required this.levelInfo,
  });
}

/// 스도쿠 생성기
class SudokuGenerator {
  static SudokuPuzzle generate(int level) {
    final diff = difficultyForLevel(level);
    final targetFilled = diff.filledCells;
    final random = Random();

    // 1. 9x9 빈 보드 생성
    List<List<int>> fullBoard =
        List.generate(kBoardSize, (_) => List.filled(kBoardSize, 0));

    // 2. 대각선 3개 3x3 박스 독립 채우기 (0,0), (3,3), (6,6)
    for (int i = 0; i < kBoardSize; i += kBoxSize) {
      _fillBox(fullBoard, i, i, random);
    }

    // 3. 백트래킹으로 나머지 칸 채워 완전한 스도쿠 완성
    _solve(fullBoard, random);

    // 4. 정답 보드 복사
    List<List<int>> solution = copyBoard(fullBoard);

    // 5. 난이도별 채워질 칸 수에 맞춰 빈칸 생성
    List<List<int>> puzzle = copyBoard(fullBoard);
    int cellsToRemove = kTotalCells - targetFilled;

    List<Point<int>> positions = [];
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        positions.add(Point(r, c));
      }
    }
    positions.shuffle(random);

    for (int i = 0; i < cellsToRemove && i < positions.length; i++) {
      puzzle[positions[i].x][positions[i].y] = 0;
    }

    return SudokuPuzzle(
      initialBoard: puzzle,
      solution: solution,
      levelInfo: diff,
    );
  }

  static List<int> _shuffledDigits(Random random) {
    return List.generate(kBoardSize, (i) => i + 1)..shuffle(random);
  }

  static void _fillBox(
      List<List<int>> grid, int startRow, int startCol, Random random) {
    List<int> numbers = _shuffledDigits(random);
    int idx = 0;
    for (int r = 0; r < kBoxSize; r++) {
      for (int c = 0; c < kBoxSize; c++) {
        grid[startRow + r][startCol + c] = numbers[idx++];
      }
    }
  }

  static bool _isValid(List<List<int>> grid, int row, int col, int num) {
    return !hasConflictAt(grid, row, col, num);
  }

  static bool _solve(List<List<int>> grid, Random random) {
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        if (grid[r][c] == 0) {
          List<int> numbers = _shuffledDigits(random);
          for (int num in numbers) {
            if (_isValid(grid, r, c, num)) {
              grid[r][c] = num;
              if (_solve(grid, random)) return true;
              grid[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }
}
