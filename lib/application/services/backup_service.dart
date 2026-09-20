import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/database.dart';

/// 데이터베이스 백업 내보내기/가져오기.
class BackupService {
  /// [path]의 파일이 우리 스키마의 sqlite DB인지 순수 sqflite로 검증.
  static Future<bool> isValidBackup(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('words','word_progress')",
      );
      return rows.length == 2;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  /// 현재 DB 파일을 공유 시트로 내보낸다.
  Future<void> export() async {
    final path = await AppDatabase.filePath;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, name: 'jlpt-backup-$stamp.db')]),
    );
  }

  /// 파일 선택 → 검증 → DB 닫고 교체. 성공 시 true.
  Future<bool> pickAndImport() async {
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (path == null) return false;
    return importFrom(path);
  }

  /// [sourcePath]가 유효한 백업이면 [targetPath](기본값: 현재 DB 파일 경로)를
  /// 덮어쓴다. 실제 앱 DB를 교체하는 경우 먼저 [AppDatabase.close]로 닫는다.
  Future<bool> importFrom(String sourcePath, {String? targetPath}) async {
    if (!await isValidBackup(sourcePath)) return false;
    await AppDatabase.close();
    final target = targetPath ?? await AppDatabase.filePath;
    await File(sourcePath).copy(target);
    return true;
  }
}
