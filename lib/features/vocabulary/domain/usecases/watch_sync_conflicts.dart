import 'package:lexico/features/vocabulary/domain/entities/sync_conflict.dart';
import 'package:lexico/features/vocabulary/domain/repositories/vocabulary_repository.dart';

/// Changes made offline that the word service refused, as they happen.
class WatchSyncConflicts {
  const WatchSyncConflicts(this._repository);

  final VocabularyRepository _repository;

  Stream<SyncConflict> call() => _repository.syncConflicts();
}
