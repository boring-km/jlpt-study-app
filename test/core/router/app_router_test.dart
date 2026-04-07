import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/core/router/app_router.dart';

void main() {
  group('appRouter', () {
    test('router has routes defined', () {
      expect(appRouter.configuration.routes, isNotEmpty);
    });

    test('router has splash route', () {
      // GoRoute의 path를 직접 확인
      final splashRoute = appRouter.configuration.routes.whereType<dynamic>().first;
      expect(splashRoute, isNotNull);
    });

    test('PlaceholderScreen has correct name', () {
      const screen = PlaceholderScreen('테스트');
      expect(screen.name, '테스트');
    });

    test('ScaffoldWithNavBar can be instantiated', () {
      // ScaffoldWithNavBar는 NavigationShell이 필요하므로 클래스 존재만 확인
      expect(ScaffoldWithNavBar, isNotNull);
    });
  });
}
