import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/features/blockblast/controller/block_blast_controller.dart';
import 'package:sudoku_app/features/blockblast/domain/block_grid.dart';
import 'package:sudoku_app/features/blockblast/domain/block_piece.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_blast_board.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_colors.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_drag.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_tray.dart';

const double kTestBoardSize = 320;
const double kTestCellSize = kTestBoardSize / kBlockGridSize; // 40

BlockPiece piece(List<String> pattern) => BlockPiece.fromPattern(pattern, 0);

/// 보드와 트레이만 담은 최소 위젯 트리
Widget harness(BlockBlastController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<BlockBlastController>.value(
        value: controller,
        child: Column(
          children: [
            const BlockBlastBoard(boardSize: kTestBoardSize),
            const SizedBox(height: 20),
            BlockTray(boardCellSize: kTestCellSize, slotSize: 80),
          ],
        ),
      ),
    ),
  );
}

/// 테스트 화면을 넉넉한 크기로 고정한다.
void useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 조각의 좌상단이 보드 (row, col)에 놓이도록 하는 포인터 위치를 역산한다.
///
/// 보드는 `포인터 + blockDragLift`를 조각의 좌상단으로 해석하므로,
/// 원하는 좌상단에서 lift를 빼면 포인터가 있어야 할 곳이 나온다.
Offset pointerForCell(WidgetTester tester, BlockPiece p, int row, int col) {
  final boardTopLeft = tester.getTopLeft(find.byType(BlockBlastBoard));
  final desiredTopLeft =
      boardTopLeft + Offset(col * kTestCellSize, row * kTestCellSize);
  return desiredTopLeft - blockDragLift(p, kTestCellSize);
}

/// 트레이 첫 조각을 보드 (row, col)로 끌어다 놓는다.
Future<void> dragTrayPieceTo(
  WidgetTester tester,
  BlockPiece p,
  int row,
  int col,
) async {
  final source = tester.getCenter(find.byType(BlockPieceView).first);
  final gesture = await tester.startGesture(source);
  // 터치 슬롭을 넘겨 드래그를 시작시킨다.
  await gesture.moveBy(const Offset(0, -30));
  await tester.pump();
  await gesture.moveTo(pointerForCell(tester, p, row, col));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}
