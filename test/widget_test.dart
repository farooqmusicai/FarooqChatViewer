import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farooq_chat_viewer/main.dart';

void main() {
  testWidgets('welcome has working intake and help controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ViewerApp());
    await tester.pumpAndSettle();
    expect(find.text('Your conversations. Always yours.'), findsOneWidget);
    expect(find.text('Open conversations folder'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    expect(find.text('Help & privacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
