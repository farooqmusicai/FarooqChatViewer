import 'dart:io';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farooq_chat_viewer/main.dart';

void main() {
  testWidgets(
    'real background parser opens selected chat and searches in narrow RTL layout',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shares = <MethodCall>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shares.add(call);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final temp = Directory.systemTemp.createTempSync('fcv-ui-');
      final chat = Directory('${temp.path}/WhatsApp Chat - Synthetic chat')
        ..createSync();
      File('${chat.path}/_chat.txt').writeAsStringSync(
        '[13/06/2026, 09:00] Ali: hello synthetic\n[13/06/2026, 09:01] Sara: مرحبا بكم',
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ViewerApp(initialPath: temp.path),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Synthetic chat'), findsOneWidget);
      await tester.tap(find.text('Synthetic chat'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ScrollablePositionedList>(
              find.byType(ScrollablePositionedList),
            )
            .initialScrollIndex,
        1,
      );
      expect(find.byTooltip('Share / Forward…'), findsWidgets);
      expect(find.text('مرحبا بكم'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Share / Forward…').last);
      await tester.pumpAndSettle();
      expect(shares, hasLength(1));
      expect(shares.single.arguments['title'], 'Synthetic chat');
      expect(shares.single.arguments['text'], 'مرحبا بكم');
      await tester.enterText(
        find.widgetWithText(TextField, 'Search messages'),
        'synthetic',
      );
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'hello synthetic'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Search messages'), 'no-such-message');
      await tester.pumpAndSettle();
      expect(find.text('No results'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Search messages'), 'synthetic');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اردو · partial'));
      await tester.pumpAndSettle();
      expect(find.text('فاروق چیٹ ویور'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/evidence').createSync(recursive: true);
        File(
          'build/evidence/rtl-widget-render.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      temp.deleteSync(recursive: true);
    },
  );
}
