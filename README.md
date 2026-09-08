# Farooq Chat Viewer

**Farooq Chat Viewer** is a free, open-source Windows desktop application for reading chat archives exported from WhatsApp without restoring them to a phone.

> Privacy first: the app is read-only. It does not sign in to WhatsApp, send or receive messages, connect to a WhatsApp account, or upload exported chats. Files are opened and processed locally on the user's Windows PC.

## Flutter Desktop Edition 2.0

This repository is the native Flutter/Windows successor to the earlier single-page/PWA Store app.

### Features
- Open an exported chat ZIP directly from Windows.
- Native two-pane desktop chat layout with a modern two-tone design.
- Multi-line message parsing, sender detection, search and sender-side selection.
- Inline image preview and Windows opening for other exported attachments.
- Light, dark and system theme modes.
- Windows-language-aware UI with the complete Windows 11 language pack + Language Interface Pack locale catalog.
- Curated English, Urdu and Arabic app translations in this release; every other Windows locale is accepted and safely falls back to English until its app strings are translated.
- Automatic RTL handling for Arabic, Urdu, Persian, Hebrew, Kurdish, Punjabi (Arabic), Sindhi, Dari and Uyghur.
- Manual language selection can expose the full Windows locale catalog, while System mode follows the Windows preferred display language.
- Local/read-only processing: no sign-in, cloud sync, analytics or upload.

## How to use
1. In WhatsApp, open the chat you want to archive.
2. Choose **Export chat**, with or without media.
3. Copy/save the ZIP file to your PC or an external drive.
4. Open **Farooq Chat Viewer**.
5. Click **Open exported chat ZIP**.
6. Select the ZIP. The app extracts a temporary local working copy, finds `_chat.txt`, parses the conversation and links available media.
7. Search messages or choose which sender should appear as your messages.

## Build on Windows
Requirements: Windows 10/11 x64, Flutter stable, and Visual Studio 2022 with **Desktop development with C++**.

```powershell
flutter doctor
flutter pub get
flutter create . --platforms=windows
flutter run -d windows
```

Release build:

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

The normal output is under `build\\windows\\x64\\runner\\Release\\`.

## Microsoft Store update
Use the **same Partner Center product identity** as the existing Store listing when replacing the PWA package with this native desktop package. See [docs/MICROSOFT-STORE.md](docs/MICROSOFT-STORE.md).

## Documentation
- [Privacy](PRIVACY.md)
- [Support](docs/SUPPORT.md)
- [Help / How to use](docs/HELP.md)
- [Microsoft Store update](docs/MICROSOFT-STORE.md)
- [Website copy](docs/WEBSITE-COPY.md)

## Trademark notice
Farooq Chat Viewer is an independent viewer for chat exports that users own. It is not affiliated with, endorsed by, or connected to WhatsApp LLC or Meta Platforms, Inc. WhatsApp is a trademark of its respective owner.

## License
Copyright © 2026 Mohammad Farooq. Released under the MIT License.

## Windows language support

The locale catalog in `lib/windows_locales.dart` follows Microsoft Learn's current Windows 11 full language packs and Language Interface Packs. Windows uses BCP-47-style language tags and can have regional/script variants. The app accepts those locales, preserves RTL direction where required, and falls back to English for any UI string that has not yet received a human-reviewed translation.
