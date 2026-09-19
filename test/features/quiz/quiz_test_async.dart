import 'package:flutter_test/flutter_test.dart';

/// 위젯 테스트는 FakeAsync 존에서 돌기 때문에 sqflite(실제 I/O) future가
/// 저절로 완료되지 않는다. 프레임을 굴리는 사이사이에 [WidgetTester.runAsync]로
/// 실제 이벤트 루프를 돌려 DB future를 완료시킨다.
/// (pumpAndSettle은 로딩 인디케이터가 무한 애니메이션이라 쓸 수 없다.)
Future<void> settleWithDb(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
  }
  await tester.pump();
}
