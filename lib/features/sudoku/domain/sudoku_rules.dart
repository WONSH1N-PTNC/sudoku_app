/// 스도쿠 보드의 크기 규칙과 규칙 검사 로직.
///
/// 보드 크기 관련 매직 넘버를 이 파일 한 곳에서만 정의하고,
/// 생성기(도메인)와 화면(프레젠테이션)이 동일한 규칙 함수를 공유한다.
library;

/// 보드 크기 관련 공용 상수 (9x9 보드, 3x3 박스)
const int kBoardSize = 9;
const int kBoxSize = 3;
const int kTotalCells = kBoardSize * kBoardSize;

/// 9x9 보드를 깊은 복사한다 (내부 리스트까지 새로 생성).
List<List<int>> copyBoard(List<List<int>> source) {
  return List.generate(kBoardSize, (r) => List.from(source[r]));
}

/// (row, col) 칸에 값(value)을 두었을 때 같은 행/열/3x3 박스에서 충돌이 있는지 검사한다.
/// [ignoreSelf]가 true이면 (row, col) 자기 자신은 비교 대상에서 제외한다.
/// 스도쿠 생성기의 배치 검증과 화면의 규칙 충돌 검사가 이 함수 하나를 공유한다.
bool hasConflictAt(
  List<List<int>> grid,
  int row,
  int col,
  int value, {
  bool ignoreSelf = false,
}) {
  if (value == 0) return false;

  for (int i = 0; i < kBoardSize; i++) {
    if (!(ignoreSelf && i == col) && grid[row][i] == value) return true;
    if (!(ignoreSelf && i == row) && grid[i][col] == value) return true;
  }

  int boxRow = (row ~/ kBoxSize) * kBoxSize;
  int boxCol = (col ~/ kBoxSize) * kBoxSize;
  for (int r = 0; r < kBoxSize; r++) {
    for (int c = 0; c < kBoxSize; c++) {
      int currR = boxRow + r;
      int currC = boxCol + c;
      if (!(ignoreSelf && currR == row && currC == col) &&
          grid[currR][currC] == value) {
        return true;
      }
    }
  }
  return false;
}
