import 'package:flutter/material.dart';

import '../../features/blockblast/presentation/block_blast_screen.dart';
import '../../features/crazyarcade/presentation/crazy_arcade_screen.dart';
import '../../features/sudoku/presentation/sudoku_screen.dart';

/// 허브에 등록된 게임 한 개의 메타데이터.
///
/// 라우터(router.dart), 상단 네비게이션 바(main_layout.dart), 로비 화면이
/// 모두 이 정보 하나에서 파생된다. 게임을 추가할 때 여러 파일을 각각
/// 고치다 누락되는 불일치를 막기 위한 단일 소스다.
class GameEntry {
  /// URL 경로 세그먼트이자 고유 식별자. 예) 'sudoku' -> '/sudoku'
  final String id;

  /// 네비게이션 바 라벨 및 로비 카드 제목
  final String title;

  /// 로비 카드와 네비게이션 바에 함께 쓰이는 아이콘
  final IconData icon;

  /// 로비 카드에 표시할 한 줄 설명
  final String description;

  /// 게임 화면 생성자
  final Widget Function() builder;

  const GameEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
    required this.builder,
  });

  /// go_router에서 사용할 절대 경로
  String get path => '/$id';
}

/// 허브에 등록된 전체 게임 목록.
///
/// 새 게임을 추가하려면 features/ 아래에 폴더를 만들고 이 목록에 한 줄만 추가하면
/// 라우트 · 네비게이션 바 탭 · 로비 카드가 모두 자동으로 생성된다.
const List<GameEntry> kGameRegistry = <GameEntry>[
  GameEntry(
    id: 'sudoku',
    title: '스도쿠',
    icon: Icons.grid_on_rounded,
    description: '9×9 보드를 숫자로 채우는 논리 퍼즐',
    builder: SudokuScreen.new,
  ),
  GameEntry(
    id: 'blockblast',
    title: '블록 블라스트',
    icon: Icons.grid_view_rounded,
    description: '8×8 보드에 조각을 놓아 행과 열을 지우는 퍼즐',
    builder: BlockBlastScreen.new,
  ),
  GameEntry(
    id: 'crazyarcade',
    title: '크레이지 아케이드',
    icon: Icons.bubble_chart_rounded,
    description: '물풍선을 놓아 상대를 가두는 실시간 액션',
    builder: CrazyArcadeScreen.new,
  ),
  // 향후 추가 예정: 클래식 테트리스(낙하·회전), 슈팅
];
