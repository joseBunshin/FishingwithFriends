import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Reactive online/offline state. Combines `connectivity_plus` (interface
/// up?) with `internet_connection_checker_plus` (actually reachable?) so
/// the orchestrator doesn't drain the queue against a captive-portal
/// Wi-Fi or a cell that has signal but no data.
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    InternetConnection? checker,
  })  : _connectivity = connectivity ?? Connectivity(),
        _checker = checker ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _checker;

  /// Stream of `true` (online) / `false` (offline) — debounced by the
  /// underlying packages.
  Stream<bool> onlineStream() async* {
    // Seed with current state.
    yield await isOnline();
    await for (final _ in _connectivity.onConnectivityChanged) {
      yield await isOnline();
    }
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    return _checker.hasInternetAccess;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onlineStream();
});
