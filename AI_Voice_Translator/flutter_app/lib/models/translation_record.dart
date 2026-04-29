class TranslationRecord {
  final int? id;
  final String transcript;
  final String translation;
  final String sourceLang;
  final String targetLang;
  final String outputMode;
  final DateTime createdAt;
  final bool synced;

  TranslationRecord({
    this.id,
    required this.transcript,
    required this.translation,
    required this.sourceLang,
    required this.targetLang,
    required this.outputMode,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'transcript': transcript,
        'translation': translation,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'output_mode': outputMode,
        'created_at': createdAt.toIso8601String(),
        'synced': synced ? 1 : 0,
      };

  static TranslationRecord fromMap(Map<String, dynamic> m) => TranslationRecord(
        id: m['id'] as int?,
        transcript: m['transcript'] as String,
        translation: m['translation'] as String,
        sourceLang: m['source_lang'] as String,
        targetLang: m['target_lang'] as String,
        outputMode: m['output_mode'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        synced: m['synced'] == 1,
      );
}
