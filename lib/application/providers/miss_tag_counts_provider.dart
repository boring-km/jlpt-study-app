import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/miss_log_repository.dart';
import 'database_provider.dart';

final missTagCountsProvider = FutureProvider<Map<ErrorTag, int>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return MissLogRepository(db).countByTag();
});
