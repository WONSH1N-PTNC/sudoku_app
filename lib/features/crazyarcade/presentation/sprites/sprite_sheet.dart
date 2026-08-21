import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// 여러 프레임이 격자로 붙어 있는 이미지 한 장.
///
/// 가로 칸(column)은 애니메이션 프레임, 세로 줄(row)은 방향처럼 종류가 다른
/// 변형을 뜻한다. 한 칸짜리 단일 이미지도 columns = rows = 1인 시트로 다룬다.
class SpriteSheet {
  SpriteSheet({
    required this.image,
    this.columns = 1,
    this.rows = 1,
    this.fps = 8,
  })  : assert(columns > 0),
        assert(rows > 0);

  final ui.Image image;
  final int columns;
  final int rows;

  /// 초당 프레임 수. columns가 1이면 의미가 없다.
  final double fps;

  double get frameWidth => image.width / columns;
  double get frameHeight => image.height / rows;

  /// 경과 시간에 해당하는 애니메이션 프레임 번호
  int frameAt(double elapsedSeconds) {
    if (columns <= 1) return 0;
    final frame = (elapsedSeconds * fps).floor();
    return frame % columns;
  }

  /// 진행도(0~1)를 프레임 번호로 바꾼다. 심지처럼 길이가 정해진 연출에 쓴다.
  int frameForProgress(double progress) {
    if (columns <= 1) return 0;
    final index = (progress.clamp(0.0, 1.0) * columns).floor();
    return index >= columns ? columns - 1 : index;
  }

  /// 시트에서 잘라낼 영역
  Rect sourceRect(int column, int row) {
    final c = columns == 1 ? 0 : column % columns;
    final r = rows == 1 ? 0 : row % rows;
    return Rect.fromLTWH(
      c * frameWidth,
      r * frameHeight,
      frameWidth,
      frameHeight,
    );
  }

  /// [dst] 영역에 한 프레임을 그린다.
  void draw(
    Canvas canvas,
    Rect dst, {
    int column = 0,
    int row = 0,
    Paint? paint,
  }) {
    canvas.drawImageRect(
      image,
      sourceRect(column, row),
      dst,
      paint ?? (Paint()..filterQuality = FilterQuality.medium),
    );
  }

  void dispose() => image.dispose();
}

/// 캐릭터 시트에서 바라보는 방향에 해당하는 줄 번호.
///
/// 아래(0) · 왼쪽(1) · 오른쪽(2) · 위(3) 순서는 스프라이트 시트에서 널리 쓰이는
/// 배치다. 줄이 하나뿐인 시트라면 [SpriteSheet.sourceRect]가 알아서 0으로 접는다.
int directionRow(double facingX, double facingY) {
  if (facingX.abs() > facingY.abs()) {
    return facingX < 0 ? 1 : 2;
  }
  return facingY < 0 ? 3 : 0;
}
