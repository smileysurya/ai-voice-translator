import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants.dart';
import '../models/translation_record.dart';
import '../services/audio_recorder_service.dart';
import '../services/audio_player_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../services/history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────
  Language _sourceLang = kLanguages[0];
  Language _targetLang = kLanguages.firstWhere((l) => l.code == 'en');
  OutputMode _outputMode = OutputMode.text;
  String _backendUrl = kDefaultBackendUrl;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _transcript = '';
  String _translation = '';
  String? _error;

  // ── Services ───────────────────────────────────────────────────────
  final _recorder = AudioRecorderService();
  final _player = AudioPlayerService();
  final _tts = TtsService();
  final _translationService = TranslationService();
  final _historyService = HistoryService();
  bool _isSpeaking = false;

  // ── Animations ─────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _ring1, _ring2, _ring3;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSettings();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _ring1 = Tween(begin: 1.0, end: 1.6).animate(CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _ring2 = Tween(begin: 1.0, end: 1.95).animate(CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.1, 0.8, curve: Curves.easeOut)));
    _ring3 = Tween(begin: 1.0, end: 2.35).animate(CurvedAnimation(parent: _pulseCtrl, curve: const Interval(0.2, 0.9, curve: Curves.easeOut)));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  Future<void> _loadSettings() async {
    final s = await _translationService.loadSettings();
    setState(() {
      _outputMode = s.outputMode;
      _backendUrl = s.backendUrl;
      _sourceLang = kLanguages.firstWhere((l) => l.code == s.sourceLang, orElse: () => kLanguages[0]);
      _targetLang = kLanguages.firstWhere((l) => l.code == s.targetLang, orElse: () => kLanguages[1]);
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndTranslate();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // On mobile (Android/iOS), explicitly request permission
    if (!kIsWeb) {
      try {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          _showError('Microphone permission denied');
          return;
        }
      } catch (_) {
        // On Windows desktop, permission is granted by the OS
      }
    }
    setState(() { _isRecording = true; _error = null; _transcript = ''; _translation = ''; });
    _fadeCtrl.reverse();
    try {
      await _recorder.start();
    } catch (e) {
      setState(() { _isRecording = false; });
      _showError('Could not start recording: $e');
    }
  }

  Future<void> _stopAndTranslate() async {
    setState(() { _isRecording = false; _isProcessing = true; });
    try {
      // Stops the recorder ONCE and returns bytes + filename hint
      final audioData = await _recorder.stopAndGetBytes();
      if (audioData == null || audioData.bytes.isEmpty) {
        throw Exception('No audio recorded — please hold the mic button and speak clearly.');
      }

      final result = await _translationService.translateFromBytes(
        audioBytes: audioData.bytes,
        sourceLang: _sourceLang.code,
        targetLang: _targetLang.code,
        outputMode: _outputMode,
        backendUrl: _backendUrl,
        filename: audioData.filename,
      );

      setState(() {
        _transcript = result.transcript;
        _translation = result.translation;
        _error = null;
      });
      _fadeCtrl.forward();

      await _historyService.insertRecord(TranslationRecord(
        transcript: result.transcript,
        translation: result.translation,
        sourceLang: result.sourceLang,
        targetLang: result.targetLang,
        outputMode: _outputMode == OutputMode.speaker ? 'speaker' : 'text',
        createdAt: DateTime.now(),
      ));

      // Speaker mode: use free client-side TTS (Web Speech API)
      if (_outputMode == OutputMode.speaker && result.translation.isNotEmpty) {
        setState(() => _isSpeaking = true);
        try {
          await _tts.speak(
            result.translation,
            languageCode: TtsService.localeFor(result.targetLang),
          );
        } finally {
          setState(() => _isSpeaking = false);
        }
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isProcessing = false);
    }
  }


  void _showError(String msg) {
    setState(() => _error = msg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: kError, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _swapLanguages() {
    if (_sourceLang.code == 'auto') return;
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    _tts.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildLanguageRow(),
                      const SizedBox(height: 16),
                      _buildOutputModeToggle(),
                      const SizedBox(height: 36),
                      _buildMicButton(),
                      const SizedBox(height: 12),
                      _buildRecordingLabel(),
                      const SizedBox(height: 28),
                      if (_isProcessing) _buildProcessingCard(),
                      if (!_isProcessing && (_transcript.isNotEmpty || _translation.isNotEmpty))
                        _buildResultCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(gradient: kPrimaryGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Voice Translator', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const Spacer(),
          if (_isProcessing)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kPrimaryLight, strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildLanguageRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _langButton(_sourceLang, isSource: true)),
          _swapButton(),
          Expanded(child: _langButton(_targetLang, isSource: false)),
        ],
      ),
    );
  }

  Widget _langButton(Language lang, {required bool isSource}) {
    return GestureDetector(
      onTap: () => _showLanguagePicker(isSource: isSource),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kGlass,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isSource ? 'FROM' : 'TO', style: GoogleFonts.inter(fontSize: 10, color: kTextHint, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(lang.name, style: GoogleFonts.inter(fontSize: 15, color: kTextPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            Text(lang.nativeName, style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _swapButton() {
    return GestureDetector(
      onTap: _swapLanguages,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: _sourceLang.code == 'auto' ? null : kPrimaryGradient,
          color: _sourceLang.code == 'auto' ? kGlass : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.swap_horiz_rounded, color: _sourceLang.code == 'auto' ? kTextHint : Colors.white, size: 20),
      ),
    );
  }

  Widget _buildOutputModeToggle() {
    return Container(
      height: 46,
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGlassBorder)),
      child: Row(
        children: [
          _modeTab(OutputMode.speaker, Icons.volume_up_rounded, 'Speaker'),
          _modeTab(OutputMode.text, Icons.text_fields_rounded, 'Text'),
        ],
      ),
    );
  }

  Widget _modeTab(OutputMode mode, IconData icon, String label) {
    final isActive = _outputMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _outputMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isActive ? kPrimaryGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : kTextHint),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : kTextHint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isRecording) ...[
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => _ring(_ring3.value, kRecording.withOpacity(0.06)),
            ),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => _ring(_ring2.value, kRecording.withOpacity(0.12)),
            ),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => _ring(_ring1.value, kRecording.withOpacity(0.22)),
            ),
          ],
          GestureDetector(
            onTap: _isProcessing ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isRecording ? kRecordingGradient : kPrimaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? kRecording : kPrimary).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(double scale, Color color) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildRecordingLabel() {
    String label;
    if (_isProcessing) label = 'Translating…';
    else if (_isRecording) label = 'Recording… tap to stop';
    else if (_transcript.isNotEmpty) label = 'Tap mic to translate again';
    else label = 'Tap mic to start speaking';
    return Text(label, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary));
  }

  Widget _buildProcessingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGlassBorder)),
      child: Row(
        children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: kPrimaryLight, strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text('Processing your speech…', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGlassBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transcript
            _resultSection(
              icon: Icons.mic_rounded,
              label: '${_sourceLang.name} (You said)',
              text: _transcript,
              iconColor: kAccent,
            ),
            Divider(color: kBorder.withOpacity(0.5), height: 1),
            // Translation
            _resultSection(
              icon: Icons.translate_rounded,
              label: '${_targetLang.name} (Translation)',
              text: _translation,
              iconColor: kPrimaryLight,
              trailing: _outputMode == OutputMode.speaker && _translation.isNotEmpty
                  ? _playButton()
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultSection({
    required IconData icon,
    required String label,
    required String text,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: iconColor, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const Spacer(),
              if (trailing != null) trailing,
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                  );
                },
                child: Icon(Icons.copy_rounded, size: 14, color: kTextHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: GoogleFonts.inter(fontSize: 15, color: kTextPrimary, height: 1.6)),
        ],
      ),
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: () async {
        if (_isSpeaking) {
          await _tts.stop();
          setState(() => _isSpeaking = false);
        } else if (_translation.isNotEmpty) {
          setState(() => _isSpeaking = true);
          try {
            await _tts.speak(
              _translation,
              languageCode: TtsService.localeFor(_targetLang.code),
            );
          } finally {
            setState(() => _isSpeaking = false);
          }
        }
      },
      child: Icon(
        _isSpeaking ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
        size: 18,
        color: kAccent,
      ),
    );
  }

  void _showLanguagePicker({required bool isSource}) {
    final available = isSource ? kLanguages : kLanguages.where((l) => l.code != 'auto').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _LanguagePickerSheet(
        languages: available,
        selected: isSource ? _sourceLang : _targetLang,
        onSelected: (lang) {
          setState(() {
            if (isSource) _sourceLang = lang;
            else _targetLang = lang;
          });
        },
      ),
    );
  }
}

// ── Language Picker Bottom Sheet ──────────────────────────────────────
class _LanguagePickerSheet extends StatefulWidget {
  final List<Language> languages;
  final Language selected;
  final ValueChanged<Language> onSelected;
  const _LanguagePickerSheet({required this.languages, required this.selected, required this.onSelected});

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.languages.where((l) =>
      l.name.toLowerCase().contains(_search.toLowerCase()) ||
      l.nativeName.toLowerCase().contains(_search.toLowerCase()),
    ).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.inter(color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search language…',
                hintStyle: GoogleFonts.inter(color: kTextHint),
                prefixIcon: const Icon(Icons.search_rounded, color: kTextHint),
                filled: true,
                fillColor: kCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final lang = filtered[i];
                final isSelected = lang.code == widget.selected.code;
                return ListTile(
                  title: Text(lang.name, style: GoogleFonts.inter(color: isSelected ? kPrimaryLight : kTextPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: Text(lang.nativeName, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: kPrimaryLight) : null,
                  onTap: () {
                    widget.onSelected(lang);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
