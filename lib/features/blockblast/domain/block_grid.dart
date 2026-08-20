import 'package:flutter/foundation.dart';

import 'block_piece.dart';

/// Block Blast 보드 한 변의 칸 수 (8x8)
const int kBlockGridSize = 8;

/// 빈 칸을 나타내는 값 (채워진 칸은 0 이상의 팔레트 색상 인덱스)
const int kEmptyCell = -1;

/// 한 줄을 지웠을 때의 기본 점수
const int kLineClearBase = 100;

/// 동시에 여러 줄을 지웠을 때 두 번째 줄부터 추가되는 점수
const int kExtraLineBonus = 200;

/// 줄 제거를 연속으로 성공했을 때 콤보 단계마다 붙는 배수 증가폭
const double kComboStep = 0.5;

/// 한 번의 배치로 지워진 줄과 얻은 점수
class ClearResult {
  const ClearResult({
    required this.clearedRows,
    required this.clearedCols,
    required this.score,
  });

  final List<int> clearedRows;
  final List<int> clearedCols;

  /// 콤보 배수까지 반영된 최종 획득 점수
  final int score;

  int get clearedLineCount => clearedRows.length + clearedCols.length;
  bool get didClear => clearedLineCount > 0;
}

/// 8x8 보드 상태와 배치 · 줄 제거 규칙.
///
/// UI와 무관한 순수 로직이라 단위 테스트가 가능하다.
class BlockGrid {
  BlockGrid()
      : _cells = List.generate(
          kBlockGridSize,
          (_) => List.filled(kBlockGridSize, kEmptyCell),
        );

  final List<List<int>> _cells;

  int cellAt(int row, int col) => _cells[row][col];
  bool isFilled(int row, int col) => _cells[row][col] != kEmptyCell;

  /// 보드를 모두 비운다.
  void clear() {
    for (int r = 0; r < kBlockGridSize; r++) {
      for (int c = 0; c < kBlockGridSize; c++) {
        _cells[r][c] = kEmptyCell;
      }
    }
  }

  /// 특정 칸을 직접 채운다. 줄 제거 판정 없이 보드 상태만 구성하므로
  /// 테스트에서 원하는 배치를 만들 때만 사용한다.
  @visibleForTesting
  void fillCell(int row, int col, int colorIndex) {
    _cells[row][col] = colorIndex;
  }

  /// [piece]의 좌상단을 (row, col)에 맞췄을 때 놓을 수 있는지 검사한다.
  bool canPlace(BlockPiece piece, int row, int col) {
    for (final (dr, dc) in piece.cells) {
      final r = row + dr;
      final c = col + dc;
      if (r < 0 || r >= kBlockGridSize || c < 0 || c >= kBlockGridSize) {
        return false;
      }
      if (_cells[r][c] != kEmptyCell) return false;
    }
    return true;
  }

  /// 보드 어디에든 [piece]를 놓을 자리가 있는지 검사한다.
  bool canPlaceAnywhere(BlockPiece piece) {
    for (int r = 0; r < kBlockGridSize; r++) {
      for (int c = 0; c < kBlockGridSize; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  /// [piece]를 (row, col)에 놓고 가득 찬 행·열을 지운 뒤 획득 점수를 돌려준다.
  ///
  /// [comboCount]는 이번 배치까지 포함한 연속 줄 제거 횟수(1부터)이며,
  /// 콤보 배수 계산에 쓰인다. 놓을 수 없는 위치면 [StateError]를 던진다.
  ClearResult place(BlockPiece piece, int row, int col, {required int comboCount}) {
    if (!canPlace(piece, row, col)) {
      throw StateError('($row, $col)에는 조각을 놓을 수 없습니다');
    }
    for (final (dr, dc) in piece.cells) {
      _cells[row + dr][col + dc] = piece.colorIndex;
    }
    return _clearFullLines(comboCount: comboCount);
  }

  /// 가득 찬 행과 열을 찾아 동시에 지운다.
  ///
  /// 행과 열을 먼저 모두 판정한 뒤 지워야 한다. 하나씩 지우면서 판정하면
  /// 먼저 지운 행 때문에 원래 가득 찼던 열이 판정에서 누락된다.
  ClearResult _clearFullLines({required int comboCount}) {
    final fullRows = <int>[];
    final fullCols = <int>[];

    for (int r = 0; r < kBlockGridSize; r++) {
      if (List.generate(kBlockGridSize, (c) => c).every((c) => isFilled(r, c))) {
        fullRows.add(r);
      }
    }
    for (int c = 0; c < kBlockGridSize; c++) {
      if (List.generate(kBlockGridSize, (r) => r).every((r) => isFilled(r, c))) {
        fullCols.add(c);
      }
    }

    for (final r in fullRows) {
      for (int c = 0; c < kBlockGridSize; c++) {
        _cells[r][c] = kEmptyCell;
      }
    }
    for (final c in fullCols) {
      for (int r = 0; r < kBlockGridSize; r++) {
        _cells[r][c] = kEmptyCell;
      }
    }

    return ClearResult(
      clearedRows: fullRows,
      clearedCols: fullCols,
      score: scoreForLines(fullRows.length + fullCols.length, comboCount),
    );
  }

  /// 줄 제거 점수 계산: 첫 줄 100점, 추가 줄마다 200점, 콤보 단계마다 50%씩 가산.
  static int scoreForLines(int lineCount, int comboCount) {
    if (lineCount <= 0) return 0;
    final base = kLineClearBase + kExtraLineBonus * (lineCount - 1);
    final multiplier = 1 + kComboStep * (comboCount - 1).clamp(0, 100);
    return (base * multiplier).round();
  }
}
