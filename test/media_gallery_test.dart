import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:farooq_chat_viewer/main.dart';

void main() {
  testWidgets('media timeline renders captions, cards and actions together', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final loader = FontLoader('Segoe UI');
      loader.addFont(File('C:/Windows/Fonts/segoeui.ttf').readAsBytes().then((b) => ByteData.sublistView(b)));
      if (await File('C:/Windows/Fonts/segoeui.ttf').exists()) await loader.load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('farooq/media'), (call) async => {'durationMs': 4000});
    final key = GlobalKey();
    final path = Directory('test/fixtures/WhatsApp Chat - Media examples').absolute.path;
    await tester.pumpWidget(RepaintBoundary(key:key, child:ViewerApp(initialPath: path)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(ViewerApp));
      await precacheImage(ResizeImage(FileImage(File('$path${Platform.pathSeparator}photo.png')), width: 720), context);
      await precacheImage(ResizeImage(FileImage(File('$path${Platform.pathSeparator}STICKER.png')), width: 450), context);
    });
    await tester.tap(find.text('Media examples'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(find.text('<attached: voice.opus>'), findsNothing);
    expect(tester.widgetList<RawImage>(find.byType(RawImage)).where((image) => image.image != null).length, 2);
    expect(find.text('Load online preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/evidence').createSync(recursive:true);
      File('build/evidence/media-layout.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}


