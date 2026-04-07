import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(wordCatalogProvider);

    return catalog.when(
      data: (words) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/');
        });
        return const _SplashBody(message: '준비 완료');
      },
      loading: () => const _SplashBody(message: '단어 데이터 로딩 중...'),
      error: (e, _) => _SplashBody(message: '로딩 실패: $e'),
    );
  }
}

class _SplashBody extends StatelessWidget {
  final String message;
  const _SplashBody({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'JLPT',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 24),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
