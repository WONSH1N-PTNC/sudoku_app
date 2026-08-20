import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/storage/score_store.dart';
import '../domain/block_grid.dart';
import '../domain/block_piece.dart';

/// 트레이에 한 번에 제시되는 조각 수
const int kTraySize = 3;

/// 최고 점수 저장에 사용할 게임 식별자
const String kBlockBlastGameId = 'blockblast';

/// Block Blast 한 판의 상태(보드 · 트레이 · 점수 · 콤보)를 소유한다.
class BlockBlastController extends ChangeNotifier {
  BlockBlastController({
    ScoreStore? scoreStore,
    Random? random,
    BlockPiece Function()? pieceFactory,
  })  : _scoreStore = scoreStore ?? const PrefsScoreStore(),
        _random = random ?? Random(),
        _pieceFactory = pieceFactory {
    _loadHighScore();
    startNewGame();
  }

  final ScoreStore _scoreStore;
  final Random _random;

  /// 조각 생성 방법. 테스트에서 결정적인 조각을 주입하기 위한 시임이다.
  final BlockPiece Function()? _pieceFactory;

  final BlockGrid grid = BlockGrid();

  /// 트레이의 조각들. 사용한 자리는 null이 되고, 셋 다 비면 새로 채워진다.
  final List<BlockPiece?> _tray = List.filled(kTraySize, null);

  int _score = 0;
  int _highScore = 0;
  int _comboCount = 0;
  bool _isGameOver = false;

  /// 마지막 배치로 지워진 줄 수 (0이면 이번엔 못 지움)
  int _lastClearedLines = 0;

  /// 드래그 중 미리보기 위치. 놓을 수 없는 위치도 표시하기 위해 유효성도 함께 보관한다.
  ({int row, int col, bool valid})? _preview;

  List<BlockPiece?> get tray => List.unmodifiable(_tray);
  int get score => _score;
  int get highScore => _highScore;
  int get comboCount => _comboCount;
  bool get isGameOver => _isGameOver;
  int get lastClearedLines => _lastClearedLines;
  ({int row, int col, bool valid})? get preview => _preview;

  /// 미리보기 중인 조각이 덮는 칸인지 여부 (보드 렌더링에 사용)
  BlockPiece? _previewPiece;
  BlockPiece? get previewPiece => _previewPiece;

  Future<void> _loadHighScore() async {
    _highScore = await _scoreStore.readHighScore(kBlockBlastGameId);
    notifyListeners();
  }

  /// 새 게임 시작
  void startNewGame() {
    grid.clear();
    _score = 0;
    _comboCount = 0;
    _lastClearedLines = 0;
    _isGameOver = false;
    _preview = null;
    _previewPiece = null;
    _refillTray();
    notifyListeners();
  }

  void _refillTray() {
    for (int i = 0; i < kTraySize; i++) {
      _tray[i] = _pieceFactory?.call() ?? randomPiece(_random);
    }
  }

  /// 드래그 중 착지 지점 미리보기를 갱신한다.
  void updatePreview(BlockPiece piece, int row, int col) {
    final valid = grid.canPlace(piece, row, col);
    final next = (row: row, col: col, valid: valid);
    if (_preview == next && identical(_previewPiece, piece)) return;
    _preview = next;
    _previewPiece = piece;
    notifyListeners();
  }

  void clearPreview() {
    if (_preview == null && _previewPiece == null) return;
    _preview = null;
    _previewPiece = null;
    notifyListeners();
  }

  /// 트레이 [trayIndex]의 조각을 (row, col)에 놓는다.
  ///
  /// 놓을 수 없는 위치면 아무 일도 하지 않고 false를 돌려준다.
  bool placePiece(int trayIndex, int row, int col) {
    if (_isGameOver) return false;
    final piece = _tray[trayIndex];
    if (piece == null || !grid.canPlace(piece, row, col)) return false;

    // 콤보는 줄을 지운 배치가 연속될 때만 이어진다.
    final nextCombo = _comboCount + 1;
    final result = grid.place(piece, row, col, comboCount: nextCombo);

    // 조각을 놓은 칸 수만큼 기본 점수를 주고, 줄을 지웠으면 제거 점수를 더한다.
    _score += piece.cellCount + result.score;
    _lastClearedLines = result.clearedLineCount;
    _comboCount = result.didClear ? nextCombo : 0;

    _tray[trayIndex] = null;
    if (_tray.every((p) => p == null)) _refillTray();

    _preview = null;
    _previewPiece = null;
    _updateGameOver();
    notifyListeners();
    return true;
  }

  /// 트레이에 남은 조각 중 하나도 놓을 수 없으면 게임 오버다.
  void _updateGameOver() {
    final remaining = _tray.whereType<BlockPiece>();
    if (remaining.any(grid.canPlaceAnywhere)) return;

    _isGameOver = true;
    if (_score > _highScore) {
      _highScore = _score;
      // 저장 실패가 게임 진행을 막아서는 안 되므로 결과를 기다리지 않는다.
      unawaited(_scoreStore.writeHighScore(kBlockBlastGameId, _score));
    }
  }
}
