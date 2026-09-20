import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 스크린샷이 저장되는 디렉터리. `--dart-define`이나 환경변수로 바꿀 수 있다.
String get _screenshotDir =>
    Platform.environment['JLPT_SCREENSHOT_DIR'] ?? 'build/screenshots';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory(_screenshotDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('screenshot saved: ${file.path}');
      return true;
    },
  );
}
