import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backup_service.dart';

/// 테스트에서 가짜 [BackupService]로 오버라이드할 수 있도록 프로바이더로 제공.
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());
