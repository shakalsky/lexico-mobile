import 'package:lexico/core/result/result.dart';

/// One business action, one class. [Params] is [NoParams] when the action
/// needs no input.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

final class NoParams {
  const NoParams();
}
