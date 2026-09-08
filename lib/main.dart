import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'archive.dart';
import 'zip_import.dart';
import 'media_widgets.dart';

void archiveWorker(List<dynamic> request) async {
  final sender = request[0] as SendPort;
  final op = request[1] as String;
  final args = request[2] as List<dynamic>;
  try {
    dynamic result;
    if (op == 'scan') {
      result = await scanLibrary(
        args[0] as String,
        dateOrders: args[1] as Map<String, bool>,
      );
    } else if (op == 'open') {
      result = [
        await parseTranscript(args[0] as String, monthFirst: args[2] as bool?),
        await mediaIndex(args[1] as String),
      ];
    } else if (op == 'zip') {
      result = extractZip(args[0] as String, args[1] as String);
    } else {
      throw ArgumentError('Unknown worker operation');
    }
    sender.send(['ok', result]);
  } catch (e) {
    sender.send(['error', e.toString()]);
  }
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(ViewerApp(initialPath: args.isEmpty ? null : args.first));
}

class ViewerApp extends StatefulWidget {
  final String? initialPath;
  const ViewerApp({super.key, this.initialPath});
  @override
  State<ViewerApp> createState() => _ViewerAppState();
}

class _ViewerAppState extends State<ViewerApp> {
  ThemeMode theme = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Farooq Chat Viewer',
    debugShowCheckedModeBanner: false,
    themeMode: theme,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('ur'), Locale('ar')],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff008069)),
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: const Color(0xfff0f2f5),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff00a884),
        brightness: Brightness.dark,
      ),
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: const Color(0xff111b21),
    ),
    home: Home(
      initialPath: widget.initialPath,
      onTheme: (value) => setState(() => theme = value),
    ),
  );
}

class Home extends StatefulWidget {
  final String? initialPath;
  final ValueChanged<ThemeMode> onTheme;
  const Home({super.key, this.initialPath, required this.onTheme});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  SharedPreferences? prefs;
  List<Chat> chats = [];
  Chat? selected;
  Transcript? transcript;
  Map<String, List<String>> files = {};
  String libraryQuery = '',
      messageQuery = '',
      status = '',
      me = '',
      language = 'en';
  String? root, recent;
  bool busy = false;
  int generation = 0, hit = 0;
  Isolate? worker;
  ReceivePort? workerPort;
  final itemScroll = ItemScrollController();
  final searchFocus = FocusNode();
  final librarySearchController = TextEditingController();
  final queryController = TextEditingController();
  Player? player;
  VideoController? videoController;
  String? playing;
  StreamSubscription<String>? playerErrors;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  String t(String en) => translations[language]?[en] ?? en;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final system =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    setState(() {
      recent = prefs!.getString('library');
      language =
          prefs!.getString('language') ??
          (['ar', 'ur'].contains(system) ? system : 'en');
    });
    widget.onTheme(ThemeMode.values[prefs!.getInt('theme') ?? 0]);
    final remembered = widget.initialPath ?? recent;
    if (remembered != null) await load(remembered);
  }

  @override
  void dispose() {
    worker?.kill(priority: Isolate.immediate);
    workerPort?.close();
    playerErrors?.cancel();
    player?.dispose();
    searchFocus.dispose();
    librarySearchController.dispose();
    queryController.dispose();
    super.dispose();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('Could not complete action')}: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<T?> background<T>(String operation, List<dynamic> args) async {
    final port = ReceivePort();
    workerPort = port;
    worker = await Isolate.spawn(archiveWorker, [
      port.sendPort,
      operation,
      args,
    ]);
    final reply = await port.first;
    port.close();
    workerPort = null;
    worker = null;
    if (reply == null) return null;
    if (reply[0] == 'error') throw Exception(reply[1]);
    return reply[1] as T;
  }

  void cancel() {
    generation++;
    worker?.kill(priority: Isolate.immediate);
    workerPort?.sendPort.send(null);
    worker = null;
    setState(() {
      busy = false;
      status = t('Cancelled');
    });
  }

  Future<void> disconnect() async {
    if (busy) return;
    await player?.stop();
    await prefs?.remove('library');
    if (!mounted) return;
    setState(() {
      root = null;
      recent = null;
      chats = [];
      selected = null;
      transcript = null;
      libraryQuery = '';
      librarySearchController.clear();
      messageQuery = '';
      queryController.clear();
      playing = null;
      files = {};
      status = '';
    });
  }

  Future<void> pick() async {
    final value = await FilePicker.platform.getDirectoryPath(
      dialogTitle: t('Open conversations folder'),
    );
    if (value != null) await load(value);
  }

  Future<void> load(String path) async {
    if (busy) return;
    final token = ++generation;
    setState(() {
      busy = true;
      status = t('Reading archive folders…');
    });
    try {
      final result = await background<List<Chat>>('scan', [
        path,
        {
          for (final k in prefs?.getKeys() ?? <String>{})
            if (k.startsWith('date:')) k.substring(5): prefs!.getBool(k)!,
        },
      ]);
      if (!mounted || token != generation || result == null) return;
      await player?.stop();
      setState(() {
        if (root != path) {
          libraryQuery = '';
          librarySearchController.clear();
        }
        root = path;
        recent = path;
        chats = result;
        selected = null;
        transcript = null;
        status = result.isEmpty
            ? t(
                'No exported chats found. Choose a folder containing _chat.txt or an Android export.',
              )
            : '${result.length} ${t('conversations')}';
      });
      await prefs?.setString('library', path);
    } catch (e) {
      error(e);
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> importZip() async {
    if (busy) return;
    final chosen = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final zip = chosen?.files.single.path;
    if (zip == null) return;
    final destination = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to create the extracted chat folder',
    );
    if (destination == null) return;
    final target = p.join(
      destination,
      '${p.basenameWithoutExtension(zip)}-${DateTime.now().millisecondsSinceEpoch}',
    );
    final token = ++generation;
    setState(() {
      busy = true;
      status = t('Extracting ZIP…');
    });
    try {
      final extracted = await background<String>('zip', [zip, target]);
      if (token != generation || extracted == null) {
        // Only remove the unique, app-created staging directory after cancellation.
        if (Directory(target).existsSync()) {
          await Directory(target).delete(recursive: true);
        }
        return;
      }
      setState(() => busy = false);
      await load(extracted);
    } catch (e) {
      error(e);
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> openChat(Chat chat, {bool? order}) async {
    if (busy) return;
    final token = ++generation;
    await player?.stop();
    setState(() {
      busy = true;
      status = t('Opening conversation…');
      playing = null;
    });
    final path = chat.transcript, folder = chat.root;
    final saved = order ?? prefs?.getBool('date:$path');
    try {
      final result = await background<List<dynamic>>('open', [
        path,
        folder,
        saved,
      ]);
      if (!mounted || token != generation || result == null) return;
      setState(() {
        transcript = result[0] as Transcript;
        final dated = transcript!.messages
            .where((m) => m.time != null && !m.isSystem)
            .toList();
        dated.sort((a, b) => a.time!.compareTo(b.time!));
        selected = Chat(
          chat.transcript,
          chat.root,
          chat.name,
          chat.bytes,
          transcript!.messages.where((m) => !m.isSystem).length,
          dated.isEmpty ? null : dated.last.time,
          dated.isEmpty ? 'No user messages' : dated.last.text,
          chat.partial,
          searchText: searchableTranscript(transcript!),
        );
        chats = [
          for (final item in chats)
            item.transcript == chat.transcript ? selected! : item,
        ];
        chats.sort(
          (a, b) =>
              (b.latest ?? DateTime(1)).compareTo(a.latest ?? DateTime(1)),
        );
        files = result[1] as Map<String, List<String>>;
        me = prefs?.getString('me:$path') ?? '';
        messageQuery = '';
        queryController.clear();
        hit = 0;
      });
    } catch (e) {
      error(e);
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  List<int> get hits => messageQuery.isEmpty || transcript == null
      ? []
      : [
          for (var i = 0; i < transcript!.messages.length; i++)
            if (!transcript!.messages[i].isSystem &&
                searchKey(
                  '${transcript!.messages[i].sender ?? ''} ${transcript!.messages[i].text}',
                ).contains(searchKey(messageQuery)))
              i,
        ];
  void navigateHit(int change) {
    final values = hits;
    if (values.isEmpty || !itemScroll.isAttached) return;
    setState(() => hit = (hit + change) % values.length);
    itemScroll.scrollTo(
      index: values[hit],
      duration: const Duration(milliseconds: 200),
    );
  }

  Future<void> save(String path) async {
    try {
      final target = await FilePicker.platform.saveFile(
        fileName: p.basename(path),
      );
      if (target == null) return;
      final canonicalTarget = p.join(
        await Directory(p.dirname(target)).resolveSymbolicLinks(),
        p.basename(target),
      );
      final canonicalRoot = await Directory(
        selected!.root,
      ).resolveSymbolicLinks();
      if (p.equals(p.absolute(target), p.absolute(path)) ||
          p.isWithin(canonicalRoot, canonicalTarget)) {
        throw Exception(
          'Save outside the source chat folder to preserve the original archive.',
        );
      }
      await File(path).copy(target);
    } catch (e) {
      error(e);
    }
  }

  Future<void> copyImage(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final rgba = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw Exception('Image decoding failed');
      final out = Uint8List(40 + rgba.lengthInBytes);
      final header = ByteData.sublistView(out);
      header.setUint32(0, 40, Endian.little);
      header.setInt32(4, img.width, Endian.little);
      header.setInt32(8, -img.height, Endian.little);
      header.setUint16(12, 1, Endian.little);
      header.setUint16(14, 32, Endian.little);
      header.setUint32(20, rgba.lengthInBytes, Endian.little);
      final pixels = rgba.buffer.asUint8List();
      for (var i = 0; i < pixels.length; i += 4) {
        out[40 + i] = pixels[i + 2];
        out[41 + i] = pixels[i + 1];
        out[42 + i] = pixels[i];
        out[43 + i] = pixels[i + 3];
      }
      img.dispose();
      codec.dispose();
      await const MethodChannel(
        'farooq/clipboard',
      ).invokeMethod<void>('copyImage', out);
    } catch (e) {
      error(e);
    }
  }

  Future<void> share(Message m, String? path) async {
    try {
      final clean = m.text.trim();
      final link = !RegExp(r'\s').hasMatch(clean) ? Uri.tryParse(clean) : null;
      final webLink =
          link != null &&
          ['http', 'https'].contains(link.scheme) &&
          link.host.isNotEmpty;
      await SharePlus.instance.share(
        path == null
            ? ShareParams(
                title: selected?.name ?? 'Farooq Chat Viewer',
                text: webLink ? null : m.text,
                uri: webLink ? link : null,
              )
            : ShareParams(
                title: selected?.name ?? 'Farooq Chat Viewer',
                files: [XFile(path)],
              ),
      );
    } catch (e) {
      error('Sharing unavailable. Use Copy or Save. $e');
    }
  }

  Future<void> external(String path) async {
    const blocked = [
      '.exe',
      '.com',
      '.bat',
      '.cmd',
      '.ps1',
      '.msi',
      '.scr',
      '.lnk',
      '.url',
      '.vbs',
      '.js',
      '.hta',
      '.reg',
    ];
    if (blocked.contains(p.extension(path).toLowerCase())) {
      error(
        'Executable attachments cannot be opened here. Save a copy if you need it.',
      );
      return;
    }
    try {
      if (!await launchUrl(Uri.file(path))) {
        error('No application is available for this file. Use Save.');
      }
    } catch (e) {
      error(e);
    }
  }

  Future<void> play(String path) async {
    try {
      player ??= Player();
      videoController ??= VideoController(player!);
      playerErrors ??= player!.stream.error.listen(
        (e) => error('Playback error: $e'),
      );
      if (playing == path) {
        await player!.playOrPause();
        if (mounted) setState(() {});
        return;
      }
      await player!.open(Media(path));
      if (mounted) setState(() => playing = path);
    } catch (e) {
      error(e);
    }
  }

  void help() => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t('Help & privacy')),
      content: const SizedBox(
        width: 570,
        child: SingleChildScrollView(
          child: SelectableText(
            'Farooq Chat Viewer 2.0.3\nBy Mohammad Farooq\n\n1. In WhatsApp, export a conversation with the media you need.\n2. Copy it to your PC. Keep one extracted folder per chat, or choose Import ZIP.\n3. Open that folder or its parent conversations folder. Select a chat and choose your name under “Me”.\n4. If dates are ambiguous, select day/month or month/day in the chat header.\n\nReading happens locally. There is no WhatsApp login, live messaging, automatic upload, or automatic link preview. Load online preview contacts the linked website only when you choose it. Source archives are read-only. Save makes a separate copy. Share opens an external app; you choose the recipient and complete sending there. Clipboard and cloud-folder synchronization follow your Windows settings.\n\nExported files are not encrypted by this viewer. Make cloud archives available offline. Verify important messages/media and keep an independent backup before deciding whether to delete anything from your phone.\n\nForget removes the remembered folder reference only. Settings are held by Windows in this application’s preferences.\n\nEnglish interface with partial Urdu/Arabic translations and English fallback. Original Unicode message text is preserved. No claim of complete translation coverage.\n\nIndependent software; not affiliated with WhatsApp or Meta.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              launchUrl(Uri(scheme: 'mailto', path: 'babaqatar@gmail.com')),
          child: Text(t('Support')),
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: c,
            applicationName: 'Farooq Chat Viewer',
          ),
          child: const Text('Licenses'),
        ),
        TextButton(onPressed: () => Navigator.pop(c), child: Text(t('Close'))),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          searchFocus.requestFocus(),
    },
    child: Focus(
      autofocus: true,
      child: Directionality(
        textDirection: language == 'en' ? TextDirection.ltr : TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              t('Farooq Chat Viewer'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                tooltip: t('Open folder'),
                onPressed: busy ? null : pick,
                icon: const Icon(Icons.folder_open),
              ),
              if (recent != null)
                IconButton(
                  tooltip: 'Disconnect folder',
                  onPressed: busy ? null : disconnect,
                  icon: const Icon(Icons.link_off),
                ),
              IconButton(
                tooltip: t('Import ZIP'),
                onPressed: busy ? null : importZip,
                icon: const Icon(Icons.archive_outlined),
              ),
              IconButton(
                tooltip: t('Refresh'),
                onPressed: busy || root == null ? null : () => load(root!),
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<ThemeMode>(
                tooltip: t('Theme'),
                icon: const Icon(Icons.contrast),
                onSelected: (v) {
                  widget.onTheme(v);
                  prefs?.setInt('theme', v.index);
                },
                itemBuilder: (c) => ThemeMode.values
                    .map((v) => PopupMenuItem(value: v, child: Text(t(v.name))))
                    .toList(),
              ),
              PopupMenuButton<String>(
                tooltip: 'Language / زبان / اللغة',
                icon: const Icon(Icons.translate),
                onSelected: (v) {
                  setState(() => language = v);
                  prefs?.setString('language', v);
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'en', child: Text('English')),
                  PopupMenuItem(value: 'ur', child: Text('اردو · partial')),
                  PopupMenuItem(value: 'ar', child: Text('العربية · partial')),
                ],
              ),
              IconButton(
                tooltip: t('Help & privacy'),
                onPressed: help,
                icon: const Icon(Icons.help_outline),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: DropTarget(
            onDragDone: (details) {
              if (!busy && details.files.isNotEmpty) {
                final path = details.files.first.path;
                if (Directory(path).existsSync()) {
                  load(path);
                } else {
                  error(
                    'Drop an extracted chat folder. Use Import ZIP for ZIP files.',
                  );
                }
              }
            },
            child: Column(
              children: [
                if (busy) ...[
                  const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(status)),
                        TextButton(onPressed: cancel, child: Text(t('Cancel'))),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: chats.isEmpty
                      ? welcome()
                      : LayoutBuilder(
                          builder: (c, box) {
                            final narrow = box.maxWidth < 850;
                            if (narrow) {
                              return selected == null
                                  ? library()
                                  : conversation();
                            }
                            return Row(
                              children: [
                                SizedBox(width: 340, child: library()),
                                const VerticalDivider(width: 1),
                                Expanded(child: conversation()),
                              ],
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    t('Read-only archive · Your original files stay unchanged'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget welcome() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('Your conversations. Always yours.'),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'Read saved WhatsApp conversations, photos and voice notes on your computer.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : pick,
                  icon: const Icon(Icons.folder_open),
                  label: Text(t('Open conversations folder')),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : importZip,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(t('Import ZIP')),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(t('Or drop one chat folder here')),
            const SizedBox(height: 28),
            if (recent != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(p.basename(recent!), maxLines: 2),
                      Wrap(
                        spacing: 16,
                        children: [
                          TextButton(
                            onPressed: busy ? null : () => load(recent!),
                            child: Text(t('Reopen')),
                          ),
                          TextButton(
                            onPressed: () {
                              prefs?.remove('library');
                              setState(() => recent = null);
                            },
                            child: Text(t('Forget')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(status, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 20),
            Text(
              'Mohammad Farooq  ·  2.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
  Widget library() {
    final visible = chats.where((c) => chatMatches(c, libraryQuery)).toList();
    return Material(
      color: dark ? const Color(0xff111b21) : Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t('Conversations')} · ${chats.length}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: librarySearchController,
                  onChanged: (s) => setState(() => libraryQuery = s),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: t('Search conversations'),
                    hintText: 'Name or message text',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text(t('No results')))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (c, i) {
                      final chat = visible[i];
                      return ListTile(
                        selected: selected?.transcript == chat.transcript,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Text(nameInitials(chat.name)),
                        ),
                        title: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            LastMessagePreview(
                              key: ValueKey(chat.transcript + chat.preview),
                              chat: chat,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${chat.latest == null ? t('Date unavailable') : DateFormat('d MMM yyyy, HH:mm').format(chat.latest!)} · ${chat.partial ? '≥ ' : ''}${chat.size}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        onTap: busy
                            ? null
                            : () async {
                                final query = libraryQuery.trim();
                                await openChat(chat);
                                if (!mounted ||
                                    selected?.transcript != chat.transcript ||
                                    query.isEmpty ||
                                    searchKey(
                                      chat.name,
                                    ).contains(searchKey(query))) {
                                  return;
                                }
                                setState(() {
                                  messageQuery = query;
                                  queryController.text = query;
                                  hit = 0;
                                });
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && itemScroll.isAttached) {
                                    navigateHit(0);
                                  }
                                });
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget conversation() {
    if (selected == null || transcript == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_chat_read_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              t('Select a conversation'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }
    final senders = transcript!.messages
        .where((m) => !m.isSystem)
        .map((m) => m.sender)
        .whereType<String>()
        .toSet()
        .toList();
    final messages = transcript!.messages;
    final found = hits;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: t('Back'),
                    onPressed: () {
                      player?.stop();
                      setState(() => selected = null);
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${selected!.count} ${t('messages')} · ${selected!.size}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Date order',
                    onSelected: (v) {
                      prefs?.setBool('date:${selected!.transcript}', v);
                      openChat(selected!, order: v);
                    },
                    itemBuilder: (c) => const [
                      PopupMenuItem(
                        value: false,
                        child: Text('Day / Month / Year'),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Text('Month / Day / Year'),
                      ),
                    ],
                    icon: const Icon(Icons.calendar_month),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: senders.contains(me) ? me : '',
                    hint: Text(t('Me')),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(t('Me: choose participant')),
                      ),
                      ...senders.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: SizedBox(
                            width: 180,
                            child: Text(s, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => me = v ?? '');
                      prefs?.setString('me:${selected!.transcript}', me);
                    },
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: queryController,
                      focusNode: searchFocus,
                      onChanged: (s) {
                        setState(() {
                          messageQuery = s.trim();
                          hit = 0;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              hits.isNotEmpty &&
                              itemScroll.isAttached) {
                            navigateHit(0);
                          }
                        });
                      },
                      onSubmitted: (_) => navigateHit(0),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: t('Search messages'),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (messageQuery.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          found.isEmpty
                              ? 'No results'
                              : '${hit + 1}/${found.length}',
                        ),
                        IconButton(
                          tooltip: t('Previous'),
                          onPressed: found.isEmpty
                              ? null
                              : () => navigateHit(-1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: t('Next'),
                          onPressed: found.isEmpty
                              ? null
                              : () => navigateHit(1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                      ],
                    ),
                ],
              ),
              if (transcript!.ambiguous || transcript!.warnings > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${transcript!.ambiguous ? 'Date order: ${transcript!.monthFirst ? 'month/day' : 'day/month'} — change using the calendar. ' : ''}${transcript!.warnings > 0 ? '${transcript!.warnings} parse warnings; original lines retained.' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (messageQuery.isNotEmpty && found.isNotEmpty)
          SizedBox(
            height: found.length == 1 ? 64 : 150,
            child: ListView.builder(
              itemCount: found.length,
              itemBuilder: (c, index) {
                final message = messages[found[index]];
                return ListTile(
                  dense: true,
                  selected: index == hit,
                  leading: const Icon(Icons.search, size: 18),
                  title: Text(
                    message.text.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${message.sender ?? 'System'} · ${message.time == null ? 'Unknown date' : DateFormat('d MMM yyyy, HH:mm').format(message.time!)}',
                  ),
                  onTap: () {
                    setState(() => hit = index);
                    navigateHit(0);
                  },
                );
              },
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: dark ? const Color(0xff0b141a) : const Color(0xffefeae2),
            child: CustomPaint(
              painter: ChatWallpaper(dark),
              child: messages.isEmpty
                  ? Center(child: Text(t('No messages found')))
                  : ScrollablePositionedList.builder(
                      key: ValueKey(
                        '${selected!.transcript}:${transcript!.monthFirst}',
                      ),
                      itemScrollController: itemScroll,
                      initialScrollIndex: latestUserMessageIndex(messages),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (c, i) {
                        final m = messages[i];
                        final newDay =
                            m.time != null &&
                            (i == 0 ||
                                messages[i - 1].time == null ||
                                DateUtils.dateOnly(m.time!) !=
                                    DateUtils.dateOnly(messages[i - 1].time!));
                        return Column(
                          children: [
                            if (newDay)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Chip(
                                  label: Text(
                                    DateFormat(
                                      'EEEE, d MMMM yyyy',
                                    ).format(m.time!),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            bubble(m, i),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: messages.isEmpty
                ? null
                : () => itemScroll.jumpTo(
                    index: latestUserMessageIndex(messages),
                  ),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: Text(t('Latest message')),
          ),
        ),
      ],
    );
  }

  Widget bubble(Message m, int i) {
    if (m.isSystem) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.symmetric(vertical: 9),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? const Color(0xff344139) : const Color(0xfffff1d1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    searchKey(m.text).contains('disappearing')
                        ? Icons.timer_outlined
                        : Icons.lock_outline,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'WhatsApp system notice',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SelectableText(
                m.text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    final mine = me.isNotEmpty && m.sender == me;
    final name = attachmentName(m.text);
    final path = name == null
        ? null
        : resolveAttachment(selected!.root, name, files);
    final ext = p.extension(path ?? name ?? '').toLowerCase();
    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
    ].contains(ext);
    final sticker = isImage && (name ?? '').toLowerCase().contains('sticker');
    final isVideo = [
      '.mp4',
      '.mov',
      '.webm',
      '.mkv',
      '.avi',
      '.3gp',
    ].contains(ext);
    final isAudio = [
      '.opus',
      '.ogg',
      '.mp3',
      '.m4a',
      '.aac',
      '.wav',
      '.amr',
    ].contains(ext);
    final caption = mediaCaption(m.text, name);
    final links = name == null
        ? RegExp(
            r'https?://[^\s<>]+',
          ).allMatches(caption).map((m) => m[0]!).toList()
        : <String>[];
    final body = links.isEmpty
        ? caption
        : caption.replaceAll(RegExp(r'https?://[^\s<>]+'), '').trim();
    final rtl = RegExp(
      r'^[^A-Za-z\u0600-\u06ff\u0590-\u05ff]*[\u0600-\u06ff\u0590-\u05ff]',
    ).hasMatch(caption);
    final active = path != null && playing == path && player != null;
    final timestamp = m.time == null
        ? 'Line ${m.line}'
        : DateFormat('h:mm a').format(m.time!);
    final visual = path != null && isImage;
    return Align(
      alignment: m.sender == null
          ? Alignment.center
          : mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: sticker
                    ? 250
                    : isAudio
                    ? 350
                    : visual || isVideo || links.isNotEmpty
                    ? 330
                    : 550,
              ),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: sticker
                  ? EdgeInsets.zero
                  : const EdgeInsets.fromLTRB(7, 6, 7, 3),
              decoration: BoxDecoration(
                color: sticker
                    ? Colors.transparent
                    : messageQuery.isNotEmpty &&
                          normalized(m.text).toLowerCase().contains(
                            normalized(messageQuery).toLowerCase(),
                          )
                    ? (dark ? const Color(0xff635222) : const Color(0xffffefad))
                    : mine
                    ? (dark ? const Color(0xff005c4b) : const Color(0xffd9fdd3))
                    : (dark ? const Color(0xff202c33) : Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.sender != null && !sticker)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
                      child: Text(
                        m.sender!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: dark
                              ? const Color(0xff6ed6c2)
                              : const Color(0xff00806b),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (visual)
                    InkWell(
                      onTap: () => lightbox(path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: sticker ? 250 : 410,
                          ),
                          child: Image.file(
                            File(path),
                            width: sticker ? 225 : 316,
                            fit: BoxFit.contain,
                            cacheWidth: sticker ? 450 : 720,
                            errorBuilder: (c, e, st) => const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'Preview unavailable — use Open or Save',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (path != null && isVideo)
                    active
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              height: 360,
                              child: Video(controller: videoController!),
                            ),
                          )
                        : VideoCard(
                            key: ValueKey(path),
                            path: path,
                            onPlay: () => play(path),
                          ),
                  if (path != null && isAudio)
                    VoiceNote(
                      key: ValueKey(path),
                      path: path,
                      sender: m.sender ?? '',
                      player: active ? player : null,
                      onPlay: () => play(path),
                    ),
                  if (name != null &&
                      (path == null || (!isImage && !isAudio && !isVideo)))
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            path == null
                                ? Icons.broken_image_outlined
                                : Icons.description_outlined,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              path == null
                                  ? '$name · ${t('Missing or ambiguous attachment')}'
                                  : name,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          if (path != null)
                            IconButton(
                              tooltip: t('Save file…'),
                              onPressed: () => save(path),
                              icon: const Icon(Icons.download_outlined),
                            ),
                        ],
                      ),
                    ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      child: SelectableText(
                        body,
                        textDirection: rtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        style: const TextStyle(fontSize: 14, height: 1.45),
                      ),
                    ),
                  for (final link in links)
                    LinkCard(
                      key: ValueKey(link),
                      uri: Uri.parse(link),
                      onOpen: () => launchUrl(
                        Uri.parse(link),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (active)
                          PopupMenuButton<double>(
                            tooltip: 'Playback speed',
                            onSelected: (v) => player!.setRate(v),
                            itemBuilder: (c) => [0.5, 1.0, 1.5, 2.0]
                                .map(
                                  (v) => PopupMenuItem(
                                    value: v,
                                    child: Text('${v}x'),
                                  ),
                                )
                                .toList(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Speed',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: sticker
                              ? BoxDecoration(
                                  color: dark
                                      ? const Color(0xff202c33)
                                      : Colors.white70,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          child: Text(
                            timestamp,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: t('Message actions'),
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (v) async {
                            if (v == 'copy') {
                              await Clipboard.setData(
                                ClipboardData(text: m.text),
                              );
                            }
                            if (v == 'share') await share(m, path);
                            if (v == 'image' && path != null) {
                              await copyImage(path);
                            }
                            if (v == 'save' && path != null) await save(path);
                            if (v == 'open' && path != null) {
                              await external(path);
                            }
                          },
                          itemBuilder: (c) => [
                            PopupMenuItem(
                              value: 'copy',
                              child: Text(t('Copy text')),
                            ),
                            if (visual)
                              PopupMenuItem(
                                value: 'image',
                                child: Text(t('Copy image')),
                              ),
                            PopupMenuItem(
                              value: 'share',
                              child: Text(t('Share / Forward…')),
                            ),
                            if (path != null) ...[
                              PopupMenuItem(
                                value: 'save',
                                child: Text(t('Save file…')),
                              ),
                              PopupMenuItem(
                                value: 'open',
                                child: Text(t('Open file')),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: t('Share / Forward…'),
            onPressed: () => share(m, path),
            style: IconButton.styleFrom(
              backgroundColor: dark ? Colors.white12 : Colors.white70,
            ),
            icon: Transform.flip(
              flipX: true,
              child: const Icon(Icons.reply_all_rounded, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  void lightbox(String path) {
    final images =
        files.values
            .expand((e) => e)
            .where(
              (f) => [
                '.jpg',
                '.jpeg',
                '.png',
                '.gif',
                '.webp',
                '.bmp',
              ].contains(p.extension(f).toLowerCase()),
            )
            .toList()
          ..sort();
    var index = images.indexOf(path);
    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                update(() => index = (index - 1) % images.length),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                update(() => index = (index + 1) % images.length),
          },
          child: Focus(
            autofocus: true,
            child: Dialog(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: t('Previous'),
                        onPressed: () =>
                            update(() => index = (index - 1) % images.length),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          p.basename(images[index]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: t('Next'),
                        onPressed: () =>
                            update(() => index = (index + 1) % images.length),
                        icon: const Icon(Icons.chevron_right),
                      ),
                      IconButton(
                        tooltip: t('Save file…'),
                        onPressed: () => save(images[index]),
                        icon: const Icon(Icons.save_alt),
                      ),
                      IconButton(
                        tooltip: t('Close'),
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      child: Image.file(
                        File(images[index]),
                        errorBuilder: (c, e, s) =>
                            const Text('Preview unavailable'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const translations = <String, Map<String, String>>{
  'ur': {
    'Farooq Chat Viewer': 'فاروق چیٹ ویور',
    'Open folder': 'فولڈر کھولیں',
    'Import ZIP': 'زپ درآمد کریں',
    'Refresh': 'تازہ کریں',
    'Help & privacy': 'مدد اور رازداری',
    'Close': 'بند کریں',
    'Support': 'رابطہ',
    'Cancel': 'منسوخ',
    'Conversations': 'گفتگو',
    'Search conversations': 'گفتگو تلاش کریں',
    'Search messages': 'پیغامات تلاش کریں',
    'Select a conversation': 'گفتگو منتخب کریں',
    'Back': 'واپس',
    'Reopen': 'دوبارہ کھولیں',
    'Forget': 'بھول جائیں',
    'Open conversations folder': 'گفتگو کا فولڈر کھولیں',
    'Your conversations. Always yours.': 'آپ کی گفتگو، ہمیشہ آپ کے پاس۔',
    'Or drop one chat folder here': 'یا گفتگو کا فولڈر یہاں ڈالیں',
    'Read-only archive · Your original files stay unchanged':
        'صرف مطالعہ · اصل فائلیں تبدیل نہیں ہوتیں',
    'Copy text': 'متن کاپی کریں',
    'Save file…': 'فائل محفوظ کریں',
    'Open file': 'فائل کھولیں',
    'Latest message': 'آخری پیغام',
    'No results': 'کوئی نتیجہ نہیں',
    'Theme': 'رنگ',
    'messages': 'پیغامات',
  },
  'ar': {
    'Farooq Chat Viewer': 'عارض محادثات فاروق',
    'Open folder': 'فتح مجلد',
    'Import ZIP': 'استيراد ZIP',
    'Refresh': 'تحديث',
    'Help & privacy': 'المساعدة والخصوصية',
    'Close': 'إغلاق',
    'Support': 'الدعم',
    'Cancel': 'إلغاء',
    'Conversations': 'المحادثات',
    'Search conversations': 'البحث عن محادثات',
    'Search messages': 'البحث في الرسائل',
    'Select a conversation': 'اختر محادثة',
    'Back': 'رجوع',
    'Reopen': 'إعادة فتح',
    'Forget': 'نسيان',
    'Open conversations folder': 'فتح مجلد المحادثات',
    'Your conversations. Always yours.': 'محادثاتك، تبقى لك.',
    'Or drop one chat folder here': 'أو اسحب مجلد المحادثة هنا',
    'Read-only archive · Your original files stay unchanged':
        'للقراءة فقط · ملفاتك الأصلية لا تتغير',
    'Copy text': 'نسخ النص',
    'Save file…': 'حفظ الملف',
    'Open file': 'فتح الملف',
    'Latest message': 'آخر رسالة',
    'No results': 'لا توجد نتائج',
    'Theme': 'المظهر',
    'messages': 'رسائل',
  },
};
