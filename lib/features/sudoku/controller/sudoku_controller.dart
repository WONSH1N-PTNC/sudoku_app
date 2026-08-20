import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/difficulty.dart';
import '../domain/sudoku_generator.dart';
import '../domain/sudoku_rules.dart';

/// 스도쿠 한 판의 상태(보드 · 선택 칸 · 완료 여부 · 경과 시간)를 소유한다.
///
/// 화면은 이 컨트롤러를 구독해 렌더링만 담당하고, 규칙 판정은 domain 계층에 위임한다.
class SudokuController extends ChangeNotifier {
  SudokuController({int initialLevel = 1}) {
    startNewGame(initialLevel);
  }

  late List<List<int>> _board;
  late List<List<int>> _initialBoard;

  int _currentLevel = 1;
  ({int row, int col})? _selectedCell;
  bool _isCompleted = false;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  int get currentLevel => _currentLevel;
  DifficultyInfo get levelInfo => difficultyForLevel(_currentLevel);
  ({int row, int col})? get selectedCell => _selectedCell;
  bool get isCompleted => _isCompleted;
  Duration get elapsed => _elapsed;

  /// mm:ss 형식의 경과 시간 (1시간을 넘으면 분이 60 이상으로 계속 누적된다)
  String get elapsedLabel {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int cellAt(int row, int col) => _board[row][col];

  /// 초기 힌트로 주어진 칸인지 여부 (수정 불가 칸)
  bool isInitialCell(int row, int col) => _initialBoard[row][col] != 0;

  /// 규칙 충돌 검사 (행 · 열 · 3x3 박스 내 중복 여부)
  bool hasConflict(int row, int col) {
    return hasConflictAt(_board, row, col, _board[row][col], ignoreSelf: true);
  }

  /// 새로운 게임 시작
  void startNewGame(int level) {
    final puzzle = SudokuGenerator.generate(level);
    // generate()는 존재하지 않는 레벨이 들어오면 레벨 1로 안전하게 대체하므로,
    // currentLevel도 원래 파라미터가 아니라 실제로 생성된 난이도 값을 따라간다.
    _currentLevel = puzzle.levelInfo.level;
    _initialBoard = copyBoard(puzzle.initialBoard);
    _board = copyBoard(_initialBoard);
    _selectedCell = null;
    _isCompleted = false;
    _restartTimer();
    notifyListeners();
  }

  /// 현재 퍼즐을 초기 상태로 리셋
  void resetCurrentGame() {
    _board = copyBoard(_initialBoard);
    _selectedCell = null;
    _isCompleted = false;
    _restartTimer();
    notifyListeners();
  }

  /// 칸 선택 (탭)
  void selectCell(int row, int col) {
    _selectedCell = (row: row, col: col);
    notifyListeners();
  }

  /// 방향키로 선택 이동
  void moveSelection(int dRow, int dCol) {
    final cell = _selectedCell;
    if (cell == null) {
      _selectedCell = (row: 0, col: 0);
    } else {
      _selectedCell = (
        row: (cell.row + dRow).clamp(0, kBoardSize - 1),
        col: (cell.col + dCol).clamp(0, kBoardSize - 1),
      );
    }
    notifyListeners();
  }

  /// 선택된 칸에 숫자 입력 (0은 지우기)
  void inputNumber(int number) {
    final cell = _selectedCell;
    if (cell == null) return;

    // 초기 힌트 칸은 수정 불가
    if (isInitialCell(cell.row, cell.col)) return;

    _board[cell.row][cell.col] = number;
    _updateCompletion();
    notifyListeners();
  }

  /// 게임 완성 여부 검사
  ///
  /// 생성기가 만드는 퍼즐은 유일해(unique solution)를 보장하지 않으므로,
  /// 저장된 solution과의 셀 단위 일치가 아니라 "빈 칸이 없고 규칙 충돌이 없는지"로 판정한다.
  /// 이렇게 하면 플레이어가 생성기와 다른, 그러나 규칙상 유효한 정답을 채워도 인정된다.
  void _updateCompletion() {
    if (_isCompleted) return;

    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        if (_board[r][c] == 0 || hasConflict(r, c)) return;
      }
    }

    _isCompleted = true;
    _ticker?.cancel();
  }

  void _restartTimer() {
    _ticker?.cancel();
    _elapsed = Duration.zero;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
