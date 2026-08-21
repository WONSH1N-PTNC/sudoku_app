import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/player_input.dart';

KeyDownEvent down(LogicalKeyboardKey key) =>
    KeyDownEvent(logicalKey: key, physicalKey: PhysicalKeyboardKey.keyA, timeStamp: Duration.zero);

KeyUpEvent up(LogicalKeyboardKey key) =>
    KeyUpEvent(logicalKey: key, physicalKey: PhysicalKeyboardKey.keyA, timeStamp: Duration.zero);

KeyRepeatEvent repeat(LogicalKeyboardKey key) =>
    KeyRepeatEvent(logicalKey: key, physicalKey: PhysicalKeyboardKey.keyA, timeStamp: Duration.zero);

void main() {
  group('키보드', () {
    test('방향키를 누르고 있는 동안 계속 이동 입력이 나온다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.arrowRight));

      expect(input.read().moveX, 1);
      expect(input.read().moveX, 1, reason: '떼기 전까지 유지되어야 한다');

      input.handleKeyEvent(up(LogicalKeyboardKey.arrowRight));
      expect(input.read().moveX, 0);
    });

    test('WASD도 방향키와 같게 동작한다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.keyW));
      expect(input.read().moveY, -1);

      input.handleKeyEvent(up(LogicalKeyboardKey.keyW));
      input.handleKeyEvent(down(LogicalKeyboardKey.keyS));
      expect(input.read().moveY, 1);
    });

    test('반대 방향을 같이 누르면 상쇄된다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.arrowLeft));
      input.handleKeyEvent(down(LogicalKeyboardKey.arrowRight));
      expect(input.read().moveX, 0);
    });

    test('설치는 한 번만 발동하고 키를 눌러도 연발되지 않는다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.space));

      expect(input.read().placeBalloon, isTrue);
      expect(input.read().placeBalloon, isFalse, reason: '읽는 즉시 내려가야 한다');

      // 키를 누르고 있는 동안 오는 반복 이벤트로는 다시 발동하지 않는다.
      input.handleKeyEvent(repeat(LogicalKeyboardKey.space));
      expect(input.read().placeBalloon, isFalse);

      // 뗐다가 다시 누르면 발동한다.
      input.handleKeyEvent(up(LogicalKeyboardKey.space));
      input.handleKeyEvent(down(LogicalKeyboardKey.space));
      expect(input.read().placeBalloon, isTrue);
    });

    test('게임과 무관한 키는 처리하지 않는다', () {
      final input = PlayerInputSource();
      expect(input.handleKeyEvent(down(LogicalKeyboardKey.keyQ)), isFalse);
    });

    test('포커스를 잃으면 눌린 키가 풀린다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.arrowRight));
      expect(input.read().moveX, 1);

      input.clearHeldInput();
      expect(input.read().moveX, 0, reason: '키가 눌린 채로 남으면 캐릭터가 계속 움직인다');
    });
  });

  group('가상 조이스틱', () {
    test('조이스틱 값이 이동 입력이 된다', () {
      final input = PlayerInputSource();
      input.setStick(0.5, -0.5);

      final intent = input.read();
      expect(intent.moveX, 0.5);
      expect(intent.moveY, -0.5);
    });

    test('조이스틱을 잡고 있으면 키보드보다 우선한다', () {
      final input = PlayerInputSource();
      input.handleKeyEvent(down(LogicalKeyboardKey.arrowLeft));
      input.setStick(1, 0);

      expect(input.read().moveX, 1, reason: '조이스틱 방향이 이겨야 한다');

      // 손을 떼면 다시 키보드가 살아난다.
      input.setStick(0, 0);
      expect(input.read().moveX, -1);
    });

    test('버튼으로도 물풍선을 설치할 수 있다', () {
      final input = PlayerInputSource();
      input.requestPlace();

      expect(input.read().placeBalloon, isTrue);
      expect(input.read().placeBalloon, isFalse);
    });
  });
}
