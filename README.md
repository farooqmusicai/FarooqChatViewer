# Farooq Chat Viewer

A free, open-source Windows desktop app for reading exported WhatsApp conversations and their saved media in a familiar chat layout.

**Current version: 2.0.3 (build 203). Status: owner testing, 8 September 2026.** The owner reports that the app is working and is allowing another 1–2 days for everyday testing. This is not a completed public-release sign-off. Windows is implemented; macOS is a future target and has no working runner in this repository.

[User guide](docs/PRODUCT-GUIDE.md) · [Testing checklist](docs/TESTING.md) · [Maintainer handoff](HANDOFF.md) · [Build instructions](docs/BUILDING.md) · [Privacy](docs/PRIVACY.md) · [Validation](docs/VALIDATION.md) · [Changes](CHANGELOG.md)

## Website, support and Store preparation

The dedicated website source is in [`chatviewer/`](chatviewer/index.html). Upload that folder to `public_html/chatviewer/` on MyMandoob. The following are the intended public URLs; website upload and live verification remain pending as of 9 September 2026.

| Page | URL |
| --- | --- |
| App home | https://www.mymandoob.com/chatviewer/ |
| How to use | https://www.mymandoob.com/chatviewer/how-to-use.html |
| Support | https://www.mymandoob.com/chatviewer/support.html |
| Privacy policy | https://www.mymandoob.com/chatviewer/privacy.html |
| Terms and conditions | https://www.mymandoob.com/chatviewer/terms.html |
| Developer | https://www.farooqmusic.com/ |

**Support email:** babaqatar@gmail.com. Do not send private archives or unredacted screenshots. Every website page links to the other pages and the developer website. The HTML pages are also printable from a browser.

See the [complete Publisher guide](docs/MICROSOFT-STORE-PUBLISHER-GUIDE.html) and [copy-ready listing fields](docs/store-listing.json) for the Microsoft Partner Center update. The website uses the existing app icon and local assets without external scripts or fonts. The home-page conversation is explicitly labeled as an illustration, not an app screenshot.

The **2.0.3.0 x64 Store MSIX is built** from the unchanged 2.0.3+203 portable payload. Its identity is `MohammadFarooq.FarooqChatViewer`, publisher `CN=88632D82-E648-416A-A69B-DD8EADB81121`, and publisher display name `Mohammad Farooq`, using the owner's supplied Partner Center values. Store product: [9NVWJ7M80940](https://apps.microsoft.com/detail/9NVWJ7M80940). The old neutral PWA package was reported as 1.0.1.0; the new package has a higher version and targets x64 desktop.

Windows SDK packaging/extraction and independent checks passed: 43 baseline files unchanged and 1,306 block hashes verified. See [package validation](docs/MSIX-VALIDATION-2.0.3.0.json) and [manifest](installer/msix/AppxManifest.xml). The required upload artifact is **`FarooqChatViewer-Microsoft-Store-2.0.3.0-x64.msixbundle`**, SHA-256 `1E1FA568850FCD0E4B00BFCC41CBB6CE87FFD16AF19B1873DCEAE1DF9584A5A3`. Partner Center requires this product to remain bundled because its first release was a bundle, as reported by the owner. The bundle version is 2.0.3.0 and contains one unchanged x64 MSIX (inner SHA-256 `83D7FCA49A057E3B9E03C4AD9595CEEADADB827CEAEE49058C7425267E89AA67`). Local bundle integrity and manifest validation passed. Bundle upload remains pending. It was delivered locally to the owner; this commit does not publish a binary download.

No Store submission, packaged-installation test, PWA-to-Flutter upgrade test or certification is claimed. Check old PWA data/launch behavior, retained packages for other architectures, actual app screenshots and the existing third-party distribution obligations before release. The Store product link does not mean that 2.0.3.0 is already available. Website upload/live verification remain pending. Microsoft signs Store-distributed MSIX packages; this unsigned upload file is not a direct-install package. The existing Setup and app binary are unchanged.

## What the app does

Keep exported conversations on your computer, open a parent folder containing multiple chats, and browse messages, photos, stickers, voice notes, videos and documents without restoring a phone backup.

The app reads the exports you select. It does not connect to a WhatsApp account, recover messages missing from an export, synchronize live conversations or send messages itself. Sharing is an explicit handoff to Windows and another installed application. Farooq Chat Viewer is an independent project, not affiliated with or endorsed by WhatsApp or Meta.

## Features available now

| Area | Current behavior |
| --- | --- |
| Conversation library | Open a parent folder or individual export folder; import ZIP exports into a new folder. |
| Remembered folder | Reopen the selected library at startup until the user disconnects it or selects another folder. Disconnect never deletes archives. |
| Chat list | Folder-based display names with the `WhatsApp Chat -` prefix removed; initials from the first two name words; latest user-message date, media preview and stored size. |
| Reading | Open at the latest user message, scroll through dated bubbles, choose which sender represents Me. |
| Search | Left panel searches conversation names and indexed message content. Opening a content match exposes matching messages, including older messages. Search inside an open chat shows results and navigation. |
| WhatsApp notices | Recognized encryption, security-code and disappearing-message notices appear as centered system cards. They are retained but excluded from user-message counts, previews, latest dates and user-message search. |
| Photos and stickers | Inline photos, captions and transparent sticker presentation; media-specific chat-list previews. |
| Voice and audio | Play/pause/resume, progress, duration and playback speed. The waveform decoration is stylized, not measured audio amplitude. |
| Video | Playable video cards with duration and a thumbnail when local Windows codecs can provide one. |
| Links | Clickable links and local link cards; online metadata/image previews load only when requested. |
| Sharing and copies | Per-message share actions for text, links and saved attachments, plus applicable copy/save actions. Available share destinations depend on Windows and installed apps. |
| Appearance | Light, dark and system themes; RTL text and partial Urdu/Arabic interface translations with English fallback. |
| Archive integrity | Reading does not modify source transcripts/media. ZIP extraction creates a separate destination and rejects unsafe paths. |

## Getting started

The Windows installer and portable package have been prepared for the owner's local test. This documentation update does not publish a downloadable binary release. Developers can build the source using [BUILDING.md](docs/BUILDING.md).

The current package targets **Windows 10 version 2004/build 19041 or later, x64**, including Windows 11. Actual development validation used Windows 11. Other architectures and clean-machine compatibility are not yet certified.

1. Export a conversation from WhatsApp, including media if needed. Only messages and files included by WhatsApp can be displayed.
2. Extract each export into its own folder, keeping its transcript and media together. Alternatively, use the app's ZIP import.
3. Place chat folders in a parent folder such as `Conversations`.
4. Open that parent folder in Farooq Chat Viewer. It can have any name.
5. Select a chat. The reader starts at its latest user message. Use search to find older content.
6. Close and reopen the app to confirm that your library is remembered. Use Disconnect folder when you want to remove that saved connection.

Example using fictional names:

```text
Conversations/
  WhatsApp Chat - Alex Morgan/
    _chat.txt
    photo.jpg
    voice.opus
  Family Group/
    chat.txt
    video.mp4
```

The first chat is displayed as **Alex Morgan**. Preserve exported filenames so attachment references continue to resolve. Cloud folders and removable drives must be available locally; online-only media may require the storage provider to download it.

## Search, dates and archive sizes

The left search looks through chat names and a local in-memory index of user-message content. It normalizes case, repeated whitespace and invisible direction marks. A match can come from an older message even when the latest-message preview contains different text. Inside a chat, use the visible result list to navigate to the matching message.

Supported export parsing includes common Android and iPhone numeric timestamp formats, multiline messages, AM/PM times and RTL content. Ambiguous numeric dates can require the date-order setting. Export formats vary by language and WhatsApp version; warnings and missing attachments should be checked against the original export.

The date beside a chat is its latest parsed user-message date, not the date the folder was copied. The size describes stored archive files, not a voice-note duration. Audio duration is shown when metadata is available. Media bytes are not all loaded into memory during scanning, but the full transcript search index does consume memory.

## Privacy and data handling

Normal reading and searching are local. There is no app account, archive-upload backend, analytics or automatic link preview fetching. The selected path and interface preferences are saved in the Windows user's app preferences. The in-memory search index is not sent to a search service.

Choosing an online preview contacts that site and possibly its image host. Opening a URL, sharing a file, using the clipboard or storing exports in a synced folder involves Windows, the destination app or the storage provider. Exported files are not encrypted by this viewer. See [PRIVACY.md](docs/PRIVACY.md) for the complete behavior.

Keep an independent archive copy and check important messages/media before removing anything from a phone. A text export is not a restorable WhatsApp account backup.

## Known limitations and release status

- Export omissions cannot be reconstructed. Unknown localized system notices may still need parser rules.
- Windows share targets, thumbnail generation and codec support vary by machine. Receiving-app delivery still needs live acceptance testing.
- Online previews can fail when sites block requests or omit metadata.
- Very large transcripts need a fresh memory/performance measurement with the current full-text index. Historical benchmark timings are not current performance guarantees.
- ZIP import has extraction limits and path checks, but no free-disk-space preflight.
- Complete translations, comprehensive accessibility/scaling checks and macOS support remain unfinished.
- Clean-machine install/upgrade/uninstall, signing, public binary licensing preparation and Microsoft Store submission are separate release tasks.

The 2.0.3 Windows release compiled and **22 automated tests passed**, with no static-analysis issues. These checks do not replace the owner's live testing. [VALIDATION.md](docs/VALIDATION.md) distinguishes automated, native, visual and still-pending checks.

## Development and repository map

The validated toolchain was Flutter 3.44.2, Dart 3.12.2 and Visual Studio Community 2026 with Desktop development with C++. Keep `pubspec.lock` and the local `share_plus` override when reproducing the build.

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

See [BUILDING.md](docs/BUILDING.md) for release packaging, native checks and runtime files.

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | Library state, preferences, search/navigation, reader and user actions. |
| `lib/archive.dart` | Export parsing, library scanning, notices, search normalization and previews. |
| `lib/media_widgets.dart` | Photo/sticker/audio/video/link presentation and metadata handling. |
| `lib/zip_import.dart` | Bounded ZIP extraction and path validation. |
| `windows/runner/` | Desktop host, asynchronous local metadata and image clipboard support. |
| `packages/share_plus/` | Vendored sharing plugin with required Windows freeze/lifetime fixes. |
| `test/` | Parser, import, preferences, search and media regression tests with fixtures. |
| `tool/` | Additional media, native-share and benchmark diagnostics. |
| `installer/windows.iss` | Per-user Windows Setup configuration. |
| `docs/` | User, privacy, testing, build and licensing documentation. |

## Support and contributions

Report reproducible problems in [GitHub Issues](https://github.com/farooqmusicai/FarooqChatViewer/issues), or email **babaqatar@gmail.com**. Include app version, Windows version, steps, expected/actual behavior and a sanitized example. Never attach private archives or unredacted chat screenshots to a public issue. See [SUPPORT.md](docs/SUPPORT.md).

During owner testing, prioritize reproducible defects in search, persistence, media and sharing. Preserve source-file integrity and add focused regression coverage for behavioral changes. Use fictional fixtures in contributions.

## License

Application code is covered by [MIT](LICENSE); dependencies retain their own licenses. The Windows media stack includes separately licensed libmpv components. Read [THIRD-PARTY-NOTICES.md](docs/THIRD-PARTY-NOTICES.md) and complete corresponding-source/runtime redistribution checks before publishing binaries. The repository being public does not by itself complete binary-distribution obligations.
