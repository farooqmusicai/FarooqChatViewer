import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:farooq_chat_viewer/media_widgets.dart';
import 'package:farooq_chat_viewer/archive.dart';

class PlaybackStreams implements PlayerStream {
  final updates = StreamController<bool>.broadcast();
  @override
  Stream<bool> get playing => updates.stream;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PlaybackFixture implements Player {
  final events = PlaybackStreams();
  bool active = true;
  @override
  PlayerState get state =>
      PlayerState(playing: active, duration: const Duration(seconds: 45));
  @override
  PlayerStream get stream => events;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('initials use separate name words across scripts', () {
    expect(nameInitials('Alex Morgan'), 'AM');
    expect(nameInitials('M Smith'), 'MS');
    expect(nameInitials(' LT - Jassim Al kaabi '), 'LJ');
    expect(nameInitials('محمد فاروق'), 'مف');
    expect(nameInitials('Bilal'), 'B');
    expect(nameInitials(''), '?');
  });
  testWidgets('sticker preview replaces export filename with icon and label', (
    tester,
  ) async {
    final chat = Chat(
      'x',
      'C:/missing-test-folder',
      'Chat',
      0,
      1,
      null,
      '<attached: 0002-STICKER.webp>',
      false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LastMessagePreview(chat: chat)),
      ),
    );
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    expect(find.textContaining('<attached:'), findsNothing);
  });
  testWidgets('voice control changes on initial attachment, pause and resume', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('farooq/media'),
      (_) async => {'durationMs': 45000},
    );
    final player = PlaybackFixture();
    Widget view(Player? value) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 350,
          child: VoiceNote(
            path: 'toggle-fixture.opus',
            sender: 'M Smith',
            player: value,
            onPlay: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(null));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    await tester.pumpWidget(view(player));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    player.active = false;
    player.events.updates.add(false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    player.active = true;
    player.events.updates.add(true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await player.events.updates.close();
  });
}
