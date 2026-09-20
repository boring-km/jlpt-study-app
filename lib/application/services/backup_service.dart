import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/database.dart';

/// 데이터베이스 백업 내보내기/가져오기.
class BackupService {
  /// [path]의 파일이 우리 스키마의 sqlite DB이고, 이 앱이 열 수 있는 버전인지
  /// 순수 sqflite로 검증한다. 우리보다 새로운 스키마 버전이면 거부한다 —
  /// sqflite의 기본 다운그레이드 처리는 예외를 던지므로, 미래 버전 백업을
  /// 그대로 받아들이면 이후 모든 DB 접근이 영구적으로 깨진다.
  static Future<bool> isValidBackup(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('words','word_progress')",
      );
      if (rows.length != 2) return false;

      final versionRows = await db.rawQuery('PRAGMA user_version');
      final userVersion = versionRows.first.values.first as int? ?? 0;
      return userVersion <= AppDatabase.kVersion;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  /// [sourcePath]의 DB를 `jlpt-backup-<yyyy-MM-dd>.db`라는 이름의 임시 파일로
  /// 복사한다. dart:io `XFile`은 디스크 파일의 `name`을 무시하고 경로의
  /// basename을 쓰므로(share_plus도 파일명을 바꿔주지 않는다), 공유 시트에
  /// 원하는 파일명을 강제하려면 그 이름의 파일 자체를 만들어야 한다.
  /// 테스트에서 검증할 수 있도록 [export]에서 분리했다.
  @visibleForTesting
  static Future<File> snapshotForShare(String sourcePath, {DateTime? now}) async {
    final stamp = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final tempDir = await Directory.systemTemp.createTemp('jlpt_export');
    final snapshotPath = p.join(tempDir.path, 'jlpt-backup-$stamp.db');
    await File(sourcePath).copy(snapshotPath);
    return File(snapshotPath);
  }

  /// 현재 DB 파일의 스냅샷을 공유 시트로 내보낸다.
  Future<void> export() async {
    final path = await AppDatabase.filePath;
    final snapshot = await snapshotForShare(path);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(snapshot.path)]),
      );
    } finally {
      await snapshot.parent.delete(recursive: true);
    }
  }

  /// 파일 선택 → 검증 → DB 닫고 교체. 성공 시 true.
  Future<bool> pickAndImport() async {
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (path == null) return false;
    return importFrom(path);
  }

  /// [sourcePath]가 유효한 백업이면 [targetPath](기본값: 현재 DB 파일 경로)를
  /// 교체한다. 실제 앱 DB를 교체하는 경우([targetPath]를 안 준 경우)에만 먼저
  /// [AppDatabase.close]로 닫는다. 교체는 임시 파일로 복사한 뒤 원자적으로
  /// rename하여, 복사 도중 실패해도 기존 대상 파일이 손상되지 않게 한다.
  Future<bool> importFrom(String sourcePath, {String? targetPath}) async {
    if (!await isValidBackup(sourcePath)) return false;

    final replacingLiveDb = targetPath == null;
    if (replacingLiveDb) {
      await AppDatabase.close();
    }

    final target = targetPath ?? await AppDatabase.filePath;
    final tempTarget = '$target.import-tmp';
    await File(sourcePath).copy(tempTarget);
    await File(tempTarget).rename(target);
    return true;
  }
}
