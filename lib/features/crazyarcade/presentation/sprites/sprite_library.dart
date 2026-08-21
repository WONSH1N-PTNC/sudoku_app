import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sprite_sheet.dart';

/// 게임이 찾는 그림의 종류
enum GameSprite {
  ground,
  wall,
  box,
  balloon,
  explosion,
  character,
  itemPower,
  itemCount,
  itemSpeed,
}

/// 스프라이트 한 장의 배치 정보
class SpriteDefinition {
  const SpriteDefinition({
    required this.path,
    this.columns = 1,
    this.rows = 1,
    this.fps = 8,
  });

  final String path;

  /// 가로 프레임 수 (애니메이션)
  final int columns;

  /// 세로 줄 수 (캐릭터는 바라보는 방향)
  final int rows;

  final double fps;
}

/// 어떤 파일을 어떤 격자로 읽을지 적어 둔 목록.
///
/// 파일을 넣은 뒤 시트가 여러 프레임이면 여기서 columns · rows만 고치면 된다.
/// 자세한 설명은 assets/images/crazyarcade/README.md 참고.
const Map<GameSprite, SpriteDefinition> kSpriteManifest = {
  GameSprite.ground: SpriteDefinition(path: 'assets/images/crazyarcade/ground.png'),
  GameSprite.wall: SpriteDefinition(path: 'assets/images/crazyarcade/wall.png'),
  GameSprite.box: SpriteDefinition(path: 'assets/images/crazyarcade/box.png'),
  GameSprite.balloon:
      SpriteDefinition(path: 'assets/images/crazyarcade/balloon.png', fps: 6),
  GameSprite.explosion:
      SpriteDefinition(path: 'assets/images/crazyarcade/explosion.png', fps: 12),
  GameSprite.character:
      SpriteDefinition(path: 'assets/images/crazyarcade/character.png', fps: 8),
  GameSprite.itemPower:
      SpriteDefinition(path: 'assets/images/crazyarcade/item_power.png'),
  GameSprite.itemCount:
      SpriteDefinition(path: 'assets/images/crazyarcade/item_count.png'),
  GameSprite.itemSpeed:
      SpriteDefinition(path: 'assets/images/crazyarcade/item_speed.png'),
};

/// 불러온 스프라이트 모음.
///
/// 파일이 하나도 없어도 정상이다. 그 경우 게임은 코드로 그리는 기본 아트를 쓴다.
/// 일부만 넣는 것도 된다. 있는 것만 그림으로 바뀌고 나머지는 기본 아트로 남는다.
class SpriteLibrary {
  const SpriteLibrary(this._sheets);

  const SpriteLibrary.empty() : _sheets = const {};

  final Map<GameSprite, SpriteSheet> _sheets;

  /// 해당 그림이 준비되어 있으면 시트를, 없으면 null을 준다.
  SpriteSheet? operator [](GameSprite sprite) => _sheets[sprite];

  bool get isEmpty => _sheets.isEmpty;
  int get length => _sheets.length;

  /// 목록에 적힌 그림을 읽는다.
  ///
  /// 없는 파일은 조용히 건너뛴다. 에셋을 아직 넣지 않은 상태가 정상이기 때문에
  /// 이것을 오류로 다루면 게임이 아예 뜨지 않는다.
  static Future<SpriteLibrary> load({
    AssetBundle? bundle,
    Map<GameSprite, SpriteDefinition> manifest = kSpriteManifest,
  }) async {
    final source = bundle ?? rootBundle;
    final sheets = <GameSprite, SpriteSheet>{};
    final missing = <String>[];

    for (final entry in manifest.entries) {
      final definition = entry.value;
      try {
        final data = await source.load(definition.path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        sheets[entry.key] = SpriteSheet(
          image: frame.image,
          columns: definition.columns,
          rows: definition.rows,
          fps: definition.fps,
        );
      } catch (_) {
        // 파일이 없거나 읽을 수 없는 형식이면 그냥 기본 아트를 쓴다.
        missing.add(definition.path.split('/').last);
      }
    }

    if (missing.isNotEmpty) {
      // 아직 에셋을 넣지 않은 상태가 정상이므로 한 줄로만 알린다.
      debugPrint(
        '크레이지 아케이드: 그림 ${missing.length}개가 없어 기본 아트로 그립니다 '
        '(${missing.join(", ")})',
      );
    }

    return SpriteLibrary(sheets);
  }

  void dispose() {
    for (final sheet in _sheets.values) {
      sheet.dispose();
    }
  }
}
