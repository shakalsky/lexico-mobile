part of 'home_bloc.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => const [];
}

/// First load: make sure a deck exists, then read the stats.
final class HomeStarted extends HomeEvent {
  const HomeStarted();
}

/// Re-read the stats without touching the network — used when coming back
/// from a session.
final class HomeRefreshed extends HomeEvent {
  const HomeRefreshed();
}
