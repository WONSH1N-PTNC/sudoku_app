import 'player_intent.dart';

/// 한 액터의 입력을 만들어 내는 곳.
///
/// 키보드 · 모바일 가상 패드 · AI 봇이 모두 이 인터페이스를 구현한다.
/// 시뮬레이션은 구현체를 알지 못하므로, 입력 장치를 바꾸거나 늘려도
/// 게임 규칙 코드는 손대지 않는다.
abstract class InputSource {
  /// 이번 프레임의 입력을 읽는다.
  ///
  /// 물풍선 설치처럼 한 번만 발동해야 하는 동작은 여기서 true로 돌려준 뒤
  /// 스스로 상태를 내려 두어야 한다 (누르고 있어도 연발되지 않도록).
  PlayerIntent read();
}

/// 아무 입력도 내지 않는 소스. 아직 AI가 없는 액터의 자리를 채운다.
class IdleInputSource implements InputSource {
  const IdleInputSource();

  @override
  PlayerIntent read() => PlayerIntent.idle;
}
