part of 'home_bloc.dart';

enum HomeStatus { initial, loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.stats = LearnerStats.empty,
    this.message,
  });

  final HomeStatus status;
  final LearnerStats stats;

  /// Set when the deck could not be prepared at all.
  final String? message;

  bool get hasWordsDue => stats.hasWordsDue;

  HomeState copyWith({
    HomeStatus? status,
    LearnerStats? stats,
    String? message,
  }) => HomeState(
    status: status ?? this.status,
    stats: stats ?? this.stats,
    message: message,
  );

  @override
  List<Object?> get props => [status, stats, message];
}
