import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/player_input.dart';
import 'package:sudoku_app/features/crazyarcade/presentation/virtual_pad.dart';

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

  group('조이스틱 응답 곡선', () {
    double magnitudeOf((double, double) v) =>
        (v.$1 * v.$1 + v.$2 * v.$2) == 0 ? 0 : (v.$1.abs() > v.$2.abs() ? v.$1.abs() : v.$2.abs());

    test('데드존 안에서는 움직이지 않는다', () {
      expect(joystickThrottle(0.05, 0), (0.0, 0.0));
      expect(joystickThrottle(0, -0.1), (0.0, 0.0));
    });

    test('절반쯤 기울이면 이미 최고 속도가 나온다', () {
      final (x, y) = joystickThrottle(kJoystickFullThrottle, 0);
      expect(x, closeTo(1.0, 1e-9));
      expect(y, 0);
    });

    test('끝까지 밀어도 크기가 1을 넘지 않는다', () {
      final (x, y) = joystickThrottle(1, 1);
      expect(magnitudeOf((x, y)), lessThanOrEqualTo(1.0));
    });

    test('방향은 유지된 채 크기만 조절된다', () {
      final (x, y) = joystickThrottle(0.3, -0.3);
      expect(x, closeTo(-y, 1e-9), reason: '대각 방향이 유지되어야 한다');
    });

    test('선형 비례보다 빠르게 반응한다', () {
      // 예전에는 기울인 만큼 그대로 속도가 됐다. 같은 기울기에서 더 빨라야 한다.
      const tilt = 0.35;
      final (x, _) = joystickThrottle(tilt, 0);
      expect(x, greaterThan(tilt));
    });
  });
}
