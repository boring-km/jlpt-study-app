import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/word_catalog_provider.dart';

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
      // raw 예외 대신 사람 말. 사용자에겐 다음에 할 일을 주고, 원인은 로그로 남긴다.
      error: (e, st) {
        developer.log(
          'catalog load failed',
          error: e,
          stackTrace: st,
          name: 'jlpt',
        );
        return const _SplashBody(message: '단어 데이터를 불러오지 못했다. 앱을 다시 실행해 주세요.');
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  final String message;
  const _SplashBody({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('JLPT', style: theme.textTheme.displayLarge),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
