import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/core/storage/score_store.dart';
import 'package:sudoku_app/features/blockblast/controller/block_blast_controller.dart';
import 'package:sudoku_app/features/blockblast/domain/block_grid.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_colors.dart';

import 'blockblast_harness.dart';

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
    useLargeSurface(tester);

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
    useLargeSurface(tester);

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
    useLargeSurface(tester);

    controller.grid.fillCell(4, 4, 1);
    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await dragTrayPieceTo(tester, piece(['X']), 4, 4);

    expect(controller.score, 0, reason: '거부된 배치는 점수를 주지 않아야 한다');
    expect(controller.tray[0], isNotNull, reason: '조각이 트레이에 남아야 한다');
  });

  testWidgets('마지막 줄(7행)에도 조각을 놓을 수 있다', (WidgetTester tester) async {
    useLargeSurface(tester);

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await dragTrayPieceTo(tester, piece(['X']), kBlockGridSize - 1, 3);

    expect(controller.grid.isFilled(kBlockGridSize - 1, 3), isTrue,
        reason: '마지막 줄을 조준하면 손가락이 보드 아래로 내려가지만 배치는 성공해야 한다');
  });

  testWidgets('세로로 긴 조각도 보드 하단에 놓을 수 있다', (WidgetTester tester) async {
    useLargeSurface(tester);

    final tall = piece(['X', 'X', 'X']);
    final c = BlockBlastController(
      scoreStore: MemoryScoreStore(),
      pieceFactory: () => tall,
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(harness(c));
    await tester.pumpAndSettle();

    // 5,6,7행을 차지하도록 좌상단을 5행에 맞춘다.
    await dragTrayPieceTo(tester, tall, kBlockGridSize - 3, 2);

    expect(c.grid.isFilled(kBlockGridSize - 3, 2), isTrue);
    expect(c.grid.isFilled(kBlockGridSize - 1, 2), isTrue);
  });
}
