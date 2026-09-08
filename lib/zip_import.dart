import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class CheckedOutput extends OutputFileStream {
  final int expected;
  int crc = 0;
  CheckedOutput(String path, this.expected)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));
  @override
  void writeByte(int value) {
    if (length + 1 > expected) {
      throw const FormatException(
        'ZIP decompressed size exceeds declared size',
      );
    }
    crc = getCrc32([value], crc);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (this.length + count > expected) {
      throw const FormatException(
        'ZIP decompressed size exceeds declared size',
      );
    }
    crc = getCrc32(
      count == bytes.length ? bytes : bytes.sublist(0, count),
      crc,
    );
    super.writeBytes(bytes, length: count);
  }
}

String safeZipPath(String root, String name) {
  final portable = name.replaceAll('\\', '/');
  if (portable.startsWith('/') ||
      portable.contains(':') ||
      portable
          .split('/')
          .any(
            (s) =>
                s == '..' ||
                s.endsWith('.') ||
                s.endsWith(' ') ||
                RegExp(
                  r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)',
                  caseSensitive: false,
                ).hasMatch(s),
          )) {
    throw const FormatException('Unsafe ZIP filename');
  }
  final target = p.normalize(p.join(root, portable));
  if (!p.isWithin(root, target)) {
    throw const FormatException('ZIP path escapes destination');
  }
  return target;
}

// Runs in a worker isolate. Output is a new staging directory only.
String extractZip(String zip, String destination) {
  final root = p.absolute(destination);
  if (FileSystemEntity.typeSync(root, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw const FormatException('Choose a new destination folder');
  }
  Directory(root).createSync();
  final input = InputFileStream(zip);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    final names = <String>{};
    // Check original central directory because decoder merges identical names.
    for (final h in decoder.directory.fileHeaders) {
      final target = safeZipPath(root, h.filename).toLowerCase();
      if (!names.add(target)) {
        throw const FormatException('Duplicate ZIP paths');
      }
    }
    if (archive.length > 200000) {
      throw const FormatException('ZIP exceeds 200,000-file safety limit');
    }
    var total = 0;
    for (final f in archive) {
      safeZipPath(root, f.name);
      if (f.isSymbolicLink) {
        throw const FormatException('ZIP links are not supported');
      }
      total += f.size;
      if (f.size < 0 || total > 100000000000) {
        throw const FormatException('ZIP exceeds 100 GB safety limit');
      }
    }
    for (final f in archive) {
      final out = safeZipPath(root, f.name);
      if (f.isDirectory) {
        Directory(out).createSync(recursive: true);
        continue;
      }
      Directory(p.dirname(out)).createSync(recursive: true);
      final stream = CheckedOutput(out, f.size);
      try {
        f.writeContent(stream);
      } finally {
        stream.closeSync();
      }
      if (File(out).lengthSync() != f.size ||
          (f.crc32 != null && stream.crc != f.crc32)) {
        throw const FormatException('ZIP entry size mismatch');
      }
    }
    return root;
  } catch (_) {
    // root was created exclusively by this operation and contains no user files.
    if (Directory(root).existsSync()) {
      Directory(root).deleteSync(recursive: true);
    }
    rethrow;
  } finally {
    input.closeSync();
  }
}
