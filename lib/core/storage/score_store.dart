import 'package:shared_preferences/shared_preferences.dart';

/// 게임별 최고 점수 저장소.
///
/// 컨트롤러가 이 인터페이스에만 의존하므로, 테스트에서는 [MemoryScoreStore]를
/// 주입해 플러그인 없이 검증할 수 있다. 웹에서는 브라우저 localStorage에 저장된다.
abstract class ScoreStore {
  Future<int> readHighScore(String gameId);
  Future<void> writeHighScore(String gameId, int score);
}

/// shared_preferences 기반 구현 (웹에서는 localStorage)
class PrefsScoreStore implements ScoreStore {
  const PrefsScoreStore();

  String _key(String gameId) => 'highscore.$gameId';

  @override
  Future<int> readHighScore(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(gameId)) ?? 0;
  }

  @override
  Future<void> writeHighScore(String gameId, int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(gameId), score);
  }
}

/// 테스트용 인메모리 구현
class MemoryScoreStore implements ScoreStore {
  MemoryScoreStore([Map<String, int>? seed]) : _scores = {...?seed};

  final Map<String, int> _scores;

  @override
  Future<int> readHighScore(String gameId) async => _scores[gameId] ?? 0;

  @override
  Future<void> writeHighScore(String gameId, int score) async {
    _scores[gameId] = score;
  }
}
