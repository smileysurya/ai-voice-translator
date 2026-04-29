import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_translator/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AIVoiceTranslatorApp());
    expect(find.byType(AIVoiceTranslatorApp), findsOneWidget);
  });
}
