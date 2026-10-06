import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../network/api_client.dart';

enum ConnectionStatus {
  online,
  offline,
  serverUnavailable,
  syncing,
}

class ConnectivityNotifier extends StateNotifier<ConnectionStatus> {
  ConnectivityNotifier() : super(ConnectionStatus.offline) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _heartbeatTimer;
  bool _isSyncing = false;

  void _init() {
    _checkStatus();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _checkStatus();
    });

    // Heartbeat probe every 30 seconds to detect network drops or server restarts
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkStatus();
    });
  }

  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    if (_isSyncing) {
      state = ConnectionStatus.syncing;
    } else {
      _checkStatus();
    }
  }

  Future<void> checkNow() async {
    await _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_isSyncing) {
      state = ConnectionStatus.syncing;
      return;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);

      if (!hasNetwork) {
        state = ConnectionStatus.offline;
        return;
      }

      // We have network interface connection, now probe real server reachability
      final reachable = await _probeServerHealth();
      if (reachable) {
        state = ConnectionStatus.online;
      } else {
        state = ConnectionStatus.serverUnavailable;
      }
    } catch (_) {
      state = ConnectionStatus.offline;
    }
  }

  Future<bool> _probeServerHealth() async {
    try {
      final base = ApiClient.baseUrl;
      final uri = Uri.parse(base).replace(path: '/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final connectionStatusProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectionStatus>((ref) {
  return ConnectivityNotifier();
});
