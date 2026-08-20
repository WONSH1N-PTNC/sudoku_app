import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/sudoku/controller/sudoku_controller.dart';
import 'package:sudoku_app/features/sudoku/domain/sudoku_rules.dart';

/// 테스트용 백트래킹 솔버. 컨트롤러가 들고 있는 퍼즐을 실제로 풀어보기 위해 사용한다.
bool solve(List<List<int>> grid) {
  for (int r = 0; r < kBoardSize; r++) {
    for (int c = 0; c < kBoardSize; c++) {
      if (grid[r][c] != 0) continue;
      for (int n = 1; n <= kBoardSize; n++) {
        if (hasConflictAt(grid, r, c, n)) continue;
        grid[r][c] = n;
        if (solve(grid)) return true;
        grid[r][c] = 0;
      }
      return false;
    }
  }
  return true;
}

/// 컨트롤러가 현재 보여주는 보드를 그대로 읽어온다.
List<List<int>> snapshot(SudokuController c) => List.generate(
      kBoardSize,
      (r) => List.generate(kBoardSize, (col) => c.cellAt(r, col)),
    );

void main() {
  group('SudokuController', () {
    test('생성 직후 레벨 1 퍼즐과 초기화된 상태를 갖는다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      expect(c.currentLevel, 1);
      expect(c.isCompleted, isFalse);
      expect(c.selectedCell, isNull);
      expect(c.elapsed, Duration.zero);
      expect(c.elapsedLabel, '00:00');
    });

    test('초기 힌트 칸은 입력으로 덮어쓸 수 없다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      final hint = _findCell(c, initial: true);
      final before = c.cellAt(hint.$1, hint.$2);
      c.selectCell(hint.$1, hint.$2);
      c.inputNumber(5);

      expect(c.cellAt(hint.$1, hint.$2), before);
    });

    test('빈 칸에는 입력과 지우기가 모두 반영된다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      final empty = _findCell(c, initial: false);
      c.selectCell(empty.$1, empty.$2);
      c.inputNumber(7);
      expect(c.cellAt(empty.$1, empty.$2), 7);

      c.inputNumber(0);
      expect(c.cellAt(empty.$1, empty.$2), 0);
    });

    test('선택된 칸이 없으면 입력이 무시된다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      final before = snapshot(c);
      c.inputNumber(3);
      expect(snapshot(c), before);
    });

    test('방향키 이동은 보드 경계를 벗어나지 않는다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      c.moveSelection(0, 0); // 선택이 없으면 (0,0)에서 시작
      expect(c.selectedCell, (row: 0, col: 0));

      c.moveSelection(-1, -1);
      expect(c.selectedCell, (row: 0, col: 0));

      c.selectCell(kBoardSize - 1, kBoardSize - 1);
      c.moveSelection(1, 1);
      expect(c.selectedCell, (row: kBoardSize - 1, col: kBoardSize - 1));
    });

    test('초기화하면 사용자가 채운 칸이 모두 지워진다', () {
      final c = SudokuController();
      addTearDown(c.dispose);

      final empty = _findCell(c, initial: false);
      c.selectCell(empty.$1, empty.$2);
      c.inputNumber(9);
      c.resetCurrentGame();

      expect(c.cellAt(empty.$1, empty.$2), 0);
      expect(c.selectedCell, isNull);
      expect(c.isCompleted, isFalse);
    });

    test('규칙에 맞게 보드를 모두 채우면 완료로 인정된다', () {
      // 생성기는 유일해를 보장하지 않으므로, 저장된 정답과 다른 유효한 해답이라도
      // 규칙만 만족하면 완료 처리되어야 한다.
      final c = SudokuController(initialLevel: 10);
      addTearDown(c.dispose);

      final solved = snapshot(c);
      expect(solve(solved), isTrue, reason: '생성된 퍼즐은 풀이 가능해야 한다');

      for (int r = 0; r < kBoardSize; r++) {
        for (int col = 0; col < kBoardSize; col++) {
          if (c.isInitialCell(r, col)) continue;
          c.selectCell(r, col);
          c.inputNumber(solved[r][col]);
        }
      }

      expect(c.isCompleted, isTrue);
    });
  });
}

/// 조건에 맞는 첫 번째 칸의 (행, 열)을 찾는다.
(int, int) _findCell(SudokuController c, {required bool initial}) {
  for (int r = 0; r < kBoardSize; r++) {
    for (int col = 0; col < kBoardSize; col++) {
      if (c.isInitialCell(r, col) == initial) return (r, col);
    }
  }
  throw StateError('조건에 맞는 칸을 찾지 못했습니다');
}
