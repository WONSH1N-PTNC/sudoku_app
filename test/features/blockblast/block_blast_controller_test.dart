import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/core/storage/score_store.dart';
import 'package:sudoku_app/features/blockblast/controller/block_blast_controller.dart';
import 'package:sudoku_app/features/blockblast/domain/block_grid.dart';
import 'package:sudoku_app/features/blockblast/domain/block_piece.dart';

BlockPiece piece(List<String> pattern) => BlockPiece.fromPattern(pattern, 0);

/// 호출 순서대로 조각을 돌려주는 팩토리 (마지막 조각을 계속 반복한다).
BlockPiece Function() sequence(List<BlockPiece> pieces) {
  var i = 0;
  return () => pieces[i < pieces.length - 1 ? i++ : pieces.length - 1];
}

void main() {
  group('BlockBlastController', () {
    test('새 게임은 점수 0, 트레이 가득, 게임오버 아님으로 시작한다', () {
      final c = BlockBlastController(scoreStore: MemoryScoreStore());
      addTearDown(c.dispose);

      expect(c.score, 0);
      expect(c.comboCount, 0);
      expect(c.isGameOver, isFalse);
      expect(c.tray.whereType<BlockPiece>().length, kTraySize);
    });

    test('저장된 최고 점수를 불러온다', () async {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore({kBlockBlastGameId: 1234}),
      );
      addTearDown(c.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(c.highScore, 1234);
    });

    test('조각을 놓으면 칸 수만큼 점수가 오른다', () {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['XXX'])]),
      );
      addTearDown(c.dispose);

      expect(c.placePiece(0, 0, 0), isTrue);
      expect(c.score, 3);
      expect(c.grid.isFilled(0, 0), isTrue);
      expect(c.tray[0], isNull);
    });

    test('놓을 수 없는 위치면 아무 것도 바뀌지 않는다', () {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['X'])]),
      );
      addTearDown(c.dispose);

      expect(c.placePiece(0, -1, 0), isFalse);
      expect(c.placePiece(0, kBlockGridSize, 0), isFalse);
      expect(c.score, 0);
      expect(c.tray[0], isNotNull);
    });

    test('세 조각을 모두 쓰면 트레이가 다시 채워진다', () {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['X'])]),
      );
      addTearDown(c.dispose);

      c.placePiece(0, 0, 0);
      c.placePiece(1, 2, 0);
      expect(c.tray.whereType<BlockPiece>().length, 1);

      c.placePiece(2, 4, 0);
      expect(c.tray.whereType<BlockPiece>().length, kTraySize);
    });

    test('줄을 지우면 제거 점수가 더해진다', () {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['X'])]),
      );
      addTearDown(c.dispose);

      // 0행의 마지막 한 칸만 남기고 채워둔다.
      for (int col = 0; col < kBlockGridSize - 1; col++) {
        c.grid.fillCell(0, col, 1);
      }
      c.placePiece(0, 0, kBlockGridSize - 1);

      // 놓은 칸 1점 + 한 줄 제거 100점 (콤보 1단계)
      expect(c.score, 101);
      expect(c.comboCount, 1);
      expect(c.grid.isFilled(0, 0), isFalse);
    });

    test('줄을 지우지 못한 배치는 콤보를 끊는다', () {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['X'])]),
      );
      addTearDown(c.dispose);

      for (int col = 0; col < kBlockGridSize - 1; col++) {
        c.grid.fillCell(0, col, 1);
      }
      c.placePiece(0, 0, kBlockGridSize - 1);
      expect(c.comboCount, 1);

      c.placePiece(1, 4, 4); // 줄과 무관한 위치
      expect(c.comboCount, 0);
    });

    test('남은 조각을 놓을 자리가 없으면 게임오버가 되고 최고 점수가 저장된다', () async {
      final store = MemoryScoreStore();
      // 첫 조각은 1x1, 이후로는 3x3만 나온다.
      final c = BlockBlastController(
        scoreStore: store,
        pieceFactory: sequence([piece(['X']), piece(['XXX', 'XXX', 'XXX'])]),
      );
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);

      // 2행과 5행을 거의 채워 세 행 연속으로 비는 구간을 없앤다.
      // (한 칸씩 남겨 배치 시 줄이 지워지지 않게 한다)
      for (final row in [2, 5]) {
        for (int col = 0; col < kBlockGridSize - 1; col++) {
          c.grid.fillCell(row, col, 1);
        }
      }
      expect(c.isGameOver, isFalse);

      // 1x1을 놓고 나면 남은 두 조각(3x3)은 어디에도 들어가지 않는다.
      expect(c.placePiece(0, 7, 0), isTrue);
      expect(c.isGameOver, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(await store.readHighScore(kBlockBlastGameId), c.score);
    });

    test('게임오버 후 새 게임을 시작하면 상태가 초기화된다', () async {
      final c = BlockBlastController(
        scoreStore: MemoryScoreStore(),
        pieceFactory: sequence([piece(['X']), piece(['XXX', 'XXX', 'XXX'])]),
      );
      addTearDown(c.dispose);

      for (final row in [2, 5]) {
        for (int col = 0; col < kBlockGridSize - 1; col++) {
          c.grid.fillCell(row, col, 1);
        }
      }
      c.placePiece(0, 7, 0);
      expect(c.isGameOver, isTrue);

      c.startNewGame();
      expect(c.isGameOver, isFalse);
      expect(c.score, 0);
      expect(c.grid.isFilled(2, 0), isFalse);
    });
  });
}
