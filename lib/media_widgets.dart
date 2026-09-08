import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'archive.dart';

String mediaCaption(String text, String? filename) {
  if (filename == null) return text;
  var result = text
      .replaceAll(RegExp(r'<attached:\s*[^>]+>'), '')
      .replaceAll(RegExp(r'^.*?\(file attached\)', multiLine: true), '')
      .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e\u2066-\u2069]'), '')
      .trim();
  if (result == filename) return '';
  return result;
}

String mediaDuration(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

class MediaPreview {
  final Duration duration;
  final Uint8List? image;
  const MediaPreview({this.duration = Duration.zero, this.image});
  static final _cache = <String, Future<MediaPreview>>{};
  static Future<void> _queue = Future.value();
  static Future<MediaPreview> load(String path) {
    if (_cache.containsKey(path)) return _cache[path]!;
    if (_cache.length >= 64) _cache.remove(_cache.keys.first);
    final pending = _queue.then((_) => _read(path));
    _queue = pending.then((_) {});
    return _cache[path] = pending;
  }

  static Future<MediaPreview> _read(String path) async {
    try {
      final data = await const MethodChannel('farooq/media')
          .invokeMapMethod<String, dynamic>('preview', path)
          .timeout(const Duration(seconds: 8));
      Uint8List? png;
      if (data?['rgba'] is Uint8List) {
        final ready = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          data!['rgba'],
          data['width'],
          data['height'],
          ui.PixelFormat.rgba8888,
          ready.complete,
        );
        final image = await ready.future;
        png = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))?.buffer.asUint8List();
        image.dispose();
      }
      var duration = Duration(milliseconds: data?['durationMs'] ?? 0);
      if (duration == Duration.zero &&
          [
            '.opus',
            '.ogg',
            '.mp3',
            '.m4a',
            '.wav',
            '.aac',
            '.amr',
          ].contains(p.extension(path).toLowerCase())) {
        Player? probe;
        try {
          probe = Player(configuration: const PlayerConfiguration(vo: 'null'));
          await probe
              .open(Media(path), play: false)
              .timeout(const Duration(seconds: 6));
          duration = probe.state.duration;
          if (duration == Duration.zero) {
            duration = await probe.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 3));
          }
        } catch (_) {
          /* The file-size label remains available for unsupported audio. */
        } finally {
          await probe?.dispose();
        }
      }
      return MediaPreview(duration: duration, image: png);
    } catch (_) {
      return const MediaPreview();
    }
  }
}

class VideoCard extends StatelessWidget {
  final String path;
  final VoidCallback onPlay;
  const VideoCard({super.key, required this.path, required this.onPlay});
  @override
  Widget build(BuildContext context) => FutureBuilder<MediaPreview>(
    future: MediaPreview.load(path),
    builder: (context, snapshot) {
      final preview = snapshot.data;
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: AspectRatio(
          aspectRatio: 0.82,
          child: Material(
            color: const Color(0xff142127),
            child: InkWell(
              onTap: onPlay,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (preview?.image != null)
                    Image.memory(preview!.image!, fit: BoxFit.contain),
                  Center(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 9,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          preview != null && preview.duration > Duration.zero
                              ? mediaDuration(preview.duration)
                              : 'Video',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class VoiceNote extends StatelessWidget {
  final String path;
  final String sender;
  final Player? player;
  final VoidCallback onPlay;
  const VoiceNote({
    super.key,
    required this.path,
    required this.sender,
    required this.onPlay,
    this.player,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<MediaPreview>(
    future: MediaPreview.load(path),
    builder: (context, meta) => StreamBuilder<bool>(
      key: ValueKey(player),
      stream: player?.stream.playing,
      initialData: player?.state.playing ?? false,
      builder: (context, playing) => StreamBuilder<Duration>(
        stream: player?.stream.position,
        initialData: player?.state.position ?? Duration.zero,
        builder: (context, position) {
          final duration =
              player?.state.duration ?? meta.data?.duration ?? Duration.zero;
          final pos = position.data ?? Duration.zero;
          final maximum = duration.inMilliseconds.toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Play / pause',
                  onPressed: onPlay,
                  icon: Icon(
                    playing.data == true
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 29,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 34,
                        child: CustomPaint(
                          painter: VoiceSeekDecoration(
                            maximum > 0 ? pos.inMilliseconds / maximum : 0,
                          ),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbColor: const Color(0xff1dcc76),
                              disabledThumbColor: const Color(0xff1dcc76),
                              disabledActiveTrackColor: Colors.transparent,
                              disabledInactiveTrackColor: Colors.transparent,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 10,
                              ),
                            ),
                            child: Slider(
                              activeColor: Colors.transparent,
                              inactiveColor: Colors.transparent,
                              value: pos.inMilliseconds.toDouble().clamp(
                                0,
                                maximum > 0 ? maximum : 1,
                              ),
                              max: maximum > 0 ? maximum : 1,
                              onChanged: player != null && maximum > 0
                                  ? (v) => player!.seek(
                                      Duration(milliseconds: v.toInt()),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Text(
                          pos > Duration.zero
                              ? mediaDuration(pos)
                              : duration > Duration.zero
                              ? mediaDuration(duration)
                              : 'Voice message',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xfff5d7dd),
                      child: Text(
                        nameInitials(sender),
                        style: const TextStyle(
                          color: Color(0xffbe164c),
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.mic,
                        color: Color(0xff00a884),
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class LinkCard extends StatefulWidget {
  final Uri uri;
  final VoidCallback onOpen;
  const LinkCard({super.key, required this.uri, required this.onOpen});
  @override
  State<LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<LinkCard> {
  String? title, description;
  Uint8List? image;
  bool busy = false, attempted = false;
  String decode(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  Future<Uint8List> fetch(HttpClient client, Uri uri, int limit) async {
    if (!['http', 'https'].contains(uri.scheme)) {
      throw const FormatException('Unsupported URL');
    }
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 6));
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw const HttpException('Preview unavailable');
    }
    final bytes = BytesBuilder();
    await for (final chunk in response.timeout(const Duration(seconds: 6))) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('Preview too large');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      attempted = true;
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final raw = await fetch(client, widget.uri, 1024 * 1024);
      final html = utf8.decode(raw, allowMalformed: true);
      final tags = RegExp(
        r'<meta\b[^>]*>',
        caseSensitive: false,
      ).allMatches(html);
      final properties = <String, String>{};
      for (final tag in tags) {
        final attrs = <String, String>{};
        for (final match in RegExp(
          "([\\w:-]+)\\s*=\\s*[\"']([^\"']*)[\"']",
        ).allMatches(tag[0]!)) {
          attrs[match[1]!.toLowerCase()] = decode(match[2]!);
        }
        final key = attrs['property'] ?? attrs['name'];
        if (key != null && attrs['content'] != null) {
          properties[key] = attrs['content']!;
        }
      }
      Uint8List? picture;
      if (properties['og:image'] != null) {
        try {
          picture = await fetch(
            client,
            widget.uri.resolve(properties['og:image']!),
            4 * 1024 * 1024,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          title = properties['og:title'];
          description =
              properties['og:description'] ?? properties['description'];
          image = picture;
        });
      }
    } catch (_) {
      /* Keep the real URL card when a site does not provide metadata. */
    } finally {
      client.close(force: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff18252b)
            : const Color(0xfff4f4f4),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                Image.memory(
                  image!,
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? widget.uri.host,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      widget.uri.host,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (!attempted || busy)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.public, size: 15),
            label: Text(busy ? 'Loading preview…' : 'Load online preview'),
          ),
        ),
      InkWell(
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            widget.uri.toString(),
            style: const TextStyle(
              color: Color(0xff008f73),
              decoration: TextDecoration.underline,
            ),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    ],
  );
}

class ChatWallpaper extends CustomPainter {
  final bool dark;
  ChatWallpaper(this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? Colors.white : const Color(0xffbba98f)).withValues(
        alpha: dark ? 0.035 : 0.10,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = 12; y < size.height; y += 92) {
      for (double x = 12; x < size.width; x += 108) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(0.24);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 22, 16),
            const Radius.circular(5),
          ),
          paint,
        );
        canvas.drawLine(const Offset(5, 16), const Offset(2, 21), paint);
        canvas.drawCircle(const Offset(52, 39), 8, paint);
        canvas.drawLine(const Offset(47, 39), const Offset(57, 39), paint);
        canvas.drawLine(const Offset(52, 34), const Offset(52, 44), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatWallpaper oldDelegate) =>
      oldDelegate.dark != dark;
}

// A decorative seek strip, not a claim about the recording's audio amplitudes.
class VoiceSeekDecoration extends CustomPainter {
  final double progress;
  VoiceSeekDecoration(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    const heights = [
      8.0,
      16.0,
      22.0,
      12.0,
      25.0,
      18.0,
      10.0,
      20.0,
      14.0,
      9.0,
      17.0,
    ];
    final usable = size.width - 28;
    for (var i = 0; i * 4 < usable; i++) {
      final x = 14.0 + i * 4;
      final height = heights[i % heights.length];
      final paint = Paint()
        ..color = (i * 4 / usable) < progress
            ? const Color(0xff1dcc76)
            : const Color(0xffc9cdcf)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant VoiceSeekDecoration oldDelegate) =>
      oldDelegate.progress != progress;
}

String nameInitials(String name) {
  // Unicode letters remain intact; punctuation-only separators do not count.
  final usable = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty && !['-', '—', '/', '|'].contains(s))
      .toList();
  if (usable.isEmpty) return '?';
  return usable.take(2).map((s) => s.characters.first).join().toUpperCase();
}

class LastMessagePreview extends StatelessWidget {
  final Chat chat;
  const LastMessagePreview({super.key, required this.chat});
  @override
  Widget build(BuildContext context) {
    final name = attachmentName(chat.preview);
    if (name == null) {
      return Text(
        chat.preview.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final ext = p.extension(name).toLowerCase();
    final sticker = name.toLowerCase().contains('sticker');
    final audio = [
      '.opus',
      '.ogg',
      '.mp3',
      '.m4a',
      '.wav',
      '.aac',
      '.amr',
    ].contains(ext);
    final video = [
      '.mp4',
      '.mov',
      '.mkv',
      '.webm',
      '.avi',
      '.3gp',
    ].contains(ext);
    final photo = [
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.gif',
      '.bmp',
    ].contains(ext);
    final label = sticker
        ? 'Sticker'
        : audio
        ? 'Voice message'
        : video
        ? 'Video'
        : photo
        ? 'Photo'
        : 'Document';
    final icon = sticker
        ? Icons.sticky_note_2_outlined
        : audio
        ? Icons.mic
        : video
        ? Icons.videocam
        : photo
        ? Icons.photo_outlined
        : Icons.description_outlined;
    final file = p.normalize(p.join(chat.root, name));
    final safe =
        !p.isAbsolute(name) &&
        !name.contains(':') &&
        p.isWithin(chat.root, file);
    return FutureBuilder<({int? bytes, Duration duration})>(
      future: safe ? _details(file, audio || video) : null,
      builder: (c, snapshot) {
        final details = snapshot.data;
        final suffix = details == null
            ? ''
            : details.duration > Duration.zero
            ? ' · ${mediaDuration(details.duration)}'
            : details.bytes == null
            ? ''
            : ' · ${formatBytes(details.bytes!)}';
        return Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '$label${audio || video ? suffix : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<({int? bytes, Duration duration})> _details(
    String path,
    bool media,
  ) async {
    final stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file) {
      return (bytes: null, duration: Duration.zero);
    }
    final preview = media
        ? await MediaPreview.load(path)
        : const MediaPreview();
    return (bytes: stat.size, duration: preview.duration);
  }
}
