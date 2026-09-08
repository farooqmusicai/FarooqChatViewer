import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class Message {
  final DateTime? time;
  final String? sender;
  String text;
  final int line;
  Message(this.time, this.sender, this.text, this.line);
  bool get isSystem => sender == null || isWhatsAppNotice(text);
}

class Transcript {
  final List<Message> messages;
  final bool ambiguous;
  final int warnings;
  final bool monthFirst;
  Transcript(this.messages, this.ambiguous, this.warnings, this.monthFirst);
}

final record = RegExp(
  r'^\[?(\d{1,4})[/\.\-](\d{1,2})[/\.\-](\d{1,4}),?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm])?\]?\s*(?:-\s*)?(.*)$',
);
String normalized(String s) => s
    .replaceAll(RegExp('[\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]'), '')
    .replaceAll('\u202f', ' ')
    .replaceAll('\u00a0', ' ');
String searchKey(String text) =>
    normalized(text).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

bool isWhatsAppNotice(String text) {
  final value = searchKey(text);
  return RegExp(
        r'^your security code with .+ changed[.!]?(?: (?:tap|click) .*)?$',
      ).hasMatch(value) ||
      RegExp(
        r'^(?:messages and calls|messages) (?:are|in this chat are) end-to-end encrypted[.\s]',
      ).hasMatch(value) ||
      RegExp(
        r'^.+ uses a default timer for disappearing messages in new chats\.',
      ).hasMatch(value) ||
      RegExp(
        r'^(?:you|.+) (?:turned on|turned off|enabled|disabled|updated the message timer for|changed the message timer for) disappearing messages[.\s]',
      ).hasMatch(value) ||
      RegExp(r'^you updated the message timer\.').hasMatch(value);
}

String searchableTranscript(Transcript transcript) => searchKey(
  transcript.messages
      .where((m) => !m.isSystem)
      .map((m) => '${m.sender ?? ''} ${m.text}')
      .join('\u0000'),
);

DateTime? dateOf(RegExpMatch m, bool monthFirst) {
  final a = int.parse(m[1]!), b = int.parse(m[2]!), c = int.parse(m[3]!);
  final year = m[1]!.length == 4 ? a : (c < 100 ? 2000 + c : c);
  final month = m[1]!.length == 4 ? b : (monthFirst ? a : b);
  final day = m[1]!.length == 4 ? c : (monthFirst ? b : a);
  var hour = int.parse(m[4]!);
  final minute = int.parse(m[5]!), second = int.parse(m[6] ?? '0');
  final period = m[7]?.toLowerCase();
  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (period == 'pm' ? 12 : 0);
  }
  if (hour > 23 || minute > 59 || second > 59) return null;
  final d = DateTime(year, month, day, hour, minute, second);
  return d.year == year && d.month == month && d.day == day ? d : null;
}

Future<Transcript> parseTranscript(String path, {bool? monthFirst}) async {
  // Two streaming passes infer date order without retaining raw file copies.
  bool? inferred;
  bool conflicting = false;
  await for (final line in File(
    path,
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    final m = record.firstMatch(normalized(line));
    if (m == null || m[1]!.length == 4) continue;
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    final evidence = a > 12 ? false : (b > 12 ? true : null);
    if (evidence != null) {
      if (inferred != null && inferred != evidence) conflicting = true;
      inferred = evidence;
    }
  }
  final order = monthFirst ?? inferred ?? false;
  final result = <Message>[];
  var warnings = 0, number = 0;
  await for (final raw in File(
    path,
  ).openRead().transform(utf8.decoder).transform(const LineSplitter())) {
    number++;
    final token = normalized(raw);
    final m = record.firstMatch(token);
    final time = m == null ? null : dateOf(m, order);
    if (m == null || time == null) {
      if (m != null || result.isEmpty) {
        warnings++;
        result.add(Message(null, null, raw, number));
      } else {
        result.last.text += '\n$raw';
      }
      continue;
    }
    // Locate the timestamp end in the original string to retain body bidi marks.
    final original = raw.replaceFirst('\ufeff', '');
    final boundary = original.indexOf(']');
    String body;
    if (original.trimLeft().startsWith('[') ||
        (boundary >= 0 && boundary < 40)) {
      body = original.substring(boundary + 1).replaceFirst(RegExp(r'^\s'), '');
    } else {
      final sep = original.indexOf(' - ');
      body = sep >= 0 ? original.substring(sep + 3) : m[8]!;
    }
    final senderMatch = RegExp(r'^([^\n:]{1,120}):\s').firstMatch(body);
    result.add(
      Message(
        time,
        senderMatch?[1],
        senderMatch == null ? body : body.substring(senderMatch.end),
        number,
      ),
    );
  }
  result.sort((a, b) {
    if (a.time == null && b.time == null) return a.line.compareTo(b.line);
    if (a.time == null) return -1;
    if (b.time == null) return 1;
    final order = a.time!.compareTo(b.time!);
    return order == 0 ? a.line.compareTo(b.line) : order;
  });
  return Transcript(
    result,
    inferred == null || conflicting,
    warnings + (conflicting ? 1 : 0),
    order,
  );
}

class Chat {
  final String transcript, root, name;
  final int bytes, count;
  final DateTime? latest;
  final String preview;
  final String searchText;
  final bool partial;
  Chat(
    this.transcript,
    this.root,
    this.name,
    this.bytes,
    this.count,
    this.latest,
    this.preview,
    this.partial, {
    this.searchText = '',
  });
  String get size => formatBytes(bytes);
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var n = bytes.toDouble(), i = 0;
  while (n >= 1000 && i < units.length - 1) {
    n /= 1000;
    i++;
  }
  return '${n.toStringAsFixed(i == 0 ? 0 : 2)} ${units[i]}';
}

Future<bool> isTranscript(File f) async {
  if (p.extension(f.path).toLowerCase() != '.txt') return false;
  var lines = 0;
  try {
    await for (final line
        in f
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (record.hasMatch(normalized(line))) return true;
      if (++lines >= 30) break;
    }
  } catch (_) {
    return false;
  }
  return p.basename(f.path).toLowerCase() == '_chat.txt';
}

String chatDisplayName(String name) {
  final cleaned = name
      .replaceFirst(RegExp(r'^WhatsApp Chat\s*-\s*', caseSensitive: false), '')
      .trim();
  return cleaned.isEmpty ? name : cleaned;
}

Future<List<Chat>> scanLibrary(
  String root, {
  void Function(int)? progress,
  Map<String, bool> dateOrders = const {},
}) async {
  final transcripts = <File>[];
  Future<void> discover(Directory d) async {
    await for (final e in d.list(followLinks: false)) {
      if (e is Directory) {
        await discover(e);
      }
      if (e is File && await isTranscript(e)) transcripts.add(e);
    }
  }

  await discover(Directory(root));
  final roots = transcripts.map((e) => p.dirname(e.path)).toSet();
  final chats = <Chat>[];
  for (final file in transcripts) {
    final chatRoot = p.dirname(file.path);
    int bytes = 0;
    bool partial = false;
    Future<void> size(Directory dir) async {
      try {
        await for (final e in dir.list(followLinks: false)) {
          if (e is Directory && !roots.contains(e.path)) await size(e);
          if (e is File && p.extension(e.path).toLowerCase() != '.zip') {
            try {
              bytes += await e.length();
            } catch (_) {
              partial = true;
            }
          }
        }
      } catch (_) {
        partial = true;
      }
    }

    await size(Directory(chatRoot));
    final parsed = await parseTranscript(
      file.path,
      monthFirst: dateOrders[file.path],
    );
    DateTime? latest;
    String preview = '';
    for (final m in parsed.messages) {
      if (!m.isSystem &&
          m.time != null &&
          (latest == null || !m.time!.isBefore(latest))) {
        latest = m.time;
        preview = m.text;
      }
    }
    final multiple =
        transcripts.where((e) => p.dirname(e.path) == chatRoot).length > 1;
    chats.add(
      Chat(
        file.path,
        chatRoot,
        multiple
            ? '${chatDisplayName(p.basename(chatRoot))} / ${chatDisplayName(p.basenameWithoutExtension(file.path))}'
            : chatDisplayName(p.basename(chatRoot)),
        bytes,
        parsed.messages.where((m) => !m.isSystem).length,
        latest,
        preview.isEmpty ? 'No user messages' : preview,
        partial,
        searchText: searchableTranscript(parsed),
      ),
    );
    progress?.call(chats.length);
  }
  chats.sort(
    (a, b) => (b.latest ?? DateTime(1)).compareTo(a.latest ?? DateTime(1)),
  );
  return chats;
}

Future<Map<String, List<String>>> mediaIndex(String root) async {
  final result = <String, List<String>>{};
  await for (final e in Directory(
    root,
  ).list(recursive: true, followLinks: false)) {
    if (e is File) {
      result
          .putIfAbsent(p.basename(e.path).toLowerCase(), () => [])
          .add(e.path);
    }
  }
  return result;
}

String? attachmentName(String text) {
  final ios = RegExp(r'<attached:\s*([^>]+)>').firstMatch(normalized(text));
  if (ios != null) return ios[1]!.trim();
  final android = RegExp(
    r'^(.+?)\s*\(file attached\)',
    multiLine: true,
  ).firstMatch(normalized(text));
  return android?[1]?.trim();
}

String? resolveAttachment(
  String root,
  String name,
  Map<String, List<String>> index,
) {
  if (p.isAbsolute(name) || name.contains(':')) return null;
  final full = p.normalize(p.join(root, name));
  if (!p.isWithin(root, full)) return null;
  final candidates = index[p.basename(name).toLowerCase()] ?? [];
  // Only return indexed regular files. No guessed paths or link traversal.
  if (candidates.contains(full)) return full;
  final exact = candidates.where((f) => p.basename(f) == name).toList();
  if (exact.length == 1) return exact.single;
  return candidates.length == 1 ? candidates.single : null;
}

bool chatMatches(Chat chat, String query) {
  final key = searchKey(query);
  return key.isEmpty ||
      searchKey(chat.name).contains(key) ||
      chat.searchText.contains(key);
}

int latestUserMessageIndex(List<Message> messages) {
  final index = messages.lastIndexWhere((m) => !m.isSystem);
  return index >= 0
      ? index
      : messages.isEmpty
      ? 0
      : messages.length - 1;
}
