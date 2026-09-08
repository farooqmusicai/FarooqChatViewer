import 'dart:io';

class ChatArchive {
  const ChatArchive({
    required this.name,
    required this.directory,
    required this.chatTextFile,
    required this.sizeBytes,
    required this.lastModified,
    this.lastMessagePreview = '',
  });

  final String name;
  final Directory directory;
  final File chatTextFile;
  final int sizeBytes;
  final DateTime lastModified;
  final String lastMessagePreview;

  String get displaySize => formatBytes(sizeBytes);

  ChatArchive copyWith({String? lastMessagePreview}) => ChatArchive(
    name: name,
    directory: directory,
    chatTextFile: chatTextFile,
    sizeBytes: sizeBytes,
    lastModified: lastModified,
    lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
  );

  static String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0
        ? 0
        : value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}
