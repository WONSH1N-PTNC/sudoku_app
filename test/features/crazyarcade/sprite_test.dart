import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/sprites/sprite_library.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/sprites/sprite_sheet.dart';

/// 테스트용 단색 이미지를 만든다.
Future<ui.Image> makeImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF2FB89B),
  );
  return recorder.endRecording().toImage(width, height);
}

Future<ByteData> makePng(int width, int height) async {
  final image = await makeImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!;
}

/// 메모리에 담아 둔 에셋만 돌려주는 번들. 없는 키는 실제 번들처럼 예외를 던진다.
class _MemoryBundle extends CachingAssetBundle {
  _MemoryBundle(this._assets);

  final Map<String, ByteData> _assets;

  @override
  Future<ByteData> load(String key) async {
    final data = _assets[key];
    if (data == null) throw FlutterError('없는 에셋: $key');
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpriteSheet', () {
    late ui.Image image;

    setUp(() async => image = await makeImage(80, 40));
    tearDown(() => image.dispose());

    test('격자에 맞춰 잘라낼 영역을 계산한다', () {
      final sheet = SpriteSheet(image: image, columns: 4, rows: 2);

      expect(sheet.frameWidth, 20);
      expect(sheet.frameHeight, 20);
      expect(sheet.sourceRect(0, 0), const Rect.fromLTWH(0, 0, 20, 20));
      expect(sheet.sourceRect(2, 1), const Rect.fromLTWH(40, 20, 20, 20));
    });

    test('범위를 넘는 번호는 되돌아 감긴다', () {
      final sheet = SpriteSheet(image: image, columns: 4, rows: 2);
      expect(sheet.sourceRect(5, 3), sheet.sourceRect(1, 1));
    });

    test('한 칸짜리 시트는 항상 전체를 쓴다', () {
      final sheet = SpriteSheet(image: image);
      expect(sheet.sourceRect(3, 2), const Rect.fromLTWH(0, 0, 80, 40));
    });

    test('시간에 따라 프레임이 순환한다', () {
      final sheet = SpriteSheet(image: image, columns: 4, fps: 10);

      expect(sheet.frameAt(0), 0);
      expect(sheet.frameAt(0.15), 1);
      expect(sheet.frameAt(0.35), 3);
      expect(sheet.frameAt(0.45), 0, reason: '네 프레임을 돌면 처음으로 돌아온다');
    });

    test('프레임이 하나뿐이면 시간과 무관하게 0이다', () {
      final sheet = SpriteSheet(image: image);
      expect(sheet.frameAt(12.3), 0);
    });

    test('진행도를 프레임으로 바꾸고 범위를 넘지 않는다', () {
      final sheet = SpriteSheet(image: image, columns: 4);

      expect(sheet.frameForProgress(0), 0);
      expect(sheet.frameForProgress(0.5), 2);
      expect(sheet.frameForProgress(1.0), 3, reason: '마지막 프레임을 넘으면 안 된다');
      expect(sheet.frameForProgress(9.9), 3);
    });
  });

  group('바라보는 방향', () {
    test('이동 방향을 네 방향 중 하나로 정리한다', () {
      expect(facingOf(-1, 0), Facing.left);
      expect(facingOf(1, 0), Facing.right);
      expect(facingOf(0, -1), Facing.up);
      expect(facingOf(0, 1), Facing.down);
      expect(facingOf(-1, 0.3), Facing.left, reason: '큰 쪽 축을 따른다');
      expect(facingOf(0.2, -1), Facing.up);
    });

    test('기본 줄 순서는 아래 · 위 · 오른쪽 · 왼쪽이다', () {
      expect(directionRow(0, 1), 0);
      expect(directionRow(0, -1), 1);
      expect(directionRow(1, 0), 2);
      expect(directionRow(-1, 0), 3);
    });

    test('시트마다 줄 순서를 다르게 줄 수 있다', () {
      // 아래 · 왼쪽 · 오른쪽 · 위로 배치된 시트
      const order = [Facing.down, Facing.left, Facing.right, Facing.up];
      expect(directionRow(0, 1, order: order), 0);
      expect(directionRow(-1, 0, order: order), 1);
      expect(directionRow(1, 0, order: order), 2);
      expect(directionRow(0, -1, order: order), 3);
    });

    test('시트가 자기 줄 순서로 줄 번호를 고른다', () async {
      final image = await makeImage(32, 32);
      addTearDown(image.dispose);
      final sheet = SpriteSheet(
        image: image,
        rows: 4,
        directionOrder: const [Facing.up, Facing.down, Facing.left, Facing.right],
      );
      expect(sheet.rowFor(0, -1), 0);
      expect(sheet.rowFor(1, 0), 3);
    });
  });

  group('SpriteLibrary', () {
    test('에셋이 하나도 없으면 비어 있고 예외를 던지지 않는다', () async {
      // 아직 그림을 넣지 않은 상태가 정상이다. 여기서 실패하면 게임이 아예 뜨지 않는다.
      final library = await SpriteLibrary.load(bundle: _MemoryBundle({}));

      expect(library.isEmpty, isTrue);
      expect(library[GameSprite.character], isNull);
    });

    test('넣어 둔 것만 불러오고 나머지는 기본 아트로 남는다', () async {
      const manifest = {
        GameSprite.character: SpriteDefinition(
          path: 'a/character.png',
          columns: 4,
          rows: 4,
        ),
        GameSprite.wall: SpriteDefinition(path: 'a/wall.png'),
      };
      final bundle = _MemoryBundle({'a/character.png': await makePng(64, 64)});

      final library = await SpriteLibrary.load(bundle: bundle, manifest: manifest);
      addTearDown(library.dispose);

      expect(library.length, 1);
      expect(library[GameSprite.wall], isNull, reason: '없는 파일은 건너뛴다');

      final character = library[GameSprite.character];
      expect(character, isNotNull);
      expect(character!.columns, 4);
      expect(character.rows, 4);
      expect(character.frameWidth, 16);
    });

    test('빈 라이브러리는 const로 만들 수 있다', () {
      const library = SpriteLibrary.empty();
      expect(library.isEmpty, isTrue);
    });
  });

  group('실제 에셋', () {
    test('넣어 둔 파일이 목록에 적은 격자로 정확히 나뉜다', () async {
      // 시트를 넣었는데 columns/rows를 안 맞추면 프레임이 어긋나 잘린다.
      final library = await SpriteLibrary.load();
      addTearDown(library.dispose);

      for (final entry in kSpriteManifest.entries) {
        final sheet = library[entry.key];
        if (sheet == null) continue; // 아직 안 넣은 그림은 검사할 것이 없다

        final definition = entry.value;
        expect(sheet.image.width % definition.columns, 0,
            reason: '${definition.path}: 가로가 columns로 나누어떨어지지 않는다');
        expect(sheet.image.height % definition.rows, 0,
            reason: '${definition.path}: 세로가 rows로 나누어떨어지지 않는다');
      }
    });
  });
}
