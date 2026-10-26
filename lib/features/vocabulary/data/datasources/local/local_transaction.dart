import 'package:lexico/core/error/exception.dart';
import 'package:lexico/features/vocabulary/data/datasources/local/app_database.dart';

/// Runs several local writes as one: either all of them land or none do.
/// Every local data source shares the one [AppDatabase], so writes made
/// through any of them inside [call] join the same transaction.
class LocalTransaction {
  const LocalTransaction(this._db);

  final AppDatabase _db;

  Future<T> call<T>(Future<T> Function() action) =>
      guardLocal(() => _db.transaction(action));
}

/// Every database error leaves the data layer as a [CacheException].
Future<T> guardLocal<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on AppException {
    rethrow;
  } catch (error) {
    throw CacheException('Local database error: $error');
  }
}
