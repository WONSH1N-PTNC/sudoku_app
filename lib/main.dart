import 'package:flutter/material.dart';

import 'router.dart';

void main() {
  runApp(const GameHubApp());
}

/// 앱 진입점.
///
/// 전역 테마와 라우터 설정만 담당한다. 각 게임의 상태와 UI는
/// features/ 아래 각 게임 폴더에서 자체적으로 소유한다.
class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Game Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
