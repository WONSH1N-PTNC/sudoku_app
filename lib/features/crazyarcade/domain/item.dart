/// 상자를 부수면 나오는 아이템 종류
enum ItemType {
  /// 폭발 사거리 증가
  power,

  /// 동시에 놓을 수 있는 물풍선 개수 증가
  count,

  /// 이동 속도 증가
  speed,
}

/// 맵에 떨어져 있는 아이템
class Item {
  Item({required this.col, required this.row, required this.type});

  final int col;
  final int row;
  final ItemType type;
}
