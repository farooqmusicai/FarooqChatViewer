import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farooq_chat_viewer/main.dart';
import 'package:farooq_chat_viewer/archive.dart';

void main() {
  test('known WhatsApp notices are classified without matching ordinary discussion', () {
    expect(isWhatsAppNotice('\u200eYour security code with Alex changed.'), isTrue);
    expect(isWhatsAppNotice('Messages and calls are end-to-end encrypted. Only people in this chat can read, listen to, or share them. Click to learn more'), isTrue);
    expect(isWhatsAppNotice("Rashid uses a default timer for disappearing messages in new chats. New messages will disappear from this chat 90 days after they're sent, except when kept. Click to set your own default timer."), isTrue);
    expect(isWhatsAppNotice('You turned on disappearing messages. New messages will disappear after 24 hours.'), isTrue);
    expect(isWhatsAppNotice('I noticed your security code with Alex changed.'), isFalse);
    expect(isWhatsAppNotice('Can you turn on disappearing messages?'), isFalse);
  });
  test('system notices do not replace the last message, count, or search content', () async {
    final temp = Directory.systemTemp.createTempSync('fcv-system-');
    addTearDown(() => temp.deleteSync(recursive:true));
    File('${temp.path}/_chat.txt').writeAsStringSync('[13/06/2026, 09:00] Alice: User message\n[14/06/2026, 09:00] Alice: Your security code with Alice changed.\n');
    final chats = await scanLibrary(temp.path);
    expect(chats.single.count, 1);
    expect(chats.single.latest, DateTime(2026,6,13,9));
    expect(chats.single.preview, 'User message');
    expect(chatMatches(chats.single, 'user   message'), isTrue);
    expect(chatMatches(chats.single, 'security code'), isFalse);
    final parsed = await parseTranscript('${temp.path}/_chat.txt');
    expect(parsed.messages.length,2);
    expect(latestUserMessageIndex(parsed.messages),0);
  });
  testWidgets('startup restores folder, left search finds older content, disconnect persists', (tester) async {
    final temp = Directory.systemTemp.createTempSync('fcv-connect-');
    final alice = Directory('${temp.path}/Alice')..createSync();
    final bob = Directory('${temp.path}/Bob')..createSync();
    File('${alice.path}/_chat.txt').writeAsStringSync('[13/06/2026, 09:00] Alice: Secret older phrase\n[13/06/2026, 10:00] Alice: Latest hello\n[14/06/2026, 09:00] Alice: Your security code with Alice changed.\n');
    File('${bob.path}/_chat.txt').writeAsStringSync('[13/06/2026, 09:00] Bob: Unrelated text\n');
    SharedPreferences.setMockInitialValues({'library':temp.path});
    tester.view.physicalSize = const Size(1280,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ViewerApp());
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds:2)));await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);expect(find.text('Bob'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField,'Search conversations'), '  SECRET   older phrase  ');await tester.pumpAndSettle();
    expect(find.text('Alice'),findsOneWidget);expect(find.text('Bob'),findsNothing);
    await tester.tap(find.text('Alice'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds:2)));await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile,'Secret older phrase'), findsOneWidget);
    expect(find.text('WhatsApp system notice'),findsOneWidget);
    expect(find.textContaining('2 messages'), findsOneWidget);
    await tester.tap(find.byTooltip('Disconnect folder'));await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('library'), isNull);
    await tester.pumpWidget(const SizedBox());await tester.pumpWidget(const ViewerApp());
    await tester.pumpAndSettle();
    expect(find.text('Alice'),findsNothing);expect(find.byTooltip('Disconnect folder'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());temp.deleteSync(recursive:true);
  });
}
