import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/chat_archive.dart';

class ArchiveScanner {
  const ArchiveScanner();

  Future<List<ChatArchive>> scanConversationsFolder(Directory root) async {
    final results = <ChatArchive>[];

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final archive = await scanChatFolder(entity);
      if (archive != null) results.add(archive);
    }

    results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return results;
  }

  Future<ChatArchive?> scanChatFolder(Directory folder) async {
    File? chatText;
    int totalBytes = 0;
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);

    await for (final entity in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      try {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
          if (stat.modified.isAfter(latest)) latest = stat.modified;
          if (p.basename(entity.path).toLowerCase() == '_chat.txt') {
            chatText = entity;
          }
        }
      } on FileSystemException {
        // Skip files that disappear or become unavailable during a scan.
      }
    }

    if (chatText == null) return null;

    final preview = await _readLastUsefulLine(chatText);
    final rawName = p.basename(folder.path);
    final name = rawName.replaceFirst(
      RegExp(r'^WhatsApp Chat\s*-\s*', caseSensitive: false),
      '',
    );

    return ChatArchive(
      name: name.trim().isEmpty ? rawName : name.trim(),
      directory: folder,
      chatTextFile: chatText,
      sizeBytes: totalBytes,
      lastModified: latest,
      lastMessagePreview: preview,
    );
  }

  Future<String> _readLastUsefulLine(File file) async {
    try {
      final lines = await file.readAsLines();
      for (var i = lines.length - 1; i >= 0; i--) {
        final value = lines[i].trim();
        if (value.isEmpty) continue;
        final normalized = value.replaceFirst(
          RegExp(
            r'^\[?\d{1,2}[\/.\-]\d{1,2}[\/.\-]\d{2,4}[^\]]*\]?\s*[-–]?\s*',
          ),
          '',
        );
        return normalized.length > 90
            ? '${normalized.substring(0, 90)}…'
            : normalized;
      }
    } catch (_) {}
    return '';
  }
}
