import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SudokuApp());
}

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

  int get emptyCells => 81 - filledCells;
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

/// 스도쿠 생성기
class SudokuGenerator {
  static SudokuPuzzle generate(int level) {
    final diff = kDifficultyLevels.firstWhere(
      (d) => d.level == level,
      orElse: () => kDifficultyLevels[0],
    );
    final targetFilled = diff.filledCells;
    final random = Random();

    // 1. 9x9 빈 보드 생성
    List<List<int>> fullBoard = List.generate(9, (_) => List.filled(9, 0));

    // 2. 대각선 3개 3x3 박스 독립 채우기 (0,0), (3,3), (6,6)
    for (int i = 0; i < 9; i += 3) {
      _fillBox(fullBoard, i, i, random);
    }

    // 3. 백트래킹으로 나머지 칸 채워 완전한 스도쿠 완성
    _solve(fullBoard, random);

    // 4. 정답 보드 복사
    List<List<int>> solution = List.generate(9, (r) => List.from(fullBoard[r]));

    // 5. 난이도별 채워질 칸 수에 맞춰 빈칸 생성
    List<List<int>> puzzle = List.generate(9, (r) => List.from(fullBoard[r]));
    int cellsToRemove = 81 - targetFilled;

    List<Point<int>> positions = [];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
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

  static void _fillBox(List<List<int>> grid, int startRow, int startCol, Random random) {
    List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(random);
    int idx = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        grid[startRow + r][startCol + c] = numbers[idx++];
      }
    }
  }

  static bool _isValid(List<List<int>> grid, int row, int col, int num) {
    for (int i = 0; i < 9; i++) {
      if (grid[row][i] == num) return false;
      if (grid[i][col] == num) return false;
    }
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (grid[boxRow + r][boxCol + c] == num) return false;
      }
    }
    return true;
  }

  static bool _solve(List<List<int>> grid, Random random) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (grid[r][c] == 0) {
          List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(random);
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

  // 현재 선택된 칸의 행(row)과 열(col)
  int selectedRow = -1;
  int selectedCol = -1;

  // 게임 완료 여부
  bool isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startNewGame(currentLevel);
  }

  // 새로운 게임 시작
  void _startNewGame(int level) {
    final puzzle = SudokuGenerator.generate(level);
    setState(() {
      currentLevel = level;
      initialBoard = List.generate(9, (r) => List.from(puzzle.initialBoard[r]));
      board = List.generate(9, (r) => List.from(puzzle.initialBoard[r]));
      solution = puzzle.solution;
      selectedRow = -1;
      selectedCol = -1;
      isCompleted = false;
    });
  }

  // 현재 퍼즐 초기 상태로 리셋
  void _resetCurrentGame() {
    setState(() {
      board = List.generate(9, (r) => List.from(initialBoard[r]));
      selectedRow = -1;
      selectedCol = -1;
      isCompleted = false;
    });
  }

  // 숫자 입력 함수
  void _inputNumber(int number) {
    if (selectedRow != -1 && selectedCol != -1) {
      // 초기 힌트 칸은 수정 불가
      if (initialBoard[selectedRow][selectedCol] != 0) {
        return;
      }
      setState(() {
        board[selectedRow][selectedCol] = number;
      });

      _checkGameCompletion();
    }
  }

  // 게임 완성 여부 검사
  void _checkGameCompletion() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0 || board[r][c] != solution[r][c]) {
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
          '레벨 $currentLevel (${kDifficultyLevels[currentLevel - 1].title}) 스도쿠를 성공적으로 완성했습니다!',
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
      if (selectedRow == -1 || selectedCol == -1) {
        selectedRow = 0;
        selectedCol = 0;
      } else {
        selectedRow = (selectedRow + dRow).clamp(0, 8);
        selectedCol = (selectedCol + dCol).clamp(0, 8);
      }
    });
  }

  // 규칙 충돌 검사 (행, 열, 박스 내 중복 여부)
  bool _hasConflict(int row, int col) {
    int val = board[row][col];
    if (val == 0) return false;

    // 행 검사
    for (int c = 0; c < 9; c++) {
      if (c != col && board[row][c] == val) return true;
    }
    // 열 검사
    for (int r = 0; r < 9; r++) {
      if (r != row && board[r][col] == val) return true;
    }
    // 3x3 박스 검사
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        int currR = boxRow + r;
        int currC = boxCol + c;
        if ((currR != row || currC != col) && board[currR][currC] == val) {
          return true;
        }
      }
    }
    return false;
  }

  // 키보드 이벤트 처리
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

      // 1 ~ 9 숫자키 (숫자패드 포함)
      if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) { _inputNumber(1); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) { _inputNumber(2); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) { _inputNumber(3); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) { _inputNumber(4); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) { _inputNumber(5); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) { _inputNumber(6); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) { _inputNumber(7); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) { _inputNumber(8); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) { _inputNumber(9); return KeyEventResult.handled; }

      // 지우기 (Backspace, Delete, 숫자 0)
      if (key == LogicalKeyboardKey.backspace ||
          key == LogicalKeyboardKey.delete ||
          key == LogicalKeyboardKey.digit0 ||
          key == LogicalKeyboardKey.numpad0) {
        _inputNumber(0);
        return KeyEventResult.handled;
      }

      // 방향키 이동 (↑, ↓, ←, →)
      if (key == LogicalKeyboardKey.arrowUp) { _moveSelection(-1, 0); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.arrowDown) { _moveSelection(1, 0); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.arrowLeft) { _moveSelection(0, -1); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.arrowRight) { _moveSelection(0, 1); return KeyEventResult.handled; }
    }
    return KeyEventResult.ignored;
  }

  // 상단 난이도 설정 패널 위젯
  Widget _buildTopDifficultyPanel() {
    final currentInfo = kDifficultyLevels.firstWhere((d) => d.level == currentLevel);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.indigo.shade100, width: 1.2),
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
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, size: 20, color: Colors.indigo.shade700),
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
                      color: Colors.indigo.shade900,
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
                  backgroundColor: Colors.indigo.shade50,
                  foregroundColor: Colors.indigo.shade800,
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
                  backgroundColor: Colors.orange.shade50,
                  foregroundColor: Colors.orange.shade800,
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
                    color: isSelected ? Colors.white : Colors.indigo.shade900,
                  ),
                  selected: isSelected,
                  selectedColor: Colors.indigo.shade600,
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide(
                    color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade300,
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
                  color: Colors.indigo.shade700,
                ),
              ),
              Text(
                '남은 빈칸: ${currentInfo.emptyCells}개',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
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
    final screenSize = MediaQuery.of(context).size;
    final boardSize = min(screenSize.width * 0.9, min(screenSize.height * 0.52, 450.0));
    final selectedVal = (selectedRow != -1 && selectedCol != -1) ? board[selectedRow][selectedCol] : 0;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: const Text('Sudoku Game', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.indigo.shade100,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. 상단 난이도 설정 패널
              _buildTopDifficultyPanel(),

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
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.black, width: 2.5),
                            ),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 9,
                              ),
                              itemCount: 81,
                              itemBuilder: (context, index) {
                                int row = index ~/ 9;
                                int col = index % 9;
                                bool isSelected = (row == selectedRow && col == selectedCol);
                                bool isInitial = initialBoard[row][col] != 0;
                                int val = board[row][col];
                                bool hasConflict = _hasConflict(row, col);

                                // 관련 영역 하이라이트 (같은 행, 같은 열, 같은 3x3 박스)
                                bool isRelated = (selectedRow != -1 && selectedCol != -1) &&
                                    (row == selectedRow ||
                                        col == selectedCol ||
                                        (row ~/ 3 == selectedRow ~/ 3 && col ~/ 3 == selectedCol ~/ 3));
                                // 같은 숫자 하이라이트
                                bool isSameNumber = (val != 0 && selectedVal != 0 && val == selectedVal);

                                Color cellBgColor = Colors.white;
                                if (isSelected) {
                                  cellBgColor = Colors.indigo.shade200;
                                } else if (hasConflict && !isInitial) {
                                  cellBgColor = Colors.red.shade100;
                                } else if (isSameNumber) {
                                  cellBgColor = Colors.indigo.shade100;
                                } else if (isRelated) {
                                  cellBgColor = const Color(0xFFEDF2FF);
                                } else if (isInitial) {
                                  cellBgColor = const Color(0xFFF9FAFB);
                                }

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedRow = row;
                                      selectedCol = col;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cellBgColor,
                                      border: Border(
                                        top: BorderSide(
                                          width: row % 3 == 0 ? 2.0 : 0.5,
                                          color: row % 3 == 0 ? Colors.black : Colors.grey.shade400,
                                        ),
                                        left: BorderSide(
                                          width: col % 3 == 0 ? 2.0 : 0.5,
                                          color: col % 3 == 0 ? Colors.black : Colors.grey.shade400,
                                        ),
                                        right: BorderSide(
                                          width: col == 8 ? 2.0 : 0.5,
                                          color: col == 8 ? Colors.black : Colors.grey.shade400,
                                        ),
                                        bottom: BorderSide(
                                          width: row == 8 ? 2.0 : 0.5,
                                          color: row == 8 ? Colors.black : Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        val == 0 ? '' : '$val',
                                        style: TextStyle(
                                          fontSize: boardSize / 20,
                                          fontWeight: isInitial ? FontWeight.w900 : FontWeight.bold,
                                          color: isInitial
                                              ? Colors.black87
                                              : (hasConflict ? Colors.red.shade700 : Colors.indigo.shade800),
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
                              ...List.generate(9, (index) {
                                int number = index + 1;
                                return SizedBox(
                                  width: 40,
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.indigo.shade900,
                                      elevation: 1.5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.indigo.shade100),
                                      ),
                                    ),
                                    onPressed: () => _inputNumber(number),
                                    child: Text(
                                      '$number',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
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