import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/chat_archive.dart';
import 'services/archive_scanner.dart';

void main() {
  runApp(const FarooqChatViewerApp());
}

class FarooqChatViewerApp extends StatelessWidget {
  const FarooqChatViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farooq Chat Viewer',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0AA884)),
        scaffoldBackgroundColor: const Color(0xFFF3F6F8),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF25D366),
          brightness: Brightness.dark,
        ),
      ),
      home: const ArchiveHomePage(),
    );
  }
}

class ArchiveHomePage extends StatefulWidget {
  const ArchiveHomePage({super.key});

  @override
  State<ArchiveHomePage> createState() => _ArchiveHomePageState();
}

class _ArchiveHomePageState extends State<ArchiveHomePage> {
  final _scanner = const ArchiveScanner();
  final _search = TextEditingController();
  List<ChatArchive> _archives = const [];
  ChatArchive? _selected;
  bool _loading = false;
  String? _rootPath;

  @override
  void initState() {
    super.initState();
    _restoreLastFolder();
  }

  Future<void> _restoreLastFolder() async {
    if (!Platform.isWindows) return;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('lastConversationsFolder');
    if (path == null) return;
    final directory = Directory(path);
    if (await directory.exists()) await _loadRoot(directory, remember: false);
  }

  Future<void> _chooseFolder() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('On iOS, use the ZIP import flow from Files.')),
      );
      return;
    }
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select conversations folder');
    if (path == null) return;
    await _loadRoot(Directory(path));
  }

  Future<void> _loadRoot(Directory directory, {bool remember = true}) async {
    setState(() => _loading = true);
    try {
      final items = await _scanner.scanConversationsFolder(directory);
      if (remember && Platform.isWindows) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastConversationsFolder', directory.path);
      }
      if (!mounted) return;
      setState(() {
        _archives = items;
        _selected = items.isEmpty ? null : items.first;
        _rootPath = directory.path;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ChatArchive> get _visibleArchives {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _archives;
    return _archives.where((item) {
      return item.name.toLowerCase().contains(q) ||
          item.lastMessagePreview.toLowerCase().contains(q) ||
          item.displaySize.toLowerCase().contains(q);
    }).toList();
  }

  String _dateLabel(DateTime value) {
    final now = DateTime.now();
    final sameDay = value.year == now.year && value.month == now.month && value.day == now.day;
    if (sameDay) {
      final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farooq Chat Viewer'),
        actions: [
          if (Platform.isWindows)
            IconButton(
              tooltip: 'Open conversations folder',
              onPressed: _loading ? null : _chooseFolder,
              icon: const Icon(Icons.folder_open_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rootPath == null
              ? _WelcomePane(onOpen: _chooseFolder)
              : wide
                  ? Row(
                      children: [
                        SizedBox(width: 390, child: _buildSidebar()),
                        const VerticalDivider(width: 1),
                        Expanded(child: _buildConversationPane()),
                      ],
                    )
                  : _selected == null
                      ? _buildSidebar()
                      : _buildConversationPane(),
    );
  }

  Widget _buildSidebar() {
    final visible = _visibleArchives;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search chats',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = visible[index];
                final selected = identical(item, _selected);
                return ListTile(
                  selected: selected,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: CircleAvatar(
                    child: Text(item.name.isEmpty ? '?' : item.name.characters.first.toUpperCase()),
                  ),
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.lastMessagePreview.isEmpty ? 'Archived conversation' : item.lastMessagePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_dateLabel(item.lastModified), style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(
                        item.displaySize,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  onTap: () => setState(() => _selected = item),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              '${_archives.length} archived chats • local & read-only',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationPane() {
    final item = _selected;
    if (item == null) {
      return const Center(child: Text('Select a chat to start reading'));
    }
    return Column(
      children: [
        Material(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(child: Text(item.name.characters.first.toUpperCase())),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_dateLabel(item.lastModified)} • ${item.displaySize} stored'),
            trailing: IconButton(
              tooltip: 'Share / Forward',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachment sharing is handled through the Windows/iOS share sheet.')),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF111B21)
                : const Color(0xFFEFE9E1),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('${item.displaySize} archive'),
                        const SizedBox(height: 8),
                        Text(
                          'The archive is loaded locally. Message parsing and media timeline rendering plug into this pane.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: Theme.of(context).colorScheme.surface,
          child: const Text(
            'Read-only archive — this is a viewer, not a sender.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _WelcomePane extends StatelessWidget {
  const _WelcomePane({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.chat_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text('Farooq Chat Viewer', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                const Text(
                  'Keep large exported chats safely on your computer and read them later without restoring them to your phone.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open conversations folder'),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Local • Read-only • Large-archive friendly',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
