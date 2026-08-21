import 'dart:math';

import 'package:flutter/material.dart';

import '../controller/crazy_arcade_controller.dart';
import '../domain/balloon.dart';
import '../domain/game_actor.dart';
import '../domain/game_world.dart';
import '../domain/item.dart';
import '../domain/tile_map.dart';

/// 게임 화면 전용 팔레트.
///
/// 앱 테마(ColorScheme)를 따르지 않고 고정 색을 쓴다. 놀이판은 주변 UI와
/// 달리 색이 일정해야 물풍선 · 불꽃 · 상자를 순간적으로 구분할 수 있다.
class GamePalette {
  const GamePalette._();

  static const groundLight = Color(0xFF7FC96B);
  static const groundDark = Color(0xFF74BE60);
  static const groundEdge = Color(0xFF63A852);

  static const wallTop = Color(0xFF9AA6B8);
  static const wallFace = Color(0xFF6B7789);
  static const wallShadow = Color(0xFF4C5666);

  static const boxTop = Color(0xFFE0A867);
  static const boxFace = Color(0xFFC98A4B);
  static const boxShadow = Color(0xFFA46E38);

  static const water = Color(0xFF49B8EC);
  static const waterDeep = Color(0xFF2C8FC4);
  static const foam = Color(0xFFCDEDFB);

  static const shadow = Color(0x33000000);
}

/// 팀별 캐릭터 색 (0번이 플레이어)
const List<Color> kTeamColors = [
  Color(0xFF4F6DF5),
  Color(0xFFE05C6E),
  Color(0xFFF2A93B),
  Color(0xFF8A6BE2),
];

/// 맵과 액터를 한 장의 캔버스에 그린다.
///
/// [repaint]에 프레임 신호를 연결하므로 위젯 트리는 리빌드되지 않고
/// 이 페인터만 다시 그려진다.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.controller,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// 월드를 직접 들고 있지 않고 컨트롤러를 통해 읽는다.
  ///
  /// 게임 화면은 프레임마다 리빌드되지 않으므로, 여기서 world를 붙들면
  /// 재시작으로 새 월드가 만들어져도 옛 월드를 계속 그리게 된다.
  final CrazyArcadeController controller;

  GameWorld get world => controller.world;

  /// 맵 전체가 들어가는 한 칸의 픽셀 크기
  static double cellSizeFor(Size size, TileMap map) {
    return (size.width / map.width).clamp(0.0, size.height / map.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final map = world.map;
    final cell = cellSizeFor(size, map);
    final originX = (size.width - cell * map.width) / 2;
    final originY = (size.height - cell * map.height) / 2;

    canvas.save();
    canvas.translate(originX, originY);

    _paintGround(canvas, cell);
    _paintItems(canvas, cell);
    _paintBlocks(canvas, cell);
    _paintBalloons(canvas, cell);
    _paintActors(canvas, cell);
    _paintExplosions(canvas, cell);

    canvas.restore();
  }

  Rect _cellRect(int col, int row, double cell, {double inset = 0}) {
    return Rect.fromLTWH(
      col * cell + inset,
      row * cell + inset,
      cell - inset * 2,
      cell - inset * 2,
    );
  }

  /// 바닥. 두 가지 초록을 번갈아 깔아 칸 경계가 자연스럽게 보이게 한다.
  void _paintGround(Canvas canvas, double cell) {
    final light = Paint()..color = GamePalette.groundLight;
    final dark = Paint()..color = GamePalette.groundDark;
    final edge = Paint()
      ..color = GamePalette.groundEdge.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.03;

    for (int row = 0; row < world.map.height; row++) {
      for (int col = 0; col < world.map.width; col++) {
        final rect = _cellRect(col, row, cell);
        canvas.drawRect(rect, (col + row).isEven ? light : dark);
        canvas.drawRect(rect, edge);
      }
    }
  }

  /// 벽과 상자. 윗면을 밝게, 아랫단을 어둡게 칠해 입체감을 준다.
  void _paintBlocks(Canvas canvas, double cell) {
    for (int row = 0; row < world.map.height; row++) {
      for (int col = 0; col < world.map.width; col++) {
        switch (world.map.tileAt(col, row)) {
          case TileType.wall:
            _paintBlock(canvas, col, row, cell,
                top: GamePalette.wallTop,
                face: GamePalette.wallFace,
                shadow: GamePalette.wallShadow,
                inset: 0.02);
          case TileType.box:
            _paintBlock(canvas, col, row, cell,
                top: GamePalette.boxTop,
                face: GamePalette.boxFace,
                shadow: GamePalette.boxShadow,
                inset: 0.08,
                planks: true);
          case TileType.empty:
            break;
        }
      }
    }
  }

  void _paintBlock(
    Canvas canvas,
    int col,
    int row,
    double cell, {
    required Color top,
    required Color face,
    required Color shadow,
    required double inset,
    bool planks = false,
  }) {
    final rect = _cellRect(col, row, cell, inset: cell * inset);
    final radius = Radius.circular(cell * 0.14);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 바닥에 드리우는 그림자
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, cell * 0.05), radius),
      Paint()..color = GamePalette.shadow,
    );
    canvas.drawRRect(rrect, Paint()..color = face);

    // 윗면 하이라이트
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.36),
        radius,
      ),
      Paint()..color = top,
    );
    // 아랫단 그늘
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        rect.bottom - rect.height * 0.16,
        rect.width,
        rect.height * 0.16,
      ),
      Paint()..color = shadow.withValues(alpha: 0.55),
    );

    if (planks) {
      // 나무 상자 느낌의 결
      final line = Paint()
        ..color = shadow.withValues(alpha: 0.45)
        ..strokeWidth = cell * 0.035;
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        line,
      );
    }
  }

  /// 바닥에 떨어진 아이템. 살짝 위아래로 떠 있어 눈에 띄게 한다.
  void _paintItems(Canvas canvas, double cell) {
    for (final item in world.items) {
      // 칸마다 위상을 어긋나게 해 여러 개가 한꺼번에 출렁이지 않게 한다.
      final phase = world.elapsed * 3 + (item.col + item.row) * 0.7;
      final bob = sin(phase) * cell * 0.05;
      final center =
          Offset((item.col + 0.5) * cell, (item.row + 0.5) * cell + bob);

      final color = switch (item.type) {
        ItemType.power => const Color(0xFFE0524A),
        ItemType.count => const Color(0xFF3F86E8),
        ItemType.speed => const Color(0xFF3FAE5A),
      };

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, (item.row + 0.78) * cell),
          width: cell * 0.42,
          height: cell * 0.14,
        ),
        Paint()..color = GamePalette.shadow,
      );

      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: cell * 0.56, height: cell * 0.56),
        Radius.circular(cell * 0.16),
      );
      canvas.drawRRect(badge, Paint()..color = color);
      canvas.drawRRect(
        badge,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05,
      );
      _paintItemGlyph(canvas, center, cell, item.type);
    }
  }

  /// 아이템 종류를 한눈에 구분할 수 있는 흰색 표식
  void _paintItemGlyph(Canvas canvas, Offset center, double cell, ItemType type) {
    final white = Paint()..color = Colors.white;
    final unit = cell * 0.11;

    switch (type) {
      case ItemType.power:
        // 폭발을 뜻하는 사방 화살표
        final path = Path();
        for (int i = 0; i < 4; i++) {
          final angle = i * pi / 2;
          path.moveTo(center.dx, center.dy);
          path.lineTo(
            center.dx + cos(angle) * unit * 1.6,
            center.dy + sin(angle) * unit * 1.6,
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..strokeWidth = cell * 0.07
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      case ItemType.count:
        // 물풍선 두 개
        canvas.drawCircle(center.translate(-unit * 0.7, 0), unit * 0.8, white);
        canvas.drawCircle(center.translate(unit * 0.7, 0), unit * 0.8, white);
      case ItemType.speed:
        // 앞으로 나아가는 삼각형
        final path = Path()
          ..moveTo(center.dx - unit, center.dy - unit * 1.2)
          ..lineTo(center.dx + unit * 1.3, center.dy)
          ..lineTo(center.dx - unit, center.dy + unit * 1.2)
          ..close();
        canvas.drawPath(path, white);
    }
  }

  /// 설치된 물풍선. 심지가 줄수록 부풀고 빠르게 출렁인다.
  void _paintBalloons(Canvas canvas, double cell) {
    for (final balloon in world.balloons) {
      final center =
          Offset((balloon.col + 0.5) * cell, (balloon.row + 0.5) * cell);
      final progress = 1 - (balloon.fuse / kBalloonFuse).clamp(0.0, 1.0);

      // 터질 때가 가까울수록 크고 빠르게 떤다.
      final wobble = sin(world.elapsed * (6 + 14 * progress)) * 0.05 * progress;
      final radius = cell * (0.34 + 0.06 * progress);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + radius * 0.85),
          width: radius * 1.7,
          height: radius * 0.5,
        ),
        Paint()..color = GamePalette.shadow,
      );

      // 물이 든 느낌을 주려고 세로로 살짝 눌린 타원으로 그린다.
      final body = Rect.fromCenter(
        center: center,
        width: radius * 2 * (1 + wobble),
        height: radius * 2 * (1 - wobble),
      );
      canvas.drawOval(body, Paint()..color = GamePalette.water);
      canvas.drawOval(
        body.deflate(radius * 0.28),
        Paint()..color = GamePalette.waterDeep.withValues(alpha: 0.35),
      );
      canvas.drawOval(
        body,
        Paint()
          ..color = GamePalette.foam
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05,
      );
      // 빛나는 점
      canvas.drawCircle(
        center.translate(-radius * 0.34, -radius * 0.36),
        radius * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  /// 터진 물이 퍼지는 모습. 남은 시간에 따라 부풀었다가 옅어진다.
  void _paintExplosions(Canvas canvas, double cell) {
    for (final explosion in world.explosions) {
      final t = (explosion.life / kExplosionLife).clamp(0.0, 1.0);
      // 터지는 순간 가장 크게 퍼지고 잦아든다.
      final spread = 1 - (t - 0.5).abs() * 2 * 0.35;
      final inset = cell * (0.30 - 0.24 * spread);

      final splash = Paint()
        ..color = GamePalette.water.withValues(alpha: 0.30 + 0.45 * t);
      final core = Paint()
        ..color = GamePalette.foam.withValues(alpha: 0.35 + 0.45 * t);

      for (final (col, row) in explosion.cells) {
        final rect = _cellRect(col, row, cell, inset: inset);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.28)),
          splash,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(cell * 0.12),
            Radius.circular(cell * 0.2),
          ),
          core,
        );
      }
    }
  }

  /// 캐릭터. 바라보는 방향으로 눈이 따라가고, 서 있을 때 살짝 들썩인다.
  void _paintActors(Canvas canvas, double cell) {
    for (final actor in world.actors) {
      if (actor.isDead) continue;

      final tileRadius = kActorRenderRadius * cell;
      // 액터마다 위상을 어긋나게 해 여럿이 동시에 같은 박자로 뛰지 않게 한다.
      final bob = sin(world.elapsed * 6 + actor.id * 1.3) * cell * 0.03;
      final center = Offset(actor.x * cell, actor.y * cell + bob);
      final color = kTeamColors[actor.teamId % kTeamColors.length];

      // 발밑 그림자는 들썩임과 무관하게 바닥에 붙어 있어야 한다.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(actor.x * cell, actor.y * cell + tileRadius * 0.82),
          width: tileRadius * 1.5,
          height: tileRadius * 0.45,
        ),
        Paint()..color = GamePalette.shadow,
      );

      final bodyRadius = actor.isBubbled ? tileRadius * 0.6 : tileRadius;
      _paintCharacter(canvas, center, bodyRadius, color, actor, cell);

      if (actor.isBubbled) {
        _paintBubble(canvas, Offset(actor.x * cell, actor.y * cell),
            tileRadius, actor, cell);
      }
    }
  }

  void _paintCharacter(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    Actor actor,
    double cell,
  ) {
    // 몸통은 아래가 살짝 눌린 물방울 모양이라 서 있는 느낌이 난다.
    final body = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2 * 0.94,
    );
    canvas.drawOval(body, Paint()..color = color);
    // 아랫배 그늘
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.42),
        width: radius * 1.5,
        height: radius * 0.8,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    // 배 무늬로 몸통 색과 대비를 준다.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.30),
        width: radius * 1.02,
        height: radius * 0.76,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    // 정수리 광택
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.28, -radius * 0.5),
        width: radius * 0.62,
        height: radius * 0.34,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    _paintFace(canvas, center, radius, actor);
  }

  /// 눈. 바라보는 방향으로 눈동자가 쏠린다.
  void _paintFace(Canvas canvas, Offset center, double radius, Actor actor) {
    final eyeGap = radius * 0.36;
    final eyeY = center.dy - radius * 0.18;
    final eyeRadius = radius * 0.23;
    final white = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF23303F);

    // 위를 볼 때는 뒤통수를 보이는 셈이라 눈을 살짝 위로만 올린다.
    final lookX = actor.facingX.clamp(-1.0, 1.0) * eyeRadius * 0.42;
    final lookY = actor.facingY.clamp(-1.0, 1.0) * eyeRadius * 0.32;

    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(center.dx + eyeGap * side, eyeY);
      canvas.drawCircle(eyeCenter, eyeRadius, white);
      canvas.drawCircle(
        eyeCenter.translate(lookX, lookY),
        eyeRadius * 0.55,
        pupil,
      );
    }
  }

  /// 갇힌 캐릭터를 감싸는 물방울과 남은 시간 표시
  void _paintBubble(
    Canvas canvas,
    Offset center,
    double radius,
    Actor actor,
    double cell,
  ) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = GamePalette.water.withValues(alpha: 0.32),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = GamePalette.foam.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05,
    );
    canvas.drawCircle(
      center.translate(-radius * 0.38, -radius * 0.4),
      radius * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    // 남은 시간을 테두리 호로 보여 준다.
    final remaining = (actor.bubbleTimer / kBubbleDuration).clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * remaining,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.08,
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    // 다시 그리기는 repaint Listenable이 프레임마다 알려 준다.
    return oldDelegate.controller != controller;
  }
}
