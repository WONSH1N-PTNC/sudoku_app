import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/games/game_entry.dart';
import 'core/widgets/main_layout.dart';
import 'features/lobby/presentation/lobby_screen.dart';

/// 앱 전역 라우팅 정의.
///
/// 게임 라우트는 [kGameRegistry]에서 자동 생성되므로, 게임을 추가할 때
/// 이 파일을 수정할 필요가 없다.
///
/// URL 전략에 관하여: GitHub Pages는 정적 호스팅이라 서버 리라이트가 없다.
/// 따라서 `usePathUrlStrategy()`를 호출하지 않고 Flutter 웹 기본값인 해시 전략
/// (`/sudoku_app/#/sudoku`)을 유지한다. 경로 전략으로 바꾸면 배포 후 딥링크
/// 새로고침 시 404가 발생한다.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      // 상단 네비게이션 바를 유지한 채 바디만 교체한다.
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LobbyScreen(),
        ),
        for (final game in kGameRegistry)
          GoRoute(
            path: game.path,
            builder: (context, state) => game.builder(),
          ),
      ],
    ),
  ],
  errorBuilder: (context, state) => _RouteNotFound(location: state.uri.toString()),
);

/// 등록되지 않은 경로로 진입했을 때 보여줄 화면
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied_rounded,
                size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('찾을 수 없는 페이지입니다: $location',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('로비로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}
