import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/explore/word_list_screen.dart';
import '../../features/explore/explore_flashcard_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/kana/kana_screen.dart';

// 플레이스홀더 - 이후 화면 구현 시 교체
class PlaceholderScreen extends StatelessWidget {
  final String name;
  const PlaceholderScreen(this.name, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text(name)),
      );
}

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: navigationShell.goBranch,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: '탐색'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: '통계'),
          ],
        ),
      );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    // 바텀 네비게이션 없는 전체화면 라우트
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const PlaceholderScreen('quiz'),
    ),
    GoRoute(
      path: '/quiz/complete',
      builder: (context, state) => const PlaceholderScreen('quiz complete'),
    ),
    GoRoute(
      path: '/kana',
      builder: (context, state) => const KanaScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          ScaffoldWithNavBar(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/explore',
            builder: (context, state) => const WordListScreen(),
            routes: [
              GoRoute(
                path: 'flashcard',
                builder: (context, state) => const ExploreFlashcardScreen(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
        ]),
      ],
    ),
  ],
);
