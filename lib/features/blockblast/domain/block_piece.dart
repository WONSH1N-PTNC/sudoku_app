import 'dart:math';

/// 보드에 놓는 블록 조각 하나.
///
/// 셀 좌표는 조각 자체의 좌상단(0,0) 기준 상대 위치다.
/// Block Blast에는 회전이 없으므로 회전된 형태는 각각 별개의 모양으로 정의한다.
class BlockPiece {
  const BlockPiece({
    required this.cells,
    required this.width,
    required this.height,
    required this.colorIndex,
  });

  /// 조각을 구성하는 칸들의 (행, 열) 상대 좌표
  final List<(int, int)> cells;

  /// 조각의 가로/세로 칸 수 (미리보기 렌더링에 사용)
  final int width;
  final int height;

  /// 팔레트 색상 인덱스
  final int colorIndex;

  int get cellCount => cells.length;

  /// 문자열 패턴('X'는 채움, 그 외는 빈칸)으로부터 조각을 만든다.
  factory BlockPiece.fromPattern(List<String> pattern, int colorIndex) {
    final cells = <(int, int)>[];
    for (int r = 0; r < pattern.length; r++) {
      for (int c = 0; c < pattern[r].length; c++) {
        if (pattern[r][c] == 'X') cells.add((r, c));
      }
    }
    final width = pattern.map((row) => row.length).reduce(max);
    return BlockPiece(
      cells: cells,
      width: width,
      height: pattern.length,
      colorIndex: colorIndex,
    );
  }
}

/// 조각 모양 정의. Block Blast와 동일하게 회전 조작이 없으므로
/// 회전된 변형까지 개별 모양으로 모두 나열한다.
const List<List<String>> kBlockPatterns = [
  // 단일 · 직선
  ['X'],
  ['XX'],
  ['X', 'X'],
  ['XXX'],
  ['X', 'X', 'X'],
  ['XXXX'],
  ['X', 'X', 'X', 'X'],
  ['XXXXX'],
  ['X', 'X', 'X', 'X', 'X'],
  // 사각형
  ['XX', 'XX'],
  ['XXX', 'XXX', 'XXX'],
  ['XXX', 'XXX'],
  ['XX', 'XX', 'XX'],
  // 2x2 모서리 (3칸 L)
  ['XX', 'X.'],
  ['XX', '.X'],
  ['X.', 'XX'],
  ['.X', 'XX'],
  // 3x3 모서리 (5칸 L)
  ['X..', 'X..', 'XXX'],
  ['..X', '..X', 'XXX'],
  ['XXX', 'X..', 'X..'],
  ['XXX', '..X', '..X'],
  // T 자
  ['XXX', '.X.'],
  ['.X.', 'XXX'],
  ['X.', 'XX', 'X.'],
  ['.X', 'XX', '.X'],
  // S · Z 자
  ['.XX', 'XX.'],
  ['XX.', '.XX'],
  ['X.', 'XX', '.X'],
  ['.X', 'XX', 'X.'],
];

/// 팔레트 색상 개수 (실제 색상 값은 프레젠테이션 계층에서 테마로 결정)
const int kBlockColorCount = 6;

/// 무작위 조각 하나를 만든다.
BlockPiece randomPiece(Random random) {
  final pattern = kBlockPatterns[random.nextInt(kBlockPatterns.length)];
  return BlockPiece.fromPattern(pattern, random.nextInt(kBlockColorCount));
}
