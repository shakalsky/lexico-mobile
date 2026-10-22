import 'package:lexico/core/error/failure.dart';

/// A tiny `Either`: every use case returns one of these instead of throwing.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = Err<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Err<T>(:final failure) => onFailure(failure),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Success<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Success($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}
