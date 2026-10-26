import 'package:connectivity_plus/connectivity_plus.dart';

/// Tells the data layer when the device goes on or off line.
abstract interface class NetworkMonitor {
  /// `true` each time the device gets a network connection, `false` each
  /// time it loses it. A connection doesn't promise the word service can be
  /// reached; it is only a good moment to try.
  Stream<bool> get onlineChanges;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none))
      .distinct();
}
