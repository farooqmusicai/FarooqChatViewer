# Farooq Chat Viewer

**Farooq Chat Viewer** is a free, open-source Flutter desktop app for **Windows and macOS** that lets people keep large exported WhatsApp conversations as long-term archives and read them later without restoring them to a phone.

> **Privacy first:** normal viewing is local and read-only. Farooq Chat Viewer does not sign in to WhatsApp, send or receive messages, or automatically upload chat archives. A user may explicitly choose **Share / Forward** on an attachment; Windows or macOS then hands that file to the operating-system sharing/open-with system, where WhatsApp Desktop or another installed app can be selected when available.

## Why this app exists

Some WhatsApp chats grow to hundreds of MB or several GB because they contain years of photos, voice notes, videos, PDFs, stickers and documents. Farooq Chat Viewer gives the user a simple archive workflow:

1. Open a single chat in WhatsApp.
2. Choose **Export chat** and, when required, **With all media**.
3. Save the generated ZIP to the computer, OneDrive/iCloud Drive, an external drive, or another local storage location.
4. Extract each ZIP into its own chat folder and place those folders inside one master **conversations** folder.
5. Open the master conversations folder in Farooq Chat Viewer.
6. The app scans every chat folder, finds `_chat.txt`, links its media, and shows all chats in one familiar desktop-style list.
7. After confirming the archive is safely stored, the user may decide to delete that single chat from the phone to recover mobile storage.

The screenshots used while designing this version include a real exported archive of about **3.5 GB**, so the product is intentionally designed around large local archives rather than tiny demo files.

## Flutter 2.0 desktop goals

- Beautiful two-tone **Windows + macOS** desktop design with light, dark and system themes.
- Open a master **conversations** folder, one exported chat folder, or a supported exported ZIP workflow.
- Conversation list with contact/chat name, latest message preview, **last chat date/time, and stored folder/archive size**.
- Search loaded chats.
- Sender-side selection so the user can identify which participant is "Me".
- Date separators and familiar incoming/outgoing message bubbles.
- Text, emoji, links and deleted-message markers.
- Inline photos and stickers.
- Audio/voice-note playback.
- Video, PDF and document cards with open/save actions.
- Explicit Share / Forward action through the operating system; WhatsApp Desktop can be used when installed/connected and supported by the OS sharing/open mechanism.
- Read-only archive mode: the app never edits `_chat.txt` or exported media.
- Large-archive-friendly scanning: folder size is calculated without loading every media file into memory.
- Remember/reopen the last conversations folder.
- Broad locale support, automatic LTR/RTL, system-language detection, and English fallback for untranslated UI strings.

## Archive size beside the date

Each chat row has a place for **archive size** beside the latest chat date/time. This lets a user immediately see which chats are consuming the most disk space, for example:

`25 Jun 2026 · 3.50 GB`

The size represents the saved chat folder (or imported archive where applicable), including `_chat.txt` and exported media.

## Repository structure

- `lib/` – shared Flutter application source
- `windows/` – generated/configured Windows desktop runner (when platform scaffolding is committed)
- `macos/` – generated/configured macOS desktop runner (when platform scaffolding is committed)
- `docs/PRODUCT-GUIDE.md` – complete workflow and product behavior
- `docs/PRIVACY.md` – privacy model
- `docs/SUPPORT.md` – support/help information
- `docs/MICROSOFT-STORE.md` – guidance for updating the existing Microsoft Store product

## Build

Use current Flutter stable.

### Windows

```powershell
flutter doctor
flutter pub get
flutter run -d windows
flutter build windows --release
```

### macOS

A Mac with Xcode and Flutter is required:

```bash
flutter doctor
flutter pub get
flutter run -d macos
flutter build macos --release
```

For Mac App Store distribution, configure the macOS bundle identifier, signing, entitlements and App Store packaging on macOS/Xcode. **This project is targeting macOS desktop, not iPhone/iPad iOS.**

## Microsoft Store update

Keep the **existing Partner Center product identity** when replacing the old PWA package with the Flutter Windows package so existing users receive it as an update rather than a separate product.

## Trademark notice

Farooq Chat Viewer is an independent viewer for chat exports that users own. It is not affiliated with, endorsed by, or connected to WhatsApp LLC or Meta Platforms, Inc. WhatsApp is a trademark of its respective owner.

## License

Copyright © 2026 Mohammad Farooq. Released under the MIT License.
