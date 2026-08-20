import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SudokuApp());
}

/// 보드 크기 관련 공용 상수 (9x9 보드, 3x3 박스)
const int kBoardSize = 9;
const int kBoxSize = 3;
const int kTotalCells = kBoardSize * kBoardSize;

/// 난이도 정보 및 채워진 숫자(힌트) 개수 정의
class DifficultyInfo {
  final int level;
  final String title;
  final int filledCells; // 9x9 (총 81칸) 중 미리 채워지는 숫자 개수

  const DifficultyInfo({
    required this.level,
    required this.title,
    required this.filledCells,
  });

  int get emptyCells => kTotalCells - filledCells;
}

/// 레벨 1 ~ 레벨 10 난이도 정의
const List<DifficultyInfo> kDifficultyLevels = [
  DifficultyInfo(level: 1, title: '매우 쉬움', filledCells: 62),
  DifficultyInfo(level: 2, title: '쉬움', filledCells: 57),
  DifficultyInfo(level: 3, title: '초급', filledCells: 52),
  DifficultyInfo(level: 4, title: '중급 1', filledCells: 47),
  DifficultyInfo(level: 5, title: '중급 2', filledCells: 42),
  DifficultyInfo(level: 6, title: '중고급', filledCells: 38),
  DifficultyInfo(level: 7, title: '고급 1', filledCells: 34),
  DifficultyInfo(level: 8, title: '고급 2', filledCells: 30),
  DifficultyInfo(level: 9, title: '전문가', filledCells: 26),
  DifficultyInfo(level: 10, title: '마스터', filledCells: 22),
];

/// 레벨 값으로 난이도 정보를 조회한다.
/// 목록에 없는 값이 들어와도 예외를 던지지 않고 레벨 1로 안전하게 대체한다.
DifficultyInfo difficultyForLevel(int level) {
  return kDifficultyLevels.firstWhere(
    (d) => d.level == level,
    orElse: () => kDifficultyLevels[0],
  );
}

/// 9x9 보드를 깊은 복사한다 (내부 리스트까지 새로 생성).
List<List<int>> _copyBoard(List<List<int>> source) {
  return List.generate(kBoardSize, (r) => List.from(source[r]));
}

/// (row, col) 칸에 값(value)을 두었을 때 같은 행/열/3x3 박스에서 충돌이 있는지 검사한다.
/// [ignoreSelf]가 true이면 (row, col) 자기 자신은 비교 대상에서 제외한다.
/// 스도쿠 생성기의 배치 검증과 화면의 규칙 충돌 검사가 이 함수 하나를 공유한다.
bool _hasConflictAt(
  List<List<int>> grid,
  int row,
  int col,
  int value, {
  bool ignoreSelf = false,
}) {
  if (value == 0) return false;

  for (int i = 0; i < kBoardSize; i++) {
    if (!(ignoreSelf && i == col) && grid[row][i] == value) return true;
    if (!(ignoreSelf && i == row) && grid[i][col] == value) return true;
  }

  int boxRow = (row ~/ kBoxSize) * kBoxSize;
  int boxCol = (col ~/ kBoxSize) * kBoxSize;
  for (int r = 0; r < kBoxSize; r++) {
    for (int c = 0; c < kBoxSize; c++) {
      int currR = boxRow + r;
      int currC = boxCol + c;
      if (!(ignoreSelf && currR == row && currC == col) &&
          grid[currR][currC] == value) {
        return true;
      }
    }
  }
  return false;
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
    List<List<int>> solution = _copyBoard(fullBoard);

    // 5. 난이도별 채워질 칸 수에 맞춰 빈칸 생성
    List<List<int>> puzzle = _copyBoard(fullBoard);
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
    return !_hasConflictAt(grid, row, col, num);
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

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SudokuScreen(),
    );
  }
}

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  int currentLevel = 1;

  // 9x9 스도쿠 보드 데이터 (0은 빈 칸)
  late List<List<int>> board;
  late List<List<int>> initialBoard;
  late List<List<int>> solution;

  // 현재 선택된 칸. 선택된 칸이 없으면 null.
  ({int row, int col})? selectedCell;

  // 게임 완료 여부 (완료 다이얼로그 중복 표시 방지 가드로도 사용)
  bool isCompleted = false;

  // 숫자키(숫자패드 포함) → 입력할 숫자 매핑. 코드 중복 없이 한 번에 조회한다.
  // LogicalKeyboardKey는 커스텀 ==/hashCode를 가지고 있어 const map의 키로 쓸 수 없으므로 static final로 선언한다.
  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad9: 9,
  };

  @override
  void initState() {
    super.initState();
    _startNewGame(currentLevel);
  }

  // 새로운 게임 시작
  void _startNewGame(int level) {
    final puzzle = SudokuGenerator.generate(level);
    setState(() {
      // generate()는 존재하지 않는 레벨이 들어오면 레벨 1로 안전하게 대체하므로,
      // currentLevel도 원래 파라미터가 아니라 실제로 생성된 난이도 값을 따라간다.
      currentLevel = puzzle.levelInfo.level;
      initialBoard = _copyBoard(puzzle.initialBoard);
      board = _copyBoard(initialBoard);
      solution = puzzle.solution;
      selectedCell = null;
      isCompleted = false;
    });
  }

  // 현재 퍼즐 초기 상태로 리셋
  void _resetCurrentGame() {
    setState(() {
      board = _copyBoard(initialBoard);
      selectedCell = null;
      isCompleted = false;
    });
  }

  // 숫자 입력 함수
  void _inputNumber(int number) {
    final cell = selectedCell;
    if (cell == null) return;

    // 초기 힌트 칸은 수정 불가
    if (initialBoard[cell.row][cell.col] != 0) {
      return;
    }
    setState(() {
      board[cell.row][cell.col] = number;
    });

    _checkGameCompletion();
  }

  // 게임 완성 여부 검사
  //
  // 생성기가 만드는 퍼즐은 유일해(unique solution)를 보장하지 않으므로,
  // 저장된 solution과의 셀 단위 일치가 아니라 "빈 칸이 없고 규칙 충돌이 없는지"로 완성을 판정한다.
  // 이렇게 하면 플레이어가 생성기와 다른, 그러나 스도쿠 규칙상 유효한 정답을 채워도 정상적으로 인정된다.
  void _checkGameCompletion() {
    if (isCompleted) return; // 이미 완료 처리된 게임에서는 다이얼로그를 다시 띄우지 않는다.

    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        if (board[r][c] == 0 || _hasConflict(r, c)) {
          return;
        }
      }
    }

    setState(() {
      isCompleted = true;
    });

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    final info = difficultyForLevel(currentLevel);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('축하합니다!'),
          ],
        ),
        content: Text(
          '레벨 $currentLevel (${info.title}) 스도쿠를 성공적으로 완성했습니다!',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (currentLevel < 10)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startNewGame(currentLevel + 1);
              },
              icon: const Icon(Icons.arrow_forward),
              label: Text('레벨 ${currentLevel + 1} 도전'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewGame(currentLevel);
            },
            child: const Text('새 게임'),
          ),
        ],
      ),
    );
  }

  // 방향키로 선택 이동 함수
  void _moveSelection(int dRow, int dCol) {
    setState(() {
      final cell = selectedCell;
      if (cell == null) {
        selectedCell = (row: 0, col: 0);
      } else {
        selectedCell = (
          row: (cell.row + dRow).clamp(0, kBoardSize - 1),
          col: (cell.col + dCol).clamp(0, kBoardSize - 1),
        );
      }
    });
  }

  // 규칙 충돌 검사 (행, 열, 박스 내 중복 여부)
  bool _hasConflict(int row, int col) {
    return _hasConflictAt(board, row, col, board[row][col], ignoreSelf: true);
  }

  // 키보드 이벤트 처리
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // KeyDownEvent(최초 입력)뿐 아니라 KeyRepeatEvent(길게 눌러 반복 입력)도 처리해야
    // 키를 누르고 있을 때 숫자 입력/이동이 계속 반복된다.
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      // 1 ~ 9 숫자키 (숫자패드 포함)
      final digit = _digitKeys[key];
      if (digit != null) {
        _inputNumber(digit);
        return KeyEventResult.handled;
      }

      // 지우기 (Backspace, Delete, 숫자 0)
      if (key == LogicalKeyboardKey.backspace ||
          key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0) {
        _inputNumber(0);
        return KeyEventResult.handled;
      }

      // 방향키 이동 (↑, ↓, ←, →)
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveSelection(-1, 0);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveSelection(1, 0);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveSelection(0, -1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveSelection(0, 1);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // 상단 난이도 설정 패널 위젯
  Widget _buildTopDifficultyPanel(ColorScheme colorScheme) {
    final currentInfo = difficultyForLevel(currentLevel);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colorScheme.primaryContainer, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상단 줄: 난이도 드롭다운 + 게임 제어 버튼들
          Row(
            children: [
              // 난이도 라벨 아이콘
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded,
                    size: 20, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 8),
              // 난이도 선택 드롭다운
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: currentLevel,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    items: kDifficultyLevels.map((info) {
                      return DropdownMenuItem<int>(
                        value: info.level,
                        child: Text(
                          '레벨 ${info.level} (${info.title}) - ${info.filledCells}칸 채움',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (newLevel) {
                      if (newLevel != null && newLevel != currentLevel) {
                        _startNewGame(newLevel);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 새 게임 버튼
              IconButton.filledTonal(
                tooltip: '새 게임 생성',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => _startNewGame(currentLevel),
              ),
              const SizedBox(width: 4),
              // 초기화 버튼
              IconButton.filledTonal(
                tooltip: '처음 상태로 초기화',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.tertiaryContainer,
                  foregroundColor: colorScheme.onTertiaryContainer,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                onPressed: _resetCurrentGame,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 하단 가로 스크롤 레벨 빠른 선택 칩 바
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kDifficultyLevels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final info = kDifficultyLevels[index];
                final isSelected = info.level == currentLevel;
                return ChoiceChip(
                  label: Text('Lv.${info.level} (${info.filledCells})'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (selected) {
                    if (selected && info.level != currentLevel) {
                      _startNewGame(info.level);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // 칸 정보 요약 바
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9×9 보드 채워진 숫자: ${currentInfo.filledCells}개',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                '남은 빈칸: ${currentInfo.emptyCells}개',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final boardSize =
        min(screenSize.width * 0.9, min(screenSize.height * 0.52, 450.0));
    final selection = selectedCell;
    final selectedVal =
        selection != null ? board[selection.row][selection.col] : 0;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: const Text('Sudoku Game',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: colorScheme.primaryContainer,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. 상단 난이도 설정 패널
              _buildTopDifficultyPanel(colorScheme),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 2. 스도쿠 9x9 보드
                        SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: colorScheme.outline, width: 2.5),
                            ),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: kBoardSize,
                              ),
                              itemCount: kTotalCells,
                              itemBuilder: (context, index) {
                                int row = index ~/ kBoardSize;
                                int col = index % kBoardSize;
                                bool isSelected = selection != null &&
                                    row == selection.row &&
                                    col == selection.col;
                                bool isInitial = initialBoard[row][col] != 0;
                                int val = board[row][col];
                                bool hasConflict = _hasConflict(row, col);

                                // 관련 영역 하이라이트 (같은 행, 같은 열, 같은 3x3 박스)
                                bool isRelated = selection != null &&
                                    (row == selection.row ||
                                        col == selection.col ||
                                        (row ~/ kBoxSize == selection.row ~/ kBoxSize &&
                                            col ~/ kBoxSize == selection.col ~/ kBoxSize));
                                // 같은 숫자 하이라이트
                                bool isSameNumber =
                                    (val != 0 && selectedVal != 0 && val == selectedVal);

                                Color cellBgColor = colorScheme.surface;
                                if (isSelected) {
                                  cellBgColor = colorScheme.primary.withValues(alpha: 0.4);
                                } else if (hasConflict && !isInitial) {
                                  cellBgColor = colorScheme.errorContainer;
                                } else if (isSameNumber) {
                                  cellBgColor = colorScheme.primaryContainer;
                                } else if (isRelated) {
                                  cellBgColor =
                                      colorScheme.primaryContainer.withValues(alpha: 0.4);
                                } else if (isInitial) {
                                  cellBgColor = colorScheme.surfaceContainerLow;
                                }

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedCell = (row: row, col: col);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cellBgColor,
                                      border: Border(
                                        top: BorderSide(
                                          width: row % kBoxSize == 0 ? 2.0 : 0.5,
                                          color: row % kBoxSize == 0
                                              ? colorScheme.outline
                                              : colorScheme.outlineVariant,
                                        ),
                                        left: BorderSide(
                                          width: col % kBoxSize == 0 ? 2.0 : 0.5,
                                          color: col % kBoxSize == 0
                                              ? colorScheme.outline
                                              : colorScheme.outlineVariant,
                                        ),
                                        right: BorderSide(
                                          width: col == kBoardSize - 1 ? 2.0 : 0.5,
                                          color: col == kBoardSize - 1
                                              ? colorScheme.outline
                                              : colorScheme.outlineVariant,
                                        ),
                                        bottom: BorderSide(
                                          width: row == kBoardSize - 1 ? 2.0 : 0.5,
                                          color: row == kBoardSize - 1
                                              ? colorScheme.outline
                                              : colorScheme.outlineVariant,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        val == 0 ? '' : '$val',
                                        style: TextStyle(
                                          fontSize: boardSize / 20,
                                          fontWeight:
                                              isInitial ? FontWeight.w900 : FontWeight.bold,
                                          color: isInitial
                                              ? colorScheme.onSurface
                                              : (hasConflict
                                                  ? colorScheme.error
                                                  : colorScheme.primary),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. 하단 숫자 패드
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...List.generate(kBoardSize, (index) {
                                int number = index + 1;
                                return SizedBox(
                                  width: 40,
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: colorScheme.surface,
                                      foregroundColor: colorScheme.onSurface,
                                      elevation: 1.5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: colorScheme.outlineVariant),
                                      ),
                                    ),
                                    onPressed: () => _inputNumber(number),
                                    child: Text(
                                      '$number',
                                      style:
                                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colorScheme.errorContainer,
                                    foregroundColor: colorScheme.onErrorContainer,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.backspace_outlined, size: 20),
                                  onPressed: () => _inputNumber(0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
