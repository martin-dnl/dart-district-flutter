import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/app_constants.dart';

class ContactsRealtimeService {
  io.Socket? _socket;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  void connect({required String userId}) {
    if (_socket != null) return;

    final socket = io.io(
      '${AppConstants.wsBaseUrl}/system',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    socket.onConnect((_) {
      _connectionController.add(true);
      socket.emit('subscribe_user', {'user_id': userId});
    });

    socket.onDisconnect((_) {
      _connectionController.add(false);
    });

    socket.onConnectError((_) {
      _connectionController.add(false);
    });

    socket.onError((_) {
      _connectionController.add(false);
    });

    socket.on('direct_message', (payload) {
      if (payload is Map) {
        _messageController.add(Map<String, dynamic>.from(payload));
      }
    });

    _socket = socket;
    socket.connect();
  }

  void sendDirectMessage({
    required String fromUserId,
    required String toUserId,
    required String content,
  }) {
    _socket?.emit('direct_message', {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'content': content,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
