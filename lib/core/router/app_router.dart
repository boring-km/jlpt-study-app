import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/explore/word_list_screen.dart';
import '../../features/explore/explore_flashcard_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/kana/kana_screen.dart';
import '../../features/quiz/quiz_complete_screen.dart';
import '../../features/quiz/quiz_mode.dart';
import '../../features/quiz/quiz_screen.dart';

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
      builder: (context, state) => QuizScreen(mode: state.extra as QuizMode? ?? QuizMode.study),
    ),
    GoRoute(
      path: '/quiz/complete',
      builder: (context, state) =>
          QuizCompleteScreen(mode: state.extra as QuizMode? ?? QuizMode.study),
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
