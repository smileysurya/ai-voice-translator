import 'package:flutter/material.dart';
import 'dart:ui';

// ── Colors ───────────────────────────────────────────────────────────
const Color kBackground = Color(0xFF0A0E1A);
const Color kSurface = Color(0xFF141824);
const Color kCard = Color(0xFF1A2035);
const Color kPrimary = Color(0xFF7C3AED);
const Color kPrimaryLight = Color(0xFF9D5BFF);
const Color kAccent = Color(0xFF10B981);
const Color kAccentLight = Color(0xFF34D399);
const Color kError = Color(0xFFEF4444);
const Color kRecording = Color(0xFFEF4444);
const Color kTextPrimary = Color(0xFFF9FAFB);
const Color kTextSecondary = Color(0xFF9CA3AF);
const Color kTextHint = Color(0xFF6B7280);
const Color kBorder = Color(0xFF2D3748);
const Color kGlass = Color(0x14FFFFFF);
const Color kGlassBorder = Color(0x20FFFFFF);

// ── Gradients ────────────────────────────────────────────────────────
const LinearGradient kBgGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0A0E1A), Color(0xFF0F1629)],
);
const LinearGradient kPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7C3AED), Color(0xFF9D5BFF)],
);
final LinearGradient kRecordingGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEF4444), Color(0xFFFF6B6B)],
);
const LinearGradient kAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF059669), Color(0xFF10B981)],
);

// ── Language Model ───────────────────────────────────────────────────
class Language {
  final String code;
  final String name;
  final String nativeName;
  const Language({required this.code, required this.name, required this.nativeName});
}

// ── Output Mode ──────────────────────────────────────────────────────
enum OutputMode { speaker, text }

// ── Input Mode ───────────────────────────────────────────────────────
enum InputMode { voice, type }

// ── Languages List ───────────────────────────────────────────────────
const List<Language> kLanguages = [
  Language(code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect'),
  Language(code: 'en', name: 'English', nativeName: 'English'),
  Language(code: 'es', name: 'Spanish', nativeName: 'Español'),
  Language(code: 'fr', name: 'French', nativeName: 'Français'),
  Language(code: 'de', name: 'German', nativeName: 'Deutsch'),
  Language(code: 'it', name: 'Italian', nativeName: 'Italiano'),
  Language(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
  Language(code: 'ru', name: 'Russian', nativeName: 'Русский'),
  Language(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  Language(code: 'ko', name: 'Korean', nativeName: '한국어'),
  Language(code: 'zh', name: 'Chinese', nativeName: '中文'),
  Language(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
  Language(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  Language(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
  Language(code: 'pl', name: 'Polish', nativeName: 'Polski'),
  Language(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
  Language(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
  Language(code: 'da', name: 'Danish', nativeName: 'Dansk'),
  Language(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
  Language(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
  Language(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
  Language(code: 'ro', name: 'Romanian', nativeName: 'Română'),
  Language(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
  Language(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
  Language(code: 'he', name: 'Hebrew', nativeName: 'עברית'),
  Language(code: 'th', name: 'Thai', nativeName: 'ภาษาไทย'),
  Language(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
  Language(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
  Language(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
  Language(code: 'fa', name: 'Persian', nativeName: 'فارسی'),
  Language(code: 'ur', name: 'Urdu', nativeName: 'اردو'),
  Language(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
  Language(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  Language(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  Language(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  Language(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  Language(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  Language(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  Language(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  Language(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
  Language(code: 'ne', name: 'Nepali', nativeName: 'नेपाली'),
  Language(code: 'si', name: 'Sinhala', nativeName: 'සිංහල'),
  Language(code: 'my', name: 'Burmese', nativeName: 'မြန်မာ'),
  Language(code: 'km', name: 'Khmer', nativeName: 'ខ្មែរ'),
  Language(code: 'ka', name: 'Georgian', nativeName: 'ქართული'),
  Language(code: 'am', name: 'Amharic', nativeName: 'አማርኛ'),
];

// ── Backend Configuration ──────────────────────────────────────────
const String kDefaultBackendUrl = 'http://192.168.1.2:3000';
