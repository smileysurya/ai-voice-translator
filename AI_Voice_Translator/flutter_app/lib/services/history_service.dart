import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/translation_record.dart';
import '../constants.dart';

class HistoryService {
  static Database? _db;
  // In-memory fallback for web
  static final List<TranslationRecord> _webRecords = [];
  static int _webIdCounter = 1;

  bool get _useInMemory => kIsWeb;

  Future<Database?> get _database async {
    if (_useInMemory) return null;
    _db ??= await _initDb();
    return _db;
  }

  Future<Database> _initDb() async {
    String path;
    if (kIsWeb) {
      path = 'ai_voice_translator.db'; // Not really used for web FFI but for consistency
    } else {
      final directory = await getApplicationDocumentsDirectory();
      // Ensure directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      path = join(directory.path, 'ai_voice_translator.db');
    }
    
    return openDatabase(
      path,
      version: 2, // Upgraded version for synced column
      onCreate: (db, version) => db.execute('''
        CREATE TABLE translations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transcript TEXT NOT NULL,
          translation TEXT NOT NULL,
          source_lang TEXT NOT NULL,
          target_lang TEXT NOT NULL,
          output_mode TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute('ALTER TABLE translations ADD COLUMN synced INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future<int> insertRecord(TranslationRecord record) async {
    if (_useInMemory) {
      final r = TranslationRecord(
        id: _webIdCounter++,
        transcript: record.transcript,
        translation: record.translation,
        sourceLang: record.sourceLang,
        targetLang: record.targetLang,
        outputMode: record.outputMode,
        createdAt: record.createdAt,
      );
      _webRecords.insert(0, r);
      return r.id!;
    }
    final database = await _database;
    final map = record.toMap()..remove('id');
    return database!.insert('translations', map);
  }

  Future<List<TranslationRecord>> getAllRecords({int limit = 100}) async {
    if (_useInMemory) {
      return _webRecords.take(limit).toList();
    }
    final database = await _database;
    final maps = await database!.query(
      'translations',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map(TranslationRecord.fromMap).toList();
  }

  Future<void> deleteRecord(int id) async {
    if (_useInMemory) {
      _webRecords.removeWhere((r) => r.id == id);
      return;
    }
    final database = await _database;
    await database!.delete('translations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    if (_useInMemory) {
      _webRecords.clear();
      return;
    }
    final database = await _database;
    await database!.delete('translations');
  }

  Future<int> getCount() async {
    if (_useInMemory) return _webRecords.length;
    final database = await _database;
    final res = await database!.rawQuery('SELECT COUNT(*) FROM translations');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Sync unsynced records to MongoDB Atlas
  Future<void> syncWithCloud(String userId, String backendUrl) async {
    if (kIsWeb) return; // For now, sync is focused on native offline fallback
    
    final database = await _database;
    final List<Map<String, dynamic>> unsynced = await database!.query(
      'translations',
      where: 'synced = ?',
      whereArgs: [0],
    );

    if (unsynced.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/sync/history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'records': unsynced.map((m) => {
            'transcript': m['transcript'],
            'translation': m['translation'],
            'sourceLang': m['source_lang'],
            'targetLang': m['target_lang'],
            'mode': 'voice',
            'timestamp': m['created_at'],
          }).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Mark as synced locally
          final ids = unsynced.map((m) => m['id']).toList();
          await database.update(
            'translations',
            {'synced': 1},
            where: 'id IN (${ids.join(',')})',
          );
          print('☁️ Synced ${ids.length} records to cloud');
        }
      }
    } catch (e) {
      print('⚠️ Cloud sync failed: $e');
    }
  }
}
