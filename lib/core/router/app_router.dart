import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/study/flashcard/flashcard_screen.dart';
import '../../features/study/quiz_reading/quiz_reading_screen.dart';
import '../../features/study/quiz_meaning/quiz_meaning_screen.dart';
import '../../features/study/wrong_answers/wrong_answers_screen.dart';
import '../../features/study/complete/complete_screen.dart';
import '../../features/review/review_screen.dart';

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
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'study/flashcard',
                builder: (context, state) => const FlashcardScreen(),
              ),
              GoRoute(
                path: 'study/quiz-reading',
                builder: (context, state) => const QuizReadingScreen(),
              ),
              GoRoute(
                path: 'study/quiz-meaning',
                builder: (context, state) => const QuizMeaningScreen(),
              ),
              GoRoute(
                path: 'study/wrong-answers',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  final stage = extra['stage'] as String? ?? 'reading';
                  return WrongAnswersScreen(stage: stage);
                },
              ),
              GoRoute(
                path: 'study/complete',
                builder: (context, state) => const CompleteScreen(),
              ),
              GoRoute(
                path: 'review',
                builder: (context, state) => const ReviewScreen(),
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
