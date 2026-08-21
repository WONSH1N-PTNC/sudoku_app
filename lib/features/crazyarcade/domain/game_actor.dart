/// 액터(플레이어 · 봇)의 생존 상태
enum ActorState {
  /// 정상 활동 중
  alive,

  /// 물풍선에 맞아 물방울에 갇힘. 제한시간 안에 같은 편이 닿으면 부활한다.
  bubbled,

  /// 탈락
  dead,
}

/// 액터 충돌 판정용 반지름 (타일 단위).
///
/// 0.5(타일 절반)에 도달하면 통로 한가운데 정확히 서 있어도 양옆 칸까지 판정에
/// 걸려 아예 지나갈 수 없다. 화면상 크기(kActorRenderRadius)보다 조금 작게 두어
/// 한 칸짜리 통로를 통과할 여유를 남긴다.
const double kActorRadius = 0.42;

/// 화면에 그릴 때의 반지름. 캐릭터가 바닥 타일 한 칸을 채우도록 한다.
const double kActorRenderRadius = 0.48;

/// 기본 이동 속도 (초당 타일 수)
const double kBaseSpeed = 3.2;

/// 속도 아이템 하나당 증가량과 상한
const double kSpeedIncrement = 0.55;
const double kMaxSpeed = 6.0;

/// 위력 · 물풍선 개수 상한
const int kMaxPower = 8;
const int kMaxBalloons = 8;

/// 물방울에 갇혀 있는 시간 (초). 이 안에 구조되지 않으면 탈락한다.
const double kBubbleDuration = 6.0;

/// 플레이어 또는 봇 한 명.
///
/// 위치는 타일 단위의 실수 좌표이며 액터의 중심을 가리킨다.
class Actor {
  Actor({
    required this.id,
    required this.teamId,
    required this.x,
    required this.y,
  });

  final int id;

  /// 같은 팀이면 물방울을 터뜨려 구조하고, 다른 팀이면 즉시 탈락시킨다.
  final int teamId;

  double x;
  double y;

  double speed = kBaseSpeed;
  int power = 1;
  int maxBalloons = 1;

  ActorState state = ActorState.alive;

  /// 물방울에 갇힌 뒤 남은 시간
  double bubbleTimer = 0;

  bool get isAlive => state == ActorState.alive;
  bool get isBubbled => state == ActorState.bubbled;
  bool get isDead => state == ActorState.dead;

  /// 조작 가능한 상태인지 (갇혀 있으면 움직이지도 설치하지도 못한다)
  bool get canAct => state == ActorState.alive;

  /// 액터 중심이 올라가 있는 칸
  int get col => x.floor();
  int get row => y.floor();

  /// 물방울에 가둔다.
  void trapInBubble() {
    if (state != ActorState.alive) return;
    state = ActorState.bubbled;
    bubbleTimer = kBubbleDuration;
  }

  /// 같은 편이 구조했다.
  void rescue() {
    if (state != ActorState.bubbled) return;
    state = ActorState.alive;
    bubbleTimer = 0;
  }

  void eliminate() {
    state = ActorState.dead;
    bubbleTimer = 0;
  }
}
