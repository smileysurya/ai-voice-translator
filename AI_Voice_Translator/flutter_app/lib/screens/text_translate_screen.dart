import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/translation_record.dart';
import '../services/translation_service.dart';
import '../services/history_service.dart';
import '../services/tts_service.dart';

class TextTranslateScreen extends StatefulWidget {
  const TextTranslateScreen({super.key});
  @override
  State<TextTranslateScreen> createState() => _TextTranslateScreenState();
}

class _TextTranslateScreenState extends State<TextTranslateScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────
  Language _sourceLang = kLanguages.firstWhere((l) => l.code == 'en');
  Language _targetLang = kLanguages.firstWhere((l) => l.code == 'es');
  OutputMode _outputMode = OutputMode.text;
  String _backendUrl = kDefaultBackendUrl;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _translation = '';

  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  // ── Services ───────────────────────────────────────────────────────
  final _translationService = TranslationService();
  final _historyService = HistoryService();
  final _tts = TtsService();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _loadSettings();
    _inputFocus.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backendUrl = prefs.getString('backend_url') ?? kDefaultBackendUrl;
      _outputMode = prefs.getString('output_mode') == 'speaker' ? OutputMode.speaker : OutputMode.text;
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _tts.dispose();
    super.dispose();
  }

  // ── Translate ──────────────────────────────────────────────────────
  Future<void> _translate() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _isProcessing = true; _translation = ''; });
    _fadeCtrl.reverse();
    try {
      final result = await _translationService.translateTextOnly(
        text: text,
        sourceLang: _sourceLang.code,
        targetLang: _targetLang.code,
        backendUrl: _backendUrl,
      );
      setState(() { _translation = result.translation; });
      _fadeCtrl.forward();

      await _historyService.insertRecord(TranslationRecord(
        transcript: result.transcript,
        translation: result.translation,
        sourceLang: result.sourceLang,
        targetLang: result.targetLang,
        outputMode: _outputMode == OutputMode.speaker ? 'speaker' : 'text',
        createdAt: DateTime.now(),
      ));

      if (_outputMode == OutputMode.speaker && result.translation.isNotEmpty) {
        setState(() => _isSpeaking = true);
        try {
          await _tts.speak(result.translation, languageCode: TtsService.localeFor(result.targetLang));
        } finally {
          if (mounted) setState(() => _isSpeaking = false);
        }
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: kError, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
      // Also swap text and translation
      final oldInput = _inputCtrl.text;
      _inputCtrl.text = _translation;
      _translation = oldInput;
    });
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      _buildLanguageRow(),
                      const SizedBox(height: 12),
                      _buildOutputModeToggle(),
                      const SizedBox(height: 20),
                      _buildInputCard(),
                      const SizedBox(height: 12),
                      _buildTranslateButton(),
                      const SizedBox(height: 16),
                      if (_translation.isNotEmpty) _buildResultCard(),
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
            decoration: BoxDecoration(gradient: kAccentGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Text Translate', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const Spacer(),
          if (_isProcessing)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kAccentLight, strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildLanguageRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGlassBorder)),
      child: Row(
        children: [
          Expanded(child: _langButton(_sourceLang, isSource: true)),
          GestureDetector(
            onTap: _swapLanguages,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: kAccentGradient, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
            ),
          ),
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
        decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(10)),
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

  Widget _buildOutputModeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGlassBorder)),
      child: Row(
        children: [
          _modeTab(OutputMode.speaker, Icons.volume_up_rounded, 'Speaker'),
          _modeTab(OutputMode.text, Icons.text_fields_rounded, 'Text Only'),
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
          decoration: BoxDecoration(gradient: isActive ? kPrimaryGradient : null, borderRadius: BorderRadius.circular(9)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? Colors.white : kTextHint),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? Colors.white : kTextHint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _inputFocus.hasFocus ? kAccentLight.withOpacity(0.5) : kGlassBorder, width: _inputFocus.hasFocus ? 1.5 : 1),
      ),
      child: Column(
        children: [
          TextField(
            controller: _inputCtrl,
            focusNode: _inputFocus,
            maxLines: 6,
            minLines: 4,
            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 16, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Type or paste text to translate…',
              hintStyle: GoogleFonts.inter(color: kTextHint, fontSize: 15),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_inputCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_inputCtrl.text.length} chars', style: GoogleFonts.inter(fontSize: 11, color: kTextHint)),
                  GestureDetector(
                    onTap: () => setState(() { _inputCtrl.clear(); _translation = ''; }),
                    child: const Icon(Icons.clear_rounded, size: 18, color: kTextHint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslateButton() {
    final canTranslate = !_isProcessing && _inputCtrl.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: canTranslate ? _translate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: canTranslate ? kAccentGradient : null,
          color: canTranslate ? null : kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: canTranslate ? Colors.transparent : kGlassBorder),
          boxShadow: canTranslate ? [BoxShadow(color: kAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            else
              const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _isProcessing ? 'Translating…' : 'Translate',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: canTranslate ? Colors.white : kTextHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGlassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, size: 15, color: kAccentLight),
                  const SizedBox(width: 6),
                  Text('${_targetLang.name} Translation',
                    style: GoogleFonts.inter(fontSize: 11, color: kAccentLight, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const Spacer(),
                  // Speak button
                  if (_outputMode == OutputMode.speaker)
                    GestureDetector(
                      onTap: () async {
                        if (_isSpeaking) {
                          await _tts.stop();
                          setState(() => _isSpeaking = false);
                        } else {
                          setState(() => _isSpeaking = true);
                          try {
                            await _tts.speak(_translation, languageCode: TtsService.localeFor(_targetLang.code));
                          } finally {
                            if (mounted) setState(() => _isSpeaking = false);
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                          size: 20, color: kAccentLight,
                        ),
                      ),
                    ),
                  // Copy button
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _translation));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Translation copied!'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.copy_rounded, size: 18, color: kTextHint),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Text(_translation, style: GoogleFonts.inter(fontSize: 17, color: kTextPrimary, height: 1.65, fontWeight: FontWeight.w400)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker({required bool isSource}) {
    // Source and target: no 'auto' for text input
    final available = kLanguages.where((l) => l.code != 'auto').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _LanguagePickerSheet(
        languages: available,
        selected: isSource ? _sourceLang : _targetLang,
        onSelected: (lang) => setState(() {
          if (isSource) _sourceLang = lang;
          else _targetLang = lang;
        }),
      ),
    );
  }
}

// ── Shared Language Picker Sheet ──────────────────────────────────────
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
      initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4, expand: false,
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
                hintText: 'Search language…', hintStyle: GoogleFonts.inter(color: kTextHint),
                prefixIcon: const Icon(Icons.search_rounded, color: kTextHint),
                filled: true, fillColor: kCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: ctrl, itemCount: filtered.length,
              itemBuilder: (_, i) {
                final lang = filtered[i];
                final isSelected = lang.code == widget.selected.code;
                return ListTile(
                  title: Text(lang.name, style: GoogleFonts.inter(color: isSelected ? kAccentLight : kTextPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: Text(lang.nativeName, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: kAccentLight) : null,
                  onTap: () { widget.onSelected(lang); Navigator.pop(context); },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
