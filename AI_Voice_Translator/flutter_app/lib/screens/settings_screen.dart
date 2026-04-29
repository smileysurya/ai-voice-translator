import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/translation_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _translationService = TranslationService();
  final _urlCtrl = TextEditingController();
  Language _sourceLang = kLanguages[0];
  Language _targetLang = kLanguages.firstWhere((l) => l.code == 'en');
  OutputMode _outputMode = OutputMode.text;
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _translationService.loadSettings();
    setState(() {
      _urlCtrl.text = s.backendUrl;
      _outputMode = s.outputMode;
      _sourceLang = kLanguages.firstWhere((l) => l.code == s.sourceLang, orElse: () => kLanguages[0]);
      _targetLang = kLanguages.firstWhere((l) => l.code == s.targetLang, orElse: () => kLanguages[1]);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _translationService.saveSettings(TranslationSettings(
      backendUrl: _urlCtrl.text.trim(),
      sourceLang: _sourceLang.code,
      targetLang: _targetLang.code,
      outputMode: _outputMode,
    ));
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimaryLight))
              : Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _sectionTitle('Backend'),
                          _card([
                            _textField('Backend URL', _urlCtrl, kDefaultBackendUrl, Icons.link_rounded),
                          ]),
                          const SizedBox(height: 20),
                          _sectionTitle('Default Languages'),
                          _card([
                            _langRow('Default Source', _sourceLang, true),
                            _divider(),
                            _langRow('Default Target', _targetLang, false),
                          ]),
                          const SizedBox(height: 20),
                          _sectionTitle('Output'),
                          _card([
                            _outputModeRow(),
                          ]),
                          const SizedBox(height: 20),
                          _sectionTitle('Info'),
                          _card([
                            _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
                            _divider(),
                            _infoRow(Icons.psychology_rounded, 'STT Engine', 'OpenAI Whisper'),
                            _divider(),
                            _infoRow(Icons.translate_rounded, 'Translation', 'GPT-4o-mini'),
                            _divider(),
                            _infoRow(Icons.volume_up_rounded, 'TTS Engine', 'OpenAI Nova'),
                          ]),
                          const SizedBox(height: 24),
                          _buildSignOutButton(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    _buildSaveButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text('Settings', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, color: kTextHint, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kGlassBorder)),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, color: kBorder.withOpacity(0.4), indent: 16);

  Widget _textField(String label, TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: kTextHint, fontSize: 14),
              prefixIcon: Icon(icon, color: kTextHint, size: 18),
              filled: true,
              fillColor: kGlass,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langRow(String label, Language lang, bool isSource) {
    return ListTile(
      title: Text(label, style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang.name, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: kTextHint, size: 18),
        ],
      ),
      onTap: () => _showLangPicker(isSource),
    );
  }

  Widget _outputModeRow() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.speaker_rounded, color: kTextSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text('Default Output Mode', style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary))),
          _modeChip(OutputMode.text, 'Text'),
          const SizedBox(width: 6),
          _modeChip(OutputMode.speaker, 'Speaker'),
        ],
      ),
    );
  }

  Widget _modeChip(OutputMode mode, String label) {
    final active = _outputMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _outputMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? kPrimaryGradient : null,
          color: active ? null : kGlass,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: active ? Colors.white : kTextSecondary, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: kTextHint, size: 18),
      title: Text(label, style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary)),
      trailing: Text(value, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _saved ? kAccentGradient : kPrimaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(_saved ? 'Saved!' : 'Save Settings', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLangPicker(bool isSource) {
    final langs = isSource ? kLanguages : kLanguages.where((l) => l.code != 'auto').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => ListView.builder(
          controller: ctrl,
          itemCount: langs.length,
          itemBuilder: (_, i) {
            final lang = langs[i];
            final sel = isSource ? _sourceLang : _targetLang;
            return ListTile(
              title: Text(lang.name, style: GoogleFonts.inter(color: lang.code == sel.code ? kPrimaryLight : kTextPrimary)),
              subtitle: Text(lang.nativeName, style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
              trailing: lang.code == sel.code ? const Icon(Icons.check_rounded, color: kPrimaryLight) : null,
              onTap: () {
                setState(() { if (isSource) _sourceLang = lang; else _targetLang = lang; });
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Container(
      decoration: BoxDecoration(
        color: kError.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kError.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => AuthService().signOut(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: kError, size: 20),
                const SizedBox(width: 8),
                Text('Sign Out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: kError)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
