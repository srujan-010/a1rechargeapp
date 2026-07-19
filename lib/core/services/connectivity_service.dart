// lib/core/services/connectivity_service.dart
// Monitors network state using connectivity_plus.
// Drives the offline banner across all screens.
// Provides a stream for reactive UI updates and a synchronous check for pre-submit validation.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  ConnectivityService() : _connectivity = Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  final _controller = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _currentStatus = NetworkStatus.online;

  Stream<NetworkStatus> get statusStream => _controller.stream;
  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == NetworkStatus.online;

  void _init() {
    _connectivity.onConnectivityChanged.listen(
      (results) {
        final status = _mapResults(results);
        if (status != _currentStatus) {
          _currentStatus = status;
          _controller.add(status);
          AppLogger.info(
            'Network status changed: ${status.name}',
            tag: 'Connectivity',
          );
        }
      },
      onError: (Object error) {
        AppLogger.error('Connectivity stream error', tag: 'Connectivity', error: error);
      },
    );

    // Initial check
    checkConnectivity();
  }

  Future<NetworkStatus> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _currentStatus = _mapResults(results);
      return _currentStatus;
    } catch (e) {
      AppLogger.warning('Could not check connectivity', tag: 'Connectivity', error: e);
      return NetworkStatus.online; // Assume online if check fails
    }
  }

  NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkStatus.offline;
    return results.any((r) => r != ConnectivityResult.none)
        ? NetworkStatus.online
        : NetworkStatus.offline;
  }

  void dispose() {
    _controller.close();
  }
}
