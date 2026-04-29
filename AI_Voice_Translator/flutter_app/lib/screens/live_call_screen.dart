import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import '../constants.dart';
import '../services/socket_service.dart';
import '../services/history_service.dart';
import '../models/translation_record.dart';

class LiveCallScreen extends StatefulWidget {
  final String? initialRoom;
  const LiveCallScreen({super.key, this.initialRoom});
  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> with TickerProviderStateMixin {
  final SocketService _socket = SocketService();
  final AudioRecorderService _recorderService = AudioRecorderService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  
  bool _inRoom = false;
  String _roomCode = '';
  
  Language _myLang = kLanguages.first; // Auto
  Language _theirLang = kLanguages[1]; // English
  
  String _backendUrl = kDefaultBackendUrl;
  bool _isRecording = false;
  bool _isProcessing = false;
  
  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer(); // Though we only use audio
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  String _callStatus = 'idle'; // idle, calling, connected, ended
  
  Timer? _callTimer;
  int _secondsElapsed = 0;
  Timer? _autoTranslateTimer;

  List<Map<String, dynamic>> _messages = [];
  final HistoryService _historyService = HistoryService();
  
  // ICE Candidate Queue
  final List<RTCIceCandidate> _remoteCandidatesQueue = [];

  // Animations
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _initTts();
    
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    
    _socket.messages.listen(_onMessageReceived);
    _socket.peerEvents.listen(_onPeerEvent);
    _socket.errors.listen(_onError);
    _socket.signaling.listen(_onSignalingReceived);
    _socket.callStatus.listen(_onCallStatusReceived);

    _initRenderers();

    if (widget.initialRoom != null && widget.initialRoom!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinRoom(widget.initialRoom!);
      });
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? kDefaultBackendUrl;
    });
  }

  void _initTts() {
    _tts.setSpeechRate(0.5);
    _tts.setVolume(1.0);
    _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    _audioPlayer.dispose(); // Dispose premium player
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.dispose();
    if (_inRoom) _socket.leaveRoom(_roomCode);
    _socket.dispose();
    super.dispose();
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _onMessageReceived(Map<String, dynamic> data) async {
    final record = TranslationRecord(
      transcript: data['originalText'] ?? '',
      translation: data['translatedText'] ?? '',
      sourceLang: data['sourceLang'] ?? '',
      targetLang: data['targetLang'] ?? '',
      outputMode: 'speaker',
      createdAt: DateTime.now(),
    );
    await _historyService.insertRecord(record);

    if (mounted) setState(() => _messages.add(data));
    
    // Auto-play the translation
    if (data['isMe'] != true) {
      final audioBase64 = data['audioBase64'];
      final text = data['translatedText'];
      final lang = data['targetLang'];

      if (audioBase64 != null) {
        print('🔊 [LiveCall] Playing premium Polly audio');
        try {
          final bytes = base64Decode(audioBase64);
          await _audioPlayer.setAudioSource(MyCustomSource(bytes));
          await _audioPlayer.play();
        } catch (e) {
          print('❌ [LiveCall] Polly playback failed: $e');
        }
      } else if (text != null) {
        print('🔊 [LiveCall] Playing fallback local TTS');
        if (lang != 'auto') await _tts.setLanguage(lang);
        await _tts.speak(text);
      }
    } else {
      // It's our own ack coming back, means processing is done
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onPeerEvent(Map<String, dynamic> data) {
    print('👥 [LiveCall] Peer event: ${data['type']} from ${data['id']}');
    if (data['type'] == 'joined') {
      // If we are already in the room, start the WebRTC connection
      if (_inRoom) {
        print('📡 [LiveCall] Starting call because peer joined');
        _startCall();
      }
    }
  }

  void _onSignalingReceived(Map<String, dynamic> data) async {
    final payload = data['payload'];
    if (payload == null) return;
    
    final type = payload['type'];
    print('📡 [LiveCall] Signaling received: $type from ${data['senderId']}');
    
    if (type == 'offer') {
      await _handleOffer(payload);
    } else if (type == 'answer') {
      await _handleAnswer(payload);
    } else if (type == 'candidate') {
      await _handleIceCandidate(payload);
    }
  }

  void _processQueuedCandidates() async {
    if (_peerConnection == null) return;
    print('📡 [LiveCall] Processing ${_remoteCandidatesQueue.length} queued ICE candidates');
    for (var candidate in _remoteCandidatesQueue) {
      await _peerConnection!.addCandidate(candidate);
    }
    _remoteCandidatesQueue.clear();
  }

  void _onCallStatusReceived(Map<String, dynamic> data) {
    final status = data['status'];
    print('📞 [LiveCall] Call status from peer: $status');
    setState(() {
      _callStatus = status;
      if (_callStatus == 'connected') _startTimers();
      if (_callStatus == 'ended') _leaveRoom();
    });
  }

  void _onError(String error) {
    print('❌ [LiveCall] Error: $error');
    setState(() => _isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: kError, content: Text(error)));
    }
  }

  Future<void> _startCall() async {
    print('📡 [LiveCall] Initiating WebRTC offer...');
    setState(() => _callStatus = 'calling');
    _peerConnection = await _createPeerConnection();
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _socket.sendSignaling(roomCode: _roomCode, payload: offer.toMap());
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
      ]
    };
    
    final pc = await createPeerConnection(config);
    
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      _socket.sendSignaling(roomCode: _roomCode, payload: {
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };

    pc.onIceConnectionState = (state) {
      print('ICE Connection State: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _socket.sendCallStatus(roomCode: _roomCode, status: 'connected');
        setState(() => _callStatus = 'connected');
        _startTimers();
      }
    };

    pc.onConnectionState = (state) {
      print('Peer Connection State: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _callStatus = 'connected');
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected || 
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _leaveRoom();
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
        });
      }
    };

    return pc;
  }

  Future<void> _handleOffer(dynamic payload) async {
    _peerConnection = await _createPeerConnection();
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
    
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    _socket.sendSignaling(roomCode: _roomCode, payload: answer.toMap());
    _processQueuedCandidates();
  }

  Future<void> _handleAnswer(dynamic payload) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(payload['sdp'], payload['type']));
    _processQueuedCandidates();
  }

  Future<void> _handleIceCandidate(dynamic payload) async {
    final candidateData = payload['candidate'];
    final candidate = RTCIceCandidate(candidateData['candidate'], candidateData['sdpMid'], candidateData['sdpMLineIndex']);
    
    if (_peerConnection != null && await _peerConnection!.getRemoteDescription() != null) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _remoteCandidatesQueue.add(candidate);
    }
  }

  void _startTimers() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });

    // Start auto-translation loop
    _performAutoTranslation();
  }

  void _performAutoTranslation() async {
    if (!_inRoom || _callStatus != 'connected') return;
    
    // This will trigger a short recording and send it
    if (_isRecording) return;
    
    try {
      await _startRecording();
      await Future.delayed(const Duration(seconds: 5)); // Record for 5 seconds
      if (mounted) {
        await _stopRecording();
        // Immediately start next recording cycle for seamless coverage
        _performAutoTranslation();
      }
    } catch (e) {
      print('❌ [LiveCall] Translation cycle error: $e');
      if (mounted) {
        setState(() { _isRecording = false; _isProcessing = false; });
        // Retry after a short delay if it failed
        Future.delayed(const Duration(seconds: 2), _performAutoTranslation);
      }
    }
  }

  void _joinRoom(String code) {
    if (code.isEmpty || code.length < 3) return;
    
    print('👥 [LiveCall] Joining room: $code');
    setState(() {
      _roomCode = code;
      _inRoom = true;
      _messages.clear();
      _secondsElapsed = 0;
      _callStatus = 'connecting...';
    });

    _socket.connect(_backendUrl);
    
    // Periodically check connection and join
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      if (_socket.isConnected) {
        print('🟢 [LiveCall] Socket connected, sending join_room for $code');
        _socket.joinRoom(code);
        timer.cancel();
      } else if (attempts > 20) { // Timeout after 10 seconds
        timer.cancel();
        print('❌ [LiveCall] Socket connection timeout for $code');
        _onError('Connection timeout. Please check your backend URL and internet.');
        if (mounted) setState(() => _inRoom = false);
      }
    });
  }

  void _leaveRoom() {
    _socket.sendCallStatus(roomCode: _roomCode, status: 'ended');
    _socket.leaveRoom(_roomCode);
    
    _callTimer?.cancel();
    _autoTranslateTimer?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    
    setState(() {
      _inRoom = false;
      _roomCode = '';
      _callStatus = 'idle';
      _secondsElapsed = 0;
    });
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() => _isMuted = !audioTrack.enabled);
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      Helper.setSpeakerphoneOn(_isSpeakerOn);
    });
  }

  String _formatTimer(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      setState(() => _isRecording = true);
      _pulseCtrl.repeat(reverse: true);
      
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.opus,
        numChannels: 1,
        sampleRate: 16000,
      ));
      
      // We will collect chunks and send upon release
      _audioChunks.clear();
      _streamSub = stream.listen((data) => _audioChunks.addAll(data));
    }
  }

  List<int> _audioChunks = [];
  StreamSubscription? _streamSub;

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _pulseCtrl.reset();
    
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });
    
    await _recorder.stop();
    await _streamSub?.cancel();
    
    if (_audioChunks.isNotEmpty) {
      final base64Audio = base64Encode(Uint8List.fromList(_audioChunks));
      _socket.sendVoiceMessage(
        roomCode: _roomCode,
        sourceLang: _myLang.code,
        targetLang: _theirLang.code,
        audioBase64: base64Audio,
      );
    } else {
      setState(() => _isProcessing = false);
    }
  }

  // UI rendering
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _inRoom ? _buildActiveRoom() : _buildJoinRoom(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Live Call', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildJoinRoom() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(_roomCode.isEmpty ? 'Enter number' : _roomCode, 
            style: GoogleFonts.inter(fontSize: 36, letterSpacing: 2, fontWeight: FontWeight.bold, color: _roomCode.isEmpty ? kTextHint : Colors.white),
          ),
          const SizedBox(height: 40),
          
          Wrap(
            spacing: 24, runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _dialKey('1'), _dialKey('2', sub: 'ABC'), _dialKey('3', sub: 'DEF'),
              _dialKey('4', sub: 'GHI'), _dialKey('5', sub: 'JKL'), _dialKey('6', sub: 'MNO'),
              _dialKey('7', sub: 'PQRS'), _dialKey('8', sub: 'TUV'), _dialKey('9', sub: 'WXYZ'),
              _dialKey('*'), _dialKey('0', sub: '+'), _dialKey('#'),
            ],
          ),
          
          const SizedBox(height: 40),
          
          Row(
            children: [
              Expanded(child: _langPicker('I speak', _myLang, (l) => setState(() => _myLang = l))),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_rounded, color: kTextHint),
              const SizedBox(width: 16),
              Expanded(child: _langPicker('They speak', _theirLang, (l) => setState(() => _theirLang = l))),
            ],
          ),
          
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Delete Button
              IconButton(
                onPressed: _roomCode.isNotEmpty 
                  ? () => setState(() => _roomCode = _roomCode.substring(0, _roomCode.length - 1)) 
                  : null,
                icon: const Icon(Icons.backspace_outlined, size: 28),
                color: kTextSecondary,
              ),
              const SizedBox(width: 24),
              // Call Button
              GestureDetector(
                onTap: _roomCode.length >= 3 ? () => _joinRoom(_roomCode) : null,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _roomCode.length >= 3 ? const Color(0xFF4CAF50) : kCard,
                    shape: BoxShape.circle,
                    boxShadow: _roomCode.length >= 3 ? [BoxShadow(color: const Color(0xFF4CAF50).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : null,
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(width: 52), // Balance visually against backspace
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _dialKey(String num, {String? sub}) {
    return GestureDetector(
      onTap: () {
        if (_roomCode.length < 15) setState(() => _roomCode += num);
      },
      child: Container(
        width: 76, height: 76,
        decoration: BoxDecoration(color: kCard.withOpacity(0.5), shape: BoxShape.circle),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white)),
            if (sub != null) Text(sub, style: GoogleFonts.inter(fontSize: 10, color: kTextHint, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _langPicker(String label, Language current, Function(Language) onSelect) {
    return GestureDetector(
      onTap: () {
        // Simple bottom sheet picker
        showModalBottomSheet(
          context: context,
          backgroundColor: kCard,
          builder: (_) => ListView.builder(
            itemCount: kLanguages.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(kLanguages[i].name, style: const TextStyle(color: Colors.white)),
              onTap: () { onSelect(kLanguages[i]); Navigator.pop(context); },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: kTextHint, fontSize: 12)),
            const SizedBox(height: 4),
            Text(current.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRoom() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Caller Info Area
                  const Icon(Icons.account_circle, size: 80, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('Room $_roomCode', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.normal, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_callStatus == 'connected' ? _formatTimer(_secondsElapsed) : _callStatus.toUpperCase(), 
                    style: GoogleFonts.inter(fontSize: 16, color: _callStatus == 'connected' ? kAccentLight : Colors.white54)),
                  
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 48),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${_myLang.name} 🇺🇸', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.sync_alt_rounded, color: Colors.white54, size: 16),
                        ),
                        Text('${_theirLang.name} 🇪🇸', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  if (_messages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            _messages.last['originalText'] ?? '',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white54, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _messages.last['translatedText'] ?? '...',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    
                  const Spacer(),
                  
                  // Calling Pad Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _callActionBtn(
                          _isMuted ? Icons.mic_off : Icons.mic, 
                          'Mute', 
                          _isMuted, 
                          onTap: _toggleMute
                        ),
                        // Indicator for auto-translation
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? kPrimary : kCard,
                            gradient: _isRecording ? kPrimaryGradient : null,
                          ),
                          child: Center(
                            child: _isProcessing 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Icon(Icons.auto_awesome, size: 32, color: _isRecording ? Colors.white : kPrimaryLight),
                          ),
                        ),
                        _callActionBtn(
                          _isSpeakerOn ? Icons.volume_up : Icons.volume_down, 
                          'Speaker', 
                          _isSpeakerOn, 
                          onTap: _toggleSpeaker
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_isRecording ? 'Translating...' : 'AI Listening', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                  
                  const SizedBox(height: 32),
                  
                  // End Call Button
                  GestureDetector(
                    onTap: _leaveRoom,
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _callActionBtn(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: isActive ? Colors.white : kCard.withOpacity(0.5),
            ),
            child: Icon(icon, size: 28, color: isActive ? Colors.black : Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────
class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      contentType: 'audio/mpeg',
      stream: Stream.value(bytes.sublist(start, end)),
    );
  }
}
