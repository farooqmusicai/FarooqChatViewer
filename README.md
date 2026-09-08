# Farooq Chat Viewer

**Farooq Chat Viewer** is a free, open-source Flutter app for **Windows and iOS** that lets people keep large exported WhatsApp conversations as long-term archives and read them later without restoring them to a phone.

> **Privacy first:** normal viewing is local and read-only. Farooq Chat Viewer does not sign in to WhatsApp, send or receive messages, or automatically upload chat archives. A user may explicitly choose **Share / Forward** on an attachment; Windows/iOS then hands that file to the operating-system share sheet, where WhatsApp or another installed app can be selected.

## Why this app exists

Some WhatsApp chats grow to hundreds of MB or several GB because they contain years of photos, voice notes, videos, PDFs, stickers and documents. Farooq Chat Viewer gives the user a simple archive workflow:

1. Open a single chat in WhatsApp.
2. Choose **Export chat** and, when required, **With all media**.
3. Save the generated ZIP to Windows, OneDrive, an external drive, or iOS Files.
4. On Windows, extract each ZIP into its own chat folder and place those folders inside one master **conversations** folder.
5. Open the master conversations folder in Farooq Chat Viewer.
6. The app scans every chat folder, finds `_chat.txt`, links its media, and shows all chats in one familiar desktop-style list.
7. After confirming the archive is safely stored, the user may decide to delete that single chat from the phone to recover mobile storage.

The screenshots used while designing this version include a real exported archive of about **3.5 GB**, so the product is intentionally designed around large local archives rather than tiny demo files.

## Flutter 2.0 goals

- Beautiful two-tone Windows/iOS design with light, dark and system themes.
- Windows: open a master **conversations** folder or one exported chat folder/ZIP.
- iOS: open exported ZIP archives from the Files picker.
- Conversation list with contact/chat name, latest message preview, **last chat date/time, and stored folder/archive size**.
- Search all loaded chats.
- Sender-side selection so the user can identify which participant is "Me".
- Date separators and familiar incoming/outgoing message bubbles.
- Text, emoji, links and deleted-message markers.
- Inline photos and stickers.
- Audio/voice-note playback.
- Video, PDF and document cards with open/save actions.
- Explicit Share / Forward action through the Windows/iOS share sheet.
- Read-only archive mode: the app never edits `_chat.txt` or the exported media.
- Large-archive friendly scanning: folder size is calculated without loading every media file into memory.
- Remember/reopen the last Windows conversations folder.
- Broad Windows locale support, automatic LTR/RTL, and English fallback for untranslated UI strings.

## New: archive size beside the date

Each chat row now has a place for **archive size** beside the latest chat date/time. This lets a user immediately see which chats are consuming the most disk space, for example:

`25 Jun 2026 · 3.50 GB`

The size represents the saved chat folder (or imported ZIP) including `_chat.txt` and exported media.

## Repository structure

- `lib/` – Flutter application source
- `docs/PRODUCT-GUIDE.md` – complete workflow and product behavior
- `docs/PRIVACY.md` – privacy model
- `docs/SUPPORT.md` – support/help information
- `docs/MICROSOFT-STORE.md` – guidance for updating the existing Microsoft Store product

## Build

Use current Flutter stable.

```powershell
flutter doctor
flutter pub get
flutter run -d windows
```

Windows release:

```powershell
flutter build windows --release
```

iOS development/build requires macOS + Xcode:

```bash
flutter pub get
flutter build ios --no-codesign
```

For App Store distribution, configure the Apple bundle identifier, signing team and provisioning in Xcode.

## Microsoft Store update

Keep the **existing Partner Center product identity** when replacing the old PWA package with the Flutter Windows package so existing users receive it as an update rather than a separate product.

## Trademark notice

Farooq Chat Viewer is an independent viewer for chat exports that users own. It is not affiliated with, endorsed by, or connected to WhatsApp LLC or Meta Platforms, Inc. WhatsApp is a trademark of its respective owner.

## License

Copyright © 2026 Mohammad Farooq. Released under the MIT License.
