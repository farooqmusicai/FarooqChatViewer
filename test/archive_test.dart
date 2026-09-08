import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive_io.dart';
import 'package:farooq_chat_viewer/archive.dart';
import 'package:farooq_chat_viewer/zip_import.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('fcv-test-'));
  tearDown(() => temp.deleteSync(recursive: true));
  Future<File> text(String content, [String name = '_chat.txt']) async =>
      File('${temp.path}/$name').writeAsString(content);
  test('iPhone: multiline, RTL, timestamps, system and original body', () async {
    final f = await text(
      '\ufeff[13/06/2026, 14:30:01] Ali: السلام عليكم\nsecond line 😀\n[14/06/2026, 09:20:00] Messages are encrypted\n[14/06/2026, 09:21:00] Sara: \u200fمرحبا',
    );
    final r = await parseTranscript(f.path);
    expect(r.messages.length, 3);
    expect(r.messages.first.text, 'السلام عليكم\nsecond line 😀');
    expect(r.messages.first.time, DateTime(2026, 6, 13, 14, 30, 1));
    expect(r.messages[1].sender, isNull);
    expect(r.messages[2].text, '\u200fمرحبا');
    expect(r.ambiguous, false);
  });
  test('Android: month-first inference, 12h and caption', () async {
    final f = await text(
      '6/25/26, 12:01 AM - Alice: photo.jpg (file attached)\ncaption\n6/25/26, 12:01 PM - Bob: hello',
    );
    final r = await parseTranscript(f.path);
    expect(r.monthFirst, true);
    expect(r.messages.first.time, DateTime(2026, 6, 25, 0, 1));
    expect(r.messages.last.time, DateTime(2026, 6, 25, 12, 1));
    expect(attachmentName(r.messages.first.text), 'photo.jpg');
  });
  test('Ambiguous date is exposed and override works', () async {
    final f = await text('[1/2/2026, 10:00] A: hi');
    expect((await parseTranscript(f.path)).ambiguous, true);
    expect(
      (await parseTranscript(f.path, monthFirst: true)).messages.first.time,
      DateTime(2026, 1, 2, 10),
    );
  });
  test('Malformed lines retained, invalid dates never normalized', () async {
    final f = await text(
      'unrecognized preamble\n[31/02/2026, 10:00] A: invalid\n[13/03/2026, 10:00] A: good',
    );
    final r = await parseTranscript(f.path);
    expect(r.warnings, 2);
    expect(r.messages[1].text, contains('invalid'));
    expect(r.messages[1].time, isNull);
  });
  test(
    'folder bytes and dates do not use modification time; ZIP excluded',
    () async {
      final f = await text('[13/01/2020, 10:00] A: old');
      File('${temp.path}/photo.jpg').writeAsBytesSync(List.filled(120, 0));
      File('${temp.path}/retained.zip').writeAsBytesSync(List.filled(200, 0));
      final before = await f.readAsBytes();
      final r = await scanLibrary(temp.path);
      expect(r.length, 1);
      expect(r.first.bytes, before.length + 120);
      expect(r.first.latest, DateTime(2020, 1, 13, 10));
      expect(await f.readAsBytes(), before);
    },
  );
  test('multiple independent transcripts remain separate', () async {
    await text('[13/01/2020, 10:00] A: one');
    await text('[13/02/2020, 10:00] B: two', 'WhatsApp.txt');
    expect((await scanLibrary(temp.path)).length, 2);
  });
  test('attachment matching rejects traversal and ambiguous basenames', () {
    final root = temp.path;
    final index = {
      'x.jpg': ['$root/a/x.jpg', '$root/b/x.jpg'],
    };
    expect(resolveAttachment(root, 'x.jpg', index), isNull);
    expect(resolveAttachment(root, '../x.jpg', index), isNull);
    expect(resolveAttachment(root, 'C:/x.jpg', index), isNull);
  });
  test(
    'ZIP safe paths reject Windows special names, absolute and parent paths',
    () {
      for (final name in [
        '../x',
        '/x',
        'C:/x',
        'a/../../x',
        'a/CON.txt',
        'x:stream',
        'a./x',
      ]) {
        expect(
          () => safeZipPath(temp.path, name),
          throwsFormatException,
          reason: name,
        );
      }
    },
  );
  test(
    'ZIP import preserves input and refuses existing destinations',
    () async {
      final a = Archive()
        ..addFile(ArchiveFile.string('_chat.txt', '[13/01/2026, 10:00] A: hi'));
      final bytes = ZipEncoder().encode(a);
      final zip = File('${temp.path}/input.zip')..writeAsBytesSync(bytes);
      final out = extractZip(zip.path, '${temp.path}/new');
      expect(File('$out/_chat.txt').existsSync(), true);
      expect(zip.readAsBytesSync(), bytes);
      expect(() => extractZip(zip.path, out), throwsFormatException);
    },
  );
  test('malicious ZIP is rejected and staging removed', () {
    final a = Archive()..addFile(ArchiveFile.string('../escaped.txt', 'bad'));
    final zip = File('${temp.path}/bad.zip')
      ..writeAsBytesSync(ZipEncoder().encode(a));
    expect(
      () => extractZip(zip.path, '${temp.path}/new'),
      throwsFormatException,
    );
    expect(Directory('${temp.path}/new').existsSync(), false);
    expect(File('${temp.path}/escaped.txt').existsSync(), false);
  });
}
