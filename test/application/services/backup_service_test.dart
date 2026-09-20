import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/application/services/backup_service.dart';
import 'package:jlpt/core/db/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('isValidBackup true for our schema, false for random file', () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final good = p.join(dir.path, 'good.db');
    final db = await AppDatabase.openAtPath(good);
    await db.close();
    expect(await BackupService.isValidBackup(good), isTrue);
    final bad = p.join(dir.path, 'bad.db');
    await File(bad).writeAsString('not a db');
    expect(await BackupService.isValidBackup(bad), isFalse);
    await dir.delete(recursive: true);
  });

  test('importFrom copies a valid backup over the target path', () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final source = p.join(dir.path, 'source.db');
    final db = await AppDatabase.openAtPath(source);
    await db.close();

    final target = p.join(dir.path, 'target.db');
    // 기존 대상 파일이 있는 상태를 시뮬레이션.
    await File(target).writeAsString('old target contents');

    final ok = await BackupService().importFrom(source, targetPath: target);

    expect(ok, isTrue);
    expect(
      await File(target).readAsBytes(),
      await File(source).readAsBytes(),
    );

    await dir.delete(recursive: true);
  });

  test('importFrom returns false and leaves target untouched for an invalid file',
      () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final bad = p.join(dir.path, 'bad.db');
    await File(bad).writeAsString('not a db');

    final target = p.join(dir.path, 'target.db');
    const originalContents = 'original target contents';
    await File(target).writeAsString(originalContents);

    final ok = await BackupService().importFrom(bad, targetPath: target);

    expect(ok, isFalse);
    expect(await File(target).readAsString(), originalContents);

    await dir.delete(recursive: true);
  });

  test('isValidBackup rejects a backup from a newer schema version', () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final future = p.join(dir.path, 'future.db');
    final db = await AppDatabase.openAtPath(future);
    await db.execute('PRAGMA user_version = 99');
    await db.close();

    expect(await BackupService.isValidBackup(future), isFalse);

    await dir.delete(recursive: true);
  });

  test('snapshotForShare copies to a temp file named jlpt-backup-<date>.db',
      () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final source = p.join(dir.path, 'source.db');
    final db = await AppDatabase.openAtPath(source);
    await db.close();

    final backupDir = Directory(p.join(dir.path, 'jlpt-backups'));
    final now = DateTime(2026, 9, 20);
    final snapshot = await BackupService.snapshotForShare(
      source,
      now: now,
      backupDir: backupDir,
    );

    expect(p.basename(snapshot.path), 'jlpt-backup-2026-09-20.db');
    expect(snapshot.path, isNot(source));
    expect(
      await snapshot.readAsBytes(),
      await File(source).readAsBytes(),
    );
    // 공유가 끝나기 전에 스냅샷이 지워지면 안 되므로, 반환 직후에도
    // 파일이 여전히 존재해야 한다 (export()가 공유 완료 직후 삭제하던
    // 이전 동작에서 되돌아간 부분).
    expect(await snapshot.exists(), isTrue);

    await dir.delete(recursive: true);
  });

  test(
      'snapshotForShare clears stale files from a previous export before writing the new one',
      () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final source = p.join(dir.path, 'source.db');
    final db = await AppDatabase.openAtPath(source);
    await db.close();

    final backupDir = Directory(p.join(dir.path, 'jlpt-backups'));
    await backupDir.create(recursive: true);
    final stale = File(p.join(backupDir.path, 'jlpt-backup-2020-01-01.db'));
    await stale.writeAsString('stale file left by a previous export');

    final now = DateTime(2026, 9, 20);
    final snapshot = await BackupService.snapshotForShare(
      source,
      now: now,
      backupDir: backupDir,
    );

    expect(await stale.exists(), isFalse);
    expect(await snapshot.exists(), isTrue);
    expect(p.basename(snapshot.path), 'jlpt-backup-2026-09-20.db');

    await dir.delete(recursive: true);
  });
}
