import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _hasNetwork(dynamic value) {
  if (value is List<ConnectivityResult>) {
    return value.any((item) => item != ConnectivityResult.none);
  }
  if (value is ConnectivityResult) {
    return value != ConnectivityResult.none;
  }
  return true;
}

final isOfflineProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  final connectivity = Connectivity();

  Future<void> emitInitial() async {
    try {
      final initial = await connectivity.checkConnectivity();
      controller.add(!_hasNetwork(initial));
    } catch (_) {
      controller.add(false);
    }
  }

  emitInitial();

  final sub = connectivity.onConnectivityChanged.listen((event) {
    controller.add(!_hasNetwork(event));
  });

  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });

  return controller.stream;
});
