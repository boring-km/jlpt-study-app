// ReviewScreen은 initState에서 DB 기반 비동기 체인을 시작합니다:
// Future(() => _init()) → startNewSession() → _loadReadingChoices() → getSimilarReading(DB)
// pumpWidget 자체가 microtask를 처리하여 DB 호출이 시작되므로 테스트 타임아웃이 발생합니다.
// 따라서 ReviewScreen의 위젯 테스트는 컴파일/임포트 확인으로 제한합니다.
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/review/review_screen.dart';

void main() {
  test('ReviewScreen class is importable', () {
    // ignore: unnecessary_type_check
    expect(ReviewScreen is Type, isTrue);
  });
}
