import 'package:flutter/services.dart';

import '../domain/input_source.dart';
import '../domain/player_intent.dart';

/// 플레이어의 입력을 모으는 소스.
///
/// 키보드와 모바일 가상 패드를 하나로 합친다. 둘 다 항상 살아 있어서
/// 터치 기기에 키보드를 붙여도, 데스크톱에서 창을 좁혀 패드가 떠도 그대로 동작한다.
/// 조이스틱을 잡고 있는 동안에는 조이스틱이 우선한다.
class PlayerInputSource implements InputSource {
  // LogicalKeyboardKey는 커스텀 ==/hashCode를 가져 const 컬렉션에 넣을 수 없다.
  static final Set<LogicalKeyboardKey> _leftKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyA,
  };
  static final Set<LogicalKeyboardKey> _rightKeys = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final Set<LogicalKeyboardKey> _upKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };
  static final Set<LogicalKeyboardKey> _downKeys = {
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyS,
  };
  static final Set<LogicalKeyboardKey> _placeKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  final Set<LogicalKeyboardKey> _pressed = {};

  /// 조이스틱 방향 (-1..1). 손을 떼면 (0, 0).
  double _stickX = 0;
  double _stickY = 0;

  /// 설치 요청. 눌린 순간 한 번만 켜지고 읽는 즉시 꺼진다.
  bool _placeRequested = false;

  /// 키 이벤트를 반영한다. 게임이 처리한 키면 true.
  bool handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      if (_placeKeys.contains(key)) {
        _placeRequested = true;
        return true;
      }
      if (_isMoveKey(key)) {
        _pressed.add(key);
        return true;
      }
      return false;
    }

    if (event is KeyUpEvent) {
      if (_placeKeys.contains(key)) return true;
      return _pressed.remove(key);
    }

    // KeyRepeatEvent: 이동은 이미 눌린 상태로 처리되고,
    // 설치는 키를 누르고 있어도 연발되면 안 되므로 무시한다.
    return _isMoveKey(key) || _placeKeys.contains(key);
  }

  bool _isMoveKey(LogicalKeyboardKey key) =>
      _leftKeys.contains(key) ||
      _rightKeys.contains(key) ||
      _upKeys.contains(key) ||
      _downKeys.contains(key);

  /// 가상 조이스틱이 매 이동마다 호출한다. 손을 떼면 (0, 0)을 넣는다.
  void setStick(double x, double y) {
    _stickX = x;
    _stickY = y;
  }

  /// 가상 패드의 물풍선 버튼이 호출한다.
  void requestPlace() => _placeRequested = true;

  /// 포커스를 잃으면 키가 눌린 채로 남을 수 있으므로 비운다.
  void clearHeldInput() {
    _pressed.clear();
    _stickX = 0;
    _stickY = 0;
  }

  @override
  PlayerIntent read() {
    final place = _placeRequested;
    _placeRequested = false;

    // 조이스틱을 잡고 있으면 그쪽을 쓴다.
    if (_stickX != 0 || _stickY != 0) {
      return PlayerIntent(moveX: _stickX, moveY: _stickY, placeBalloon: place);
    }

    double x = 0;
    double y = 0;
    if (_pressed.any(_leftKeys.contains)) x -= 1;
    if (_pressed.any(_rightKeys.contains)) x += 1;
    if (_pressed.any(_upKeys.contains)) y -= 1;
    if (_pressed.any(_downKeys.contains)) y += 1;
    return PlayerIntent(moveX: x, moveY: y, placeBalloon: place);
  }
}
