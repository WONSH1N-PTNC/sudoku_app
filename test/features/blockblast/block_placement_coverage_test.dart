import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/core/storage/score_store.dart';
import 'package:sudoku_app/features/blockblast/controller/block_blast_controller.dart';
import 'package:sudoku_app/features/blockblast/domain/block_grid.dart';
import 'package:sudoku_app/features/blockblast/domain/block_piece.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_colors.dart';
import 'package:sudoku_app/features/blockblast/presentation/block_drag.dart';

import 'blockblast_harness.dart';

/// 정의된 모든 조각 모양이 보드의 네 모서리(상단 첫 줄 · 하단 마지막 줄 ×
/// 첫 열 · 마지막 열)에 실제 드래그로 놓이는지 전수 검증한다.
///
/// 가운데만 검증하면 히트 테스트가 보드 경계를 벗어나는 문제를 놓친다.
void main() {
  testWidgets('모든 조각을 보드 상·하단 끝 줄에 드래그로 놓을 수 있다',
      (WidgetTester tester) async {
    useLargeSurface(tester);

    final controllers = <BlockBlastController>[];
    addTearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    final failures = <String>[];

    for (final pattern in kBlockPatterns) {
      final p = piece(pattern);
      final maxRow = kBlockGridSize - p.height;
      final maxCol = kBlockGridSize - p.width;

      for (final row in <int>{0, maxRow}) {
        for (final col in <int>{0, maxCol}) {
          final controller = BlockBlastController(
            scoreStore: MemoryScoreStore(),
            pieceFactory: () => p,
          );
          controllers.add(controller);

          await tester.pumpWidget(harness(controller));
          await tester.pumpAndSettle();
          await dragTrayPieceTo(tester, p, row, col);

          final placed = p.cells.every(
            (cell) => controller.grid.isFilled(row + cell.$1, col + cell.$2),
          );
          if (!placed) {
            failures.add('${pattern.join("|")} (${p.width}x${p.height}) -> ($row,$col)');
          }
        }
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      failures,
      isEmpty,
      reason: '다음 조각/위치 조합에서 배치가 실패했습니다:\n${failures.join("\n")}',
    );
  });


  testWidgets('조각 가운데가 빈 칸이어도 그 지점에서 드래그를 시작할 수 있다',
      (WidgetTester tester) async {
    useLargeSurface(tester);

    // 바운딩 박스 한가운데가 빈 칸인 L자 조각
    final lShape = piece(['X..', 'X..', 'XXX']);
    final controller = BlockBlastController(
      scoreStore: MemoryScoreStore(),
      pieceFactory: () => lShape,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    await dragTrayPieceTo(tester, lShape, 0, 0);

    expect(controller.grid.isFilled(0, 0), isTrue,
        reason: '조각의 빈 칸을 짚어도 드래그가 시작되어야 한다');
    expect(controller.grid.isFilled(2, 2), isTrue);
  });

  testWidgets('조각 바깥 슬롯 여백을 짚어도 드래그가 시작된다',
      (WidgetTester tester) async {
    useLargeSurface(tester);

    // 1x1 조각은 슬롯보다 작아 주변에 빈 여백이 생긴다.
    final dot = piece(['X']);
    final controller = BlockBlastController(
      scoreStore: MemoryScoreStore(),
      pieceFactory: () => dot,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(harness(controller));
    await tester.pumpAndSettle();

    final slot = find.byType(Draggable<BlockDragData>).first;
    final slotRect = tester.getRect(slot);
    final pieceRect = tester.getRect(find.byType(BlockPieceView).first);
    expect(slotRect.contains(slotRect.topLeft + const Offset(2, 2)), isTrue);
    expect(pieceRect.contains(slotRect.topLeft + const Offset(2, 2)), isFalse,
        reason: '이 지점은 조각 바깥이어야 테스트가 의미 있다');

    final gesture = await tester.startGesture(slotRect.topLeft + const Offset(2, 2));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(pointerForCell(tester, dot, 4, 4));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.grid.isFilled(4, 4), isTrue,
        reason: '슬롯 여백을 짚어도 조각을 끌 수 있어야 한다');
  });
}
