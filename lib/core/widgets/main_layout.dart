import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../games/game_entry.dart';

/// 모든 화면을 감싸는 공용 셸.
///
/// 상단 네비게이션 바(로비 + 게임 탭)를 항상 유지하고, 하단 바디에 현재 라우트의
/// 화면을 배치한다. 탭 목록은 [kGameRegistry]에서 파생되므로 게임을 추가해도
/// 이 파일은 수정할 필요가 없다.
class MainLayout extends StatelessWidget {
  const MainLayout({super.key, required this.child});

  /// ShellRoute가 전달하는 현재 라우트의 화면
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: colorScheme.primaryContainer,
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            // 브랜드 (클릭 시 로비로 이동)
            InkWell(
              onTap: () => context.go('/'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.videogame_asset_rounded,
                        color: colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Game Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 게임 탭 (레지스트리에서 자동 생성, 좁은 화면에서는 가로 스크롤)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _NavTab(
                      icon: Icons.home_rounded,
                      label: '로비',
                      selected: location == '/',
                      onTap: () => context.go('/'),
                    ),
                    for (final game in kGameRegistry)
                      _NavTab(
                        icon: game.icon,
                        label: game.title,
                        selected: location == game.path,
                        onTap: () => context.go(game.path),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

/// 상단 네비게이션 바의 탭 하나.
///
/// 게임 대부분이 방향키를 사용하므로 [canRequestFocus]를 꺼서 포커스 트래버설에서
/// 제외한다. 그렇지 않으면 방향키 입력을 네비게이션 바가 가로챈다.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = selected
        ? colorScheme.onPrimary
        : colorScheme.onPrimaryContainer.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
