import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const _wsBaseUrl = 'ws://localhost:8000';
const _storage = FlutterSecureStorage();

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  Timer? _reconnectTimer;
  String? _currentUrl;
  bool _isConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String channel) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    _currentUrl = '$_wsBaseUrl/ws/$channel?token=$token';
    _doConnect();
  }

  void _doConnect() {
    if (_currentUrl == null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      _isConnected = true;
      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data) as Map<String, dynamic>;
            _messageController.add(message);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

// Providers
final dashboardWsProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect('dashboard');
  ref.onDispose(() => service.dispose());
  return service;
});

final notificationsWsProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect('notifications');
  ref.onDispose(() => service.dispose());
  return service;
});

final inventoryWsProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect('inventory');
  ref.onDispose(() => service.dispose());
  return service;
});

final aiWsProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  service.connect('ai');
  ref.onDispose(() => service.dispose());
  return service;
});

// Stream providers for consuming in widgets
final dashboardUpdatesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final ws = ref.watch(dashboardWsProvider);
  return ws.messages;
});

final notificationUpdatesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final ws = ref.watch(notificationsWsProvider);
  return ws.messages;
});

final inventoryUpdatesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final ws = ref.watch(inventoryWsProvider);
  return ws.messages;
});

final aiStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final ws = ref.watch(aiWsProvider);
  return ws.messages;
});
