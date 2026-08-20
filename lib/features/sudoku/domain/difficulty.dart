import 'sudoku_rules.dart';

/// 난이도 정보 및 채워진 숫자(힌트) 개수 정의
class DifficultyInfo {
  final int level;
  final String title;
  final int filledCells; // 9x9 (총 81칸) 중 미리 채워지는 숫자 개수

  const DifficultyInfo({
    required this.level,
    required this.title,
    required this.filledCells,
  });

  int get emptyCells => kTotalCells - filledCells;
}

/// 레벨 1 ~ 레벨 10 난이도 정의
const List<DifficultyInfo> kDifficultyLevels = [
  DifficultyInfo(level: 1, title: '매우 쉬움', filledCells: 62),
  DifficultyInfo(level: 2, title: '쉬움', filledCells: 57),
  DifficultyInfo(level: 3, title: '초급', filledCells: 52),
  DifficultyInfo(level: 4, title: '중급 1', filledCells: 47),
  DifficultyInfo(level: 5, title: '중급 2', filledCells: 42),
  DifficultyInfo(level: 6, title: '중고급', filledCells: 38),
  DifficultyInfo(level: 7, title: '고급 1', filledCells: 34),
  DifficultyInfo(level: 8, title: '고급 2', filledCells: 30),
  DifficultyInfo(level: 9, title: '전문가', filledCells: 26),
  DifficultyInfo(level: 10, title: '마스터', filledCells: 22),
];

/// 레벨 값으로 난이도 정보를 조회한다.
/// 목록에 없는 값이 들어와도 예외를 던지지 않고 레벨 1로 안전하게 대체한다.
DifficultyInfo difficultyForLevel(int level) {
  return kDifficultyLevels.firstWhere(
    (d) => d.level == level,
    orElse: () => kDifficultyLevels[0],
  );
}
