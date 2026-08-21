import 'dart:math' as math;

/// 한 플레이어가 이번 프레임에 하려는 행동.
///
/// 키보드 · 모바일 가상 패드 · AI 봇이 모두 이 값을 만들어 내고,
/// 시뮬레이션은 그것이 어디서 왔는지 알지 못한다. 덕분에
/// - AI는 특별 취급 없이 그냥 또 하나의 입력 소스가 되고
/// - 로컬 2인 대전은 입력 소스를 하나 더 붙이는 것으로 끝나며
/// - 테스트에서는 각본대로 입력을 주입해 시뮬레이션을 결정론적으로 검증할 수 있다.
class PlayerIntent {
  const PlayerIntent({
    this.moveX = 0,
    this.moveY = 0,
    this.placeBalloon = false,
  });

  /// 아무것도 하지 않음
  static const PlayerIntent idle = PlayerIntent();

  /// 좌(-1) ~ 우(+1)
  final double moveX;

  /// 상(-1) ~ 하(+1)
  final double moveY;

  /// 이번 프레임에 물풍선을 설치하려는지
  final bool placeBalloon;

  bool get isMoving => moveX != 0 || moveY != 0;

  /// 대각 입력이 축 입력보다 빨라지지 않도록 길이를 1로 제한한다.
  PlayerIntent normalized() {
    final lengthSquared = moveX * moveX + moveY * moveY;
    if (lengthSquared <= 1.0) return this;
    final length = math.sqrt(lengthSquared);
    return PlayerIntent(
      moveX: moveX / length,
      moveY: moveY / length,
      placeBalloon: placeBalloon,
    );
  }

  @override
  String toString() =>
      'PlayerIntent(move: ($moveX, $moveY), placeBalloon: $placeBalloon)';
}
