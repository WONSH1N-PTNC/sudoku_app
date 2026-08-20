import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
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
  // 9x9 스도쿠 보드 데이터 (0은 빈 칸)
  List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));

  // 현재 선택된 칸의 행(row)과 열(col)
  int selectedRow = -1;
  int selectedCol = -1;

  // 숫자 입력 함수
  void _inputNumber(int number) {
    if (selectedRow != -1 && selectedCol != -1) {
      setState(() {
        board[selectedRow][selectedCol] = number;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 맞추어 스도쿠판의 최대 크기 계산 (최대 450px)
    final screenSize = MediaQuery.of(context).size;
    final boardSize = min(screenSize.width * 0.9, min(screenSize.height * 0.55, 450.0));

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sudoku Game', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.indigo.shade100,
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. 스도쿠 9x9 보드 (크기 자동 제한)
                SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: Container(
                    decoration: BoxDecoration(
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

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRow = row;
                              selectedCol = col;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.indigo.shade100 : Colors.white,
                              border: Border(
                                top: BorderSide(
                                  width: row % 3 == 0 ? 2.0 : 0.5,
                                  color: row % 3 == 0 ? Colors.black : Colors.grey,
                                ),
                                left: BorderSide(
                                  width: col % 3 == 0 ? 2.0 : 0.5,
                                  color: col % 3 == 0 ? Colors.black : Colors.grey,
                                ),
                                right: BorderSide(
                                  width: col == 8 ? 2.0 : 0.5,
                                  color: col == 8 ? Colors.black : Colors.grey,
                                ),
                                bottom: BorderSide(
                                  width: row == 8 ? 2.0 : 0.5,
                                  color: row == 8 ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                board[row][col] == 0 ? '' : '${board[row][col]}',
                                style: TextStyle(
                                  fontSize: boardSize / 20, // 보드 크기에 맞춘 폰트 크기
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. 하단 숫자 패드
                Wrap(
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
                      child: IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        color: Colors.redAccent,
                        onPressed: () => _inputNumber(0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}