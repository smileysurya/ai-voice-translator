import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/translation_record.dart';
import '../services/history_service.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _historyService = HistoryService();
  List<TranslationRecord> _records = [];
  bool _loading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    _records = await _historyService.getAllRecords();
    setState(() => _loading = false);
  }

  Future<void> _delete(TranslationRecord r) async {
    await _historyService.deleteRecord(r.id!);
    _loadHistory();
  }

  Future<void> _syncNow() async {
    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to sync with cloud')));
      return;
    }

    setState(() => _isSyncing = true);
    final prefs = await SharedPreferences.getInstance();
    final backendUrl = prefs.getString('backend_url') ?? kDefaultBackendUrl;
    
    await _historyService.syncWithCloud(user.uid, backendUrl);
    
    setState(() => _isSyncing = false);
    _loadHistory();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed!')));
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        title: Text('Clear History', style: GoogleFonts.inter(color: kTextPrimary, fontWeight: FontWeight.w600)),
        content: Text('Delete all ${_records.length} records?', style: GoogleFonts.inter(color: kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete All', style: TextStyle(color: kError))),
        ],
      ),
    );
    if (ok == true) {
      await _historyService.clearAll();
      _loadHistory();
    }
  }

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
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryLight))
                    : _records.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            color: kPrimaryLight,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _records.length,
                              itemBuilder: (_, i) => _buildCard(_records[i]),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Text('History', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('${_records.length}', style: GoogleFonts.inter(fontSize: 12, color: kPrimaryLight, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          if (_records.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: kTextSecondary), onPressed: _clearAll, tooltip: 'Clear All'),
          
          if (_isSyncing)
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryLight)))
          else
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined, color: kPrimaryLight), 
              onPressed: _syncNow, 
              tooltip: 'Sync Now'
            ),
            
          IconButton(icon: const Icon(Icons.refresh_rounded, color: kTextSecondary), onPressed: _loadHistory, tooltip: 'Refresh'),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: kTextHint.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('No translations yet', style: GoogleFonts.inter(fontSize: 18, color: kTextSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Your translations will appear here', style: GoogleFonts.inter(fontSize: 13, color: kTextHint)),
        ],
      ),
    );
  }

  Widget _buildCard(TranslationRecord r) {
    final langFrom = kLanguages.firstWhere((l) => l.code == r.sourceLang, orElse: () => Language(code: r.sourceLang, name: r.sourceLang, nativeName: r.sourceLang));
    final langTo = kLanguages.firstWhere((l) => l.code == r.targetLang, orElse: () => Language(code: r.targetLang, name: r.targetLang, nativeName: r.targetLang));
    final dateStr = DateFormat('MMM d, HH:mm').format(r.createdAt.toLocal());

    return Dismissible(
      key: Key('${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: kError.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: kError),
      ),
      onDismissed: (_) => _delete(r),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kGlassBorder)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(r.transcript, style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _langChip(langFrom.name),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: kTextHint),
                  _langChip(langTo.name),
                  const Spacer(),
                  Icon(r.outputMode == 'speaker' ? Icons.volume_up_rounded : Icons.text_fields_rounded, size: 12, color: kTextHint),
                  const SizedBox(width: 4),
                  Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: kTextHint)),
                  const SizedBox(width: 8),
                  Icon(
                    r.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, 
                    size: 14, 
                    color: r.synced ? kPrimaryLight : kTextHint.withOpacity(0.5)
                  ),
                ],
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.translate_rounded, size: 13, color: kPrimaryLight), const SizedBox(width: 4), Text('Translation', style: GoogleFonts.inter(fontSize: 11, color: kPrimaryLight, fontWeight: FontWeight.w600))]),
                    const SizedBox(height: 6),
                    Text(r.translation, style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(String name) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(6)),
      child: Text(name, style: GoogleFonts.inter(fontSize: 10, color: kTextSecondary)),
    );
  }
}
