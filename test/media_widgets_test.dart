import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farooq_chat_viewer/media_widgets.dart';

void main() {
  test('attachment markers disappear without losing captions or original source', () {
    const source = '\u200e<attached: photo.jpg>\nصبح بخیر';
    expect(mediaCaption(source, 'photo.jpg'), 'صبح بخیر');
    expect(source, contains('<attached:'));
    expect(mediaCaption('voice.opus (file attached)', 'voice.opus'), '');
    expect(mediaCaption('hello', null), 'hello');
  });
  testWidgets('voice and video cards stay compact and have real duration labels', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('farooq/media'), (call) async => {'durationMs': 12000});
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('farooq/media'), null));
    var plays = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, child: Column(children: [
      VoiceNote(path: 'fixture-audio.wav', sender: 'Ali', onPlay: () => plays++),
      VideoCard(path: 'fixture-video.mp4', onPlay: () => plays++),
    ])))));
    await tester.pumpAndSettle();
    expect(find.text('0:12'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Play / pause'));
    expect(plays, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('link cards do not request the network until asked', (tester) async {
    final server = await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    var requests = 0;
    server!.listen((r) { requests++; r.response.close(); });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, child: LinkCard(uri: Uri.parse('http://127.0.0.1:${server.port}/private-link'), onOpen: () {})))));
    await tester.pumpAndSettle();
    expect(find.text('Load online preview'), findsOneWidget);
    expect(requests, 0);
    await tester.runAsync(() => server.close(force: true));
  });
}
