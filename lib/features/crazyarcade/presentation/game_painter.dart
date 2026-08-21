import 'package:flutter/material.dart';

import '../controller/crazy_arcade_controller.dart';
import '../domain/balloon.dart';
import '../domain/game_actor.dart';
import '../domain/game_world.dart';
import '../domain/item.dart';
import '../domain/tile_map.dart';

/// 팀별 캐릭터 색 (0번이 플레이어)
const List<Color> kTeamColors = [
  Color(0xFF4F6DF5),
  Color(0xFFE05C6E),
  Color(0xFFF2A93B),
  Color(0xFF54B04A),
];

/// 맵과 액터를 한 장의 캔버스에 그린다.
///
/// [repaint]에 프레임 신호를 연결하므로 위젯 트리는 리빌드되지 않고
/// 이 페인터만 다시 그려진다.
class GamePainter extends CustomPainter {
  GamePainter({
    required this.controller,
    required this.colorScheme,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// 월드를 직접 들고 있지 않고 컨트롤러를 통해 읽는다.
  ///
  /// 게임 화면은 프레임마다 리빌드되지 않으므로, 여기서 world를 붙들면
  /// 재시작으로 새 월드가 만들어져도 옛 월드를 계속 그리게 된다.
  final CrazyArcadeController controller;

  final ColorScheme colorScheme;

  GameWorld get world => controller.world;

  /// 맵 전체가 들어가는 한 칸의 픽셀 크기
  static double cellSizeFor(Size size, TileMap map) {
    return (size.width / map.width).clamp(0.0, size.height / map.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final map = world.map;
    final cell = cellSizeFor(size, map);
    // 맵을 캔버스 가운데에 놓는다.
    final originX = (size.width - cell * map.width) / 2;
    final originY = (size.height - cell * map.height) / 2;

    canvas.save();
    canvas.translate(originX, originY);

    _paintTiles(canvas, cell);
    _paintItems(canvas, cell);
    _paintBalloons(canvas, cell);
    _paintExplosions(canvas, cell);
    _paintActors(canvas, cell);

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

  void _paintTiles(Canvas canvas, double cell) {
    final ground = Paint()..color = colorScheme.surfaceContainerLow;
    final wall = Paint()..color = colorScheme.onSurfaceVariant;
    final box = Paint()..color = colorScheme.tertiaryContainer;
    final boxEdge = Paint()
      ..color = colorScheme.onTertiaryContainer.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.06;

    for (int row = 0; row < world.map.height; row++) {
      for (int col = 0; col < world.map.width; col++) {
        final rect = _cellRect(col, row, cell);
        canvas.drawRect(rect, ground);

        switch (world.map.tileAt(col, row)) {
          case TileType.wall:
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                _cellRect(col, row, cell, inset: cell * 0.04),
                Radius.circular(cell * 0.16),
              ),
              wall,
            );
          case TileType.box:
            final r = RRect.fromRectAndRadius(
              _cellRect(col, row, cell, inset: cell * 0.1),
              Radius.circular(cell * 0.18),
            );
            canvas.drawRRect(r, box);
            canvas.drawRRect(r, boxEdge);
          case TileType.empty:
            break;
        }
      }
    }
  }

  void _paintItems(Canvas canvas, double cell) {
    for (final item in world.items) {
      final center = Offset((item.col + 0.5) * cell, (item.row + 0.5) * cell);
      final color = switch (item.type) {
        ItemType.power => const Color(0xFFE05C6E),
        ItemType.count => const Color(0xFF4F6DF5),
        ItemType.speed => const Color(0xFF54B04A),
      };
      canvas.drawCircle(center, cell * 0.26, Paint()..color = color);
      canvas.drawCircle(
        center,
        cell * 0.26,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06,
      );
      // 종류를 구분하는 최소한의 표식
      final markSize = cell * 0.1;
      final mark = Paint()..color = Colors.white;
      switch (item.type) {
        case ItemType.power:
          canvas.drawCircle(center, markSize, mark);
        case ItemType.count:
          canvas.drawRect(Rect.fromCenter(
              center: center, width: markSize * 2, height: markSize * 2), mark);
        case ItemType.speed:
          final path = Path()
            ..moveTo(center.dx - markSize, center.dy + markSize)
            ..lineTo(center.dx + markSize, center.dy)
            ..lineTo(center.dx - markSize, center.dy - markSize)
            ..close();
          canvas.drawPath(path, mark);
      }
    }
  }

  void _paintBalloons(Canvas canvas, double cell) {
    for (final balloon in world.balloons) {
      final center =
          Offset((balloon.col + 0.5) * cell, (balloon.row + 0.5) * cell);
      // 심지가 줄수록 조금씩 부풀어 터질 때가 임박했음을 알린다.
      final progress = 1 - (balloon.fuse / kBalloonFuse).clamp(0.0, 1.0);
      final radius = cell * (0.30 + 0.06 * progress);

      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF4AA8E0).withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05,
      );
      // 물방울 느낌의 하이라이트
      canvas.drawCircle(
        center.translate(-radius * 0.32, -radius * 0.34),
        radius * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  void _paintExplosions(Canvas canvas, double cell) {
    for (final explosion in world.explosions) {
      // 남은 시간에 따라 옅어지며 사라진다.
      final t = (explosion.life / kExplosionLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = const Color(0xFF6FD3F7).withValues(alpha: 0.35 + 0.5 * t);
      final inset = cell * (0.06 + 0.14 * (1 - t));

      for (final (col, row) in explosion.cells) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            _cellRect(col, row, cell, inset: inset),
            Radius.circular(cell * 0.22),
          ),
          paint,
        );
      }
    }
  }

  void _paintActors(Canvas canvas, double cell) {
    for (final actor in world.actors) {
      if (actor.isDead) continue;

      final center = Offset(actor.x * cell, actor.y * cell);
      // 충돌 판정보다 조금 크게 그려 캐릭터가 타일 한 칸을 채우도록 한다.
      final tileRadius = kActorRenderRadius * cell;
      // 갇혀 있으면 물방울이 타일을 채우고 캐릭터는 그 안으로 들어간다.
      final radius = actor.isBubbled ? tileRadius * 0.62 : tileRadius;
      final color = kTeamColors[actor.teamId % kTeamColors.length];

      if (actor.isBubbled) {
        canvas.drawCircle(
          center,
          tileRadius,
          Paint()..color = const Color(0xFF6FD3F7).withValues(alpha: 0.30),
        );
      }

      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05,
      );
      // 눈 두 개로 캐릭터임을 알아보게 한다.
      final eyeOffset = radius * 0.34;
      final eyePaint = Paint()..color = Colors.white;
      canvas.drawCircle(center.translate(-eyeOffset, -radius * 0.12),
          radius * 0.19, eyePaint);
      canvas.drawCircle(center.translate(eyeOffset, -radius * 0.12),
          radius * 0.19, eyePaint);

      if (actor.isBubbled) {
        // 남은 시간을 물방울 테두리의 호로 보여 준다.
        final remaining = (actor.bubbleTimer / kBubbleDuration).clamp(0.0, 1.0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: tileRadius),
          -1.5708,
          6.2832 * remaining,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.07,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    // 다시 그리기는 repaint Listenable이 프레임마다 알려 준다.
    return oldDelegate.controller != controller ||
        oldDelegate.colorScheme != colorScheme;
  }
}
