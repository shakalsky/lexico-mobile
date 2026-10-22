import 'package:equatable/equatable.dart';

/// Everything that can go wrong, expressed in terms the domain understands.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The backend answered, but not with what we asked for.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, this.code});

  final int? statusCode;

  /// The API's machine-readable error, e.g. `deck_not_found`.
  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
}

/// We never reached the backend (offline, timeout, DNS, ...).
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No connection to the word service.']);
}

/// The local database refused to read or write.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not reach the local library.']);
}

/// There is nothing left to study right now.
final class EmptyDeckFailure extends Failure {
  const EmptyDeckFailure([super.message = 'There are no words to study yet.']);
}

/// The input was refused before anything was saved.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong.']);
}
