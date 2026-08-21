/// 물풍선이 터지기까지의 시간 (초)
const double kBalloonFuse = 2.4;

/// 폭발 이펙트가 남아 있는 시간 (초). 이 동안 닿는 액터는 물방울에 갇힌다.
const double kExplosionLife = 0.55;

/// 설치된 물풍선
class Balloon {
  Balloon({
    required this.col,
    required this.row,
    required this.ownerId,
    required this.power,
  });

  final int col;
  final int row;
  final int ownerId;

  /// 폭발이 뻗어 나가는 칸 수
  final int power;

  /// 남은 심지 시간
  double fuse = kBalloonFuse;

  /// 설치 직후 물풍선 위에 겹쳐 있는 액터들.
  ///
  /// 이들은 물풍선을 통과할 수 있고, 완전히 벗어나는 순간 목록에서 빠져
  /// 그 뒤로는 다시 올라탈 수 없다. 원작과 같은 동작이다.
  final Set<int> passableActorIds = {};

  /// 연쇄 폭발 등으로 즉시 터뜨린다.
  void detonateNow() => fuse = 0;
}

/// 터진 물풍선이 만들어 낸 불꽃
class Explosion {
  Explosion({required this.cells, required this.ownerId});

  /// 불꽃이 덮은 칸 목록 (중심 포함)
  final List<(int, int)> cells;

  final int ownerId;

  /// 남은 지속 시간
  double life = kExplosionLife;

  bool covers(int col, int row) =>
      cells.any((cell) => cell.$1 == col && cell.$2 == row);
}
