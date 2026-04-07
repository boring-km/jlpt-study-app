import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';

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
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '설정'),
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
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          ScaffoldWithNavBar(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PlaceholderScreen('홈'),
            routes: [
              GoRoute(
                path: 'study/flashcard',
                builder: (context, state) => const PlaceholderScreen('플래시카드'),
              ),
              GoRoute(
                path: 'study/quiz-reading',
                builder: (context, state) => const PlaceholderScreen('1단계 퀴즈'),
              ),
              GoRoute(
                path: 'study/quiz-meaning',
                builder: (context, state) => const PlaceholderScreen('2단계 퀴즈'),
              ),
              GoRoute(
                path: 'study/wrong-answers',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  return PlaceholderScreen('오답노트 stage=${extra['stage']}');
                },
              ),
              GoRoute(
                path: 'study/complete',
                builder: (context, state) => const PlaceholderScreen('학습 완료'),
              ),
              GoRoute(
                path: 'review',
                builder: (context, state) => const PlaceholderScreen('복습 퀴즈'),
              ),
              GoRoute(
                path: 'kana',
                builder: (context, state) => const PlaceholderScreen('가나표'),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/explore',
            builder: (context, state) => const PlaceholderScreen('탐색'),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/stats',
            builder: (context, state) => const PlaceholderScreen('통계'),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const PlaceholderScreen('설정'),
          ),
        ]),
      ],
    ),
  ],
);
