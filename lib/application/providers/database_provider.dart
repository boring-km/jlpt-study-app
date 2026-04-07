import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/database.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance;
});
