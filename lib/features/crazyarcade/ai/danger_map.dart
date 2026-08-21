import '../domain/balloon.dart';
import '../domain/blast.dart';
import '../domain/game_world.dart';

/// 각 칸이 불꽃에 휩싸이기까지 남은 시간을 담은 지도.
///
/// 봇의 모든 판단이 여기서 나온다. 폭발 범위는 시뮬레이션과 같은 [blastCells]를
/// 쓰므로, 봇이 "안전하다"고 본 칸은 실제로도 안전하다.
class DangerMap {
  DangerMap._(this.width, this.height, this._timeToBlast);

  final int width;
  final int height;
  final List<double> _timeToBlast;

  /// (col, row)가 위험해지기까지 남은 시간(초). 안전하면 [double.infinity].
  /// 맵 밖은 갈 수 없으므로 위험으로 취급한다.
  double timeToBlast(int col, int row) {
    if (col < 0 || col >= width || row < 0 || row >= height) return 0;
    return _timeToBlast[row * width + col];
  }

  bool isSafe(int col, int row) => timeToBlast(col, row) == double.infinity;

  /// 현재 월드의 위험 지도를 만든다.
  ///
  /// [extraBalloon]을 넘기면 "여기에 놓으면 어떻게 되는가"를 실제로 놓아 보지 않고
  /// 미리 확인할 수 있다. 봇이 자폭을 피하는 핵심 수단이다.
  factory DangerMap.of(GameWorld world, {Balloon? extraBalloon}) {
    final map = world.map;
    final width = map.width;
    final height = map.height;
    final time = List.filled(width * height, double.infinity);

    final balloons = <Balloon>[...world.balloons, ?extraBalloon];

    bool hasBalloonAt(int col, int row) =>
        balloons.any((b) => b.col == col && b.row == row);

    Balloon? balloonAt(int col, int row) {
      for (final b in balloons) {
        if (b.col == col && b.row == row) return b;
      }
      return null;
    }

    // 연쇄를 반영한 실제 폭발 시각을 구한다.
    // 다른 물풍선의 불꽃에 닿으면 자기 심지와 무관하게 그때 함께 터진다.
    final detonateAt = {for (final b in balloons) b: b.fuse};
    for (int pass = 0; pass < balloons.length + 1; pass++) {
      var changed = false;
      for (final source in balloons) {
        blastCells(
          map,
          source.col,
          source.row,
          source.power,
          hasBalloon: hasBalloonAt,
          onBalloon: (col, row) {
            final other = balloonAt(col, row);
            if (other == null) return;
            if (detonateAt[source]! < detonateAt[other]!) {
              detonateAt[other] = detonateAt[source]!;
              changed = true;
            }
          },
        );
      }
      if (!changed) break;
    }

    for (final balloon in balloons) {
      final cells = blastCells(
        map,
        balloon.col,
        balloon.row,
        balloon.power,
        hasBalloon: hasBalloonAt,
      );
      final at = detonateAt[balloon]!;
      for (final (col, row) in cells) {
        final index = row * width + col;
        if (at < time[index]) time[index] = at;
      }
    }

    // 이미 타오르고 있는 불꽃은 지금 당장 위험하다.
    for (final explosion in world.explosions) {
      for (final (col, row) in explosion.cells) {
        time[row * width + col] = 0;
      }
    }

    return DangerMap._(width, height, time);
  }
}
