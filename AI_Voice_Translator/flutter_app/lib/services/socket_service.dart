import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  // Stream controllers for broadcasting events to UI
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _peerEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  final _callStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<Map<String, dynamic>> get peerEvents => _peerEventController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<Map<String, dynamic>> get signaling => _signalingController.stream;
  Stream<Map<String, dynamic>> get callStatus => _callStatusController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String backendUrl) {
    if (_socket != null && _socket!.connected) return;

    final cleanUrl = normalizeUrl(backendUrl);
    _socket = IO.io(cleanUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('🟢 Connected to WebSocket Server at $cleanUrl');
    });

    _socket!.onConnectError((data) {
      print('❌ Socket Connection Error: $data');
      _errorController.add('Socket connection error');
    });

    _socket!.onDisconnect((_) {
      print('🔴 Disconnected from WebSocket Server');
    });

    _socket!.on('translated_message', (data) {
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_sent_ack', (data) {
      // Echo back what we sent, for local history display
      final echo = Map<String, dynamic>.from(data);
      echo['isMe'] = true;
      _messageController.add(echo);
    });

    _socket!.on('peer_joined', (data) {
      _peerEventController.add({...Map<String, dynamic>.from(data), 'type': 'joined'});
    });

    _socket!.on('peer_left', (data) {
      _peerEventController.add({...Map<String, dynamic>.from(data), 'type': 'left'});
    });

    _socket!.on('socket_error', (data) {
      final msg = data['message'] ?? 'Unknown socket error';
      _errorController.add(msg.toString());
    });

    _socket!.on('webrtc_signal', (data) {
      _signalingController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('call_status', (data) {
      _callStatusController.add(Map<String, dynamic>.from(data));
    });
  }

  void joinRoom(String roomCode) {
    if (!isConnected) return;
    _socket!.emit('join_room', roomCode);
  }

  void leaveRoom(String roomCode) {
    if (!isConnected) return;
    _socket!.emit('leave_room', roomCode);
  }

  void sendVoiceMessage({
    required String roomCode,
    required String sourceLang,
    required String targetLang,
    required String audioBase64,
  }) {
    if (!isConnected) return;
    _socket!.emit('voice_message', {
      'roomCode': roomCode,
      'sourceLang': sourceLang,
      'targetLang': targetLang,
      'audioBase64': audioBase64,
    });
  }

  void sendSignaling({required String roomCode, required Map<String, dynamic> payload}) {
    if (!isConnected) return;
    _socket!.emit('webrtc_signal', {
      'roomCode': roomCode,
      'payload': payload,
    });
  }

  void sendCallStatus({required String roomCode, required String status}) {
    if (!isConnected) return;
    _socket!.emit('call_status', {
      'roomCode': roomCode,
      'status': status,
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
