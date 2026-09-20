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

  /// 내보내기 스냅샷을 보관하는 고정 디렉터리. 공유 시트가 공유 완료를
  /// 알려주는 시점과, AirDrop/Mail 등 실제로 파일을 다 읽는 시점이 다를 수
  /// 있어(비동기로 읽는 대상들) 공유 직후 삭제하면 백업이 비어 있거나
  /// 누락된 채로 전달될 수 있다 — 그래서 공유 후에는 지우지 않고, 매
  /// 내보내기 시작 시점에 지난 스냅샷을 정리한다.
  static Future<Directory> _defaultBackupDir() async =>
      Directory(p.join(Directory.systemTemp.path, 'jlpt-backups'));

  /// [sourcePath]의 DB를 `jlpt-backup-<yyyy-MM-dd>.db`라는 이름의 파일로
  /// [backupDir](기본값: 고정된 `<systemTemp>/jlpt-backups`)에 복사한다.
  /// dart:io `XFile`은 디스크 파일의 `name`을 무시하고 경로의 basename을
  /// 쓰므로(share_plus도 파일명을 바꿔주지 않는다), 공유 시트에 원하는
  /// 파일명을 강제하려면 그 이름의 파일 자체를 만들어야 한다. 새 스냅샷을
  /// 쓰기 전에 그 디렉터리에 남아 있던 이전 내보내기 파일을 먼저 지운다.
  /// 테스트에서 검증할 수 있도록 [export]에서 분리했다.
  @visibleForTesting
  static Future<File> snapshotForShare(
    String sourcePath, {
    DateTime? now,
    Directory? backupDir,
  }) async {
    final dir = backupDir ?? await _defaultBackupDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    final stamp = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    final snapshotPath = p.join(dir.path, 'jlpt-backup-$stamp.db');
    await File(sourcePath).copy(snapshotPath);
    return File(snapshotPath);
  }

  /// 현재 DB 파일의 스냅샷을 공유 시트로 내보낸다. 스냅샷은 공유 완료 직후가
  /// 아니라 다음 내보내기 시작 시점에 정리된다 (위 [snapshotForShare] 참고).
  Future<void> export() async {
    final path = await AppDatabase.filePath;
    final snapshot = await snapshotForShare(path);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(snapshot.path)]),
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
