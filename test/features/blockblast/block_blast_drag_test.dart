import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/core/storage/score_store.dart';
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

void main() {
  late BlockBlastController controller;

  setUp(() {
    controller = BlockBlastController(
      scoreStore: MemoryScoreStore(),
      pieceFactory: () => piece(['X']),
    );
  });

  tearDown(() => controller.dispose());

  testWidgets('트레이 조각을 보드로 드래그하면 조준한 칸에 정확히 놓인다',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await dragTrayPieceTo(tester, piece(['X']), 3, 5);

    expect(controller.grid.isFilled(3, 5), isTrue,
        reason: '조준한 (3,5) 칸이 채워져야 한다');
    // 의도한 칸 하나만 채워졌는지 확인한다.
    var filled = 0;
    for (int r = 0; r < kBlockGridSize; r++) {
      for (int c = 0; c < kBlockGridSize; c++) {
        if (controller.grid.isFilled(r, c)) filled++;
      }
    }
    expect(filled, 1);
  });

  testWidgets('드래그 중에는 착지 지점 미리보기가 표시된다',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(BlockPieceView).first));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(pointerForCell(tester, piece(['X']), 2, 2));
    await tester.pump();

    expect(controller.preview, isNotNull);
    expect(controller.preview!.row, 2);
    expect(controller.preview!.col, 2);
    expect(controller.preview!.valid, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.preview, isNull, reason: '드롭 후 미리보기는 사라져야 한다');
  });

  testWidgets('이미 찬 칸에 겹쳐 놓으면 배치가 거부된다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    controller.grid.fillCell(4, 4, 1);
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await dragTrayPieceTo(tester, piece(['X']), 4, 4);

    expect(controller.score, 0, reason: '거부된 배치는 점수를 주지 않아야 한다');
    expect(controller.tray[0], isNotNull, reason: '조각이 트레이에 남아야 한다');
  });
}
