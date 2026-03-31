import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_constants.dart';

class WebSocketClient {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  bool _isConnected = false;
  String? _currentUrl;

  void connect({String? url}) {
    _currentUrl = url ?? AppConstants.wsBaseUrl;
    _establishConnection();
  }

  void _establishConnection() {
    if (_currentUrl == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      _isConnected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          _messageController.add(decoded);
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
      );

      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void send(String event, Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) return;

    final payload = jsonEncode({
      'event': event,
      'data': data,
    });
    _channel!.sink.add(payload);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: AppConstants.wsHeartbeatInterval),
      (_) => send('ping', {}),
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(seconds: AppConstants.wsReconnectDelay),
      _establishConnection,
    );
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
