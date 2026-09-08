# Farooq Chat Viewer — Product Guide

## Purpose

Farooq Chat Viewer is for people who have very large WhatsApp conversations and want to keep them as readable archives on Windows or iOS without keeping the entire chat on the phone forever.

The app is not a WhatsApp replacement, messenger, synchronizer or backup service. It is a **local archive viewer** for exported chats owned by the user.

## Real-world workflow

### 1. Export one chat from WhatsApp
Open WhatsApp, choose the chat to archive, then go to the chat export option. When the media matters, choose **With all media**. WhatsApp creates an export containing `_chat.txt` plus available media files such as images, stickers, audio, video, PDFs and other documents.

### 2. Save the ZIP safely
The exported ZIP can be saved to Windows, OneDrive, an external hard drive, or iOS Files. Large archives are expected; the design reference includes a chat export around 3.5 GB.

### 3. Windows archive layout
For the best Windows experience, extract every exported chat into its own folder and place all chat folders inside one parent folder named, for example, `conversations`.

Example:

```text
conversations/
  WhatsApp Chat - AbdulRahman Mughal/
    _chat.txt
    00000002-STICKER....webp
    00000006-AUDIO....opus
    00000024-PHOTO....jpg
    ...
  WhatsApp Chat - Tahira Jabeen/
    _chat.txt
    ...
  WhatsApp Chat - M Sarfraz/
    _chat.txt
    ...
```

Farooq Chat Viewer opens the parent folder, scans the chat folders and builds one conversation list.

### 4. iOS archive workflow
On iPhone/iPad, use the Files picker to select an exported ZIP. The app imports it into its own local working area, reads `_chat.txt`, links the contained media and shows the conversation in the same viewer experience.

### 5. Verify before deleting from the phone
The user should open the archived chat in Farooq Chat Viewer and verify that the conversation and important media are readable. Only after verifying the archive should the user decide whether to delete the original chat from the phone to recover storage.

Farooq Chat Viewer never deletes chats from the phone and never performs that decision automatically.

## Conversation list

Each row should show:

- chat/contact name;
- latest message preview;
- last chat date/time;
- **stored archive size**;
- avatar/initials;
- media indicator where useful.

Example:

```text
M Sarfraz
🎤 Audio
4:24 PM · 3.50 GB
```

The archive size is the total size of the saved chat folder, including `_chat.txt` and all exported media. For a ZIP import, the app can show the ZIP size and, after import, the extracted archive size.

## Chat viewer behavior

The desktop layout uses a two-pane design: chats on the left and the selected conversation on the right. The selected chat header shows its name, message count/date range and sender-side selector.

The viewer supports:

- incoming and outgoing message bubbles;
- date separators;
- text and emoji;
- clickable links;
- deleted-message markers;
- photos and stickers;
- audio/voice-note playback;
- videos;
- PDFs and documents;
- save/download actions;
- search;
- jump/scroll controls.

## Share / Forward

Viewing is offline. When the user explicitly chooses **Share / Forward**, Farooq Chat Viewer passes the selected attachment to the operating-system share sheet.

If WhatsApp Desktop is installed/connected on Windows, or WhatsApp is available on iOS, the user can choose it as the target. Other compatible apps can also appear. Farooq Chat Viewer itself does not send the message and does not connect to the user's WhatsApp account.

## Privacy model

- No WhatsApp sign-in.
- No automatic upload.
- No cloud database required.
- No chat analytics required.
- No modification of `_chat.txt`.
- No modification of exported media.
- Files remain under user control.
- External sharing occurs only after an explicit user action.

## Large archive design

The app should not read every media file into memory just to calculate folder size. It walks file metadata and sums file lengths. Parsing `_chat.txt` is separate from media rendering, and media should be loaded lazily when it becomes visible or is opened.

This is important for archives measured in gigabytes.

## Languages

The UI follows the operating-system language when supported and provides a manual language selector. LTR/RTL layout is automatic. Chat content is displayed as stored, including mixed Urdu, Arabic, English and other Unicode text.

English is the safe fallback when a UI translation is not yet available.

## Independence notice

Farooq Chat Viewer is an independent viewer for chat exports that users own. It is not affiliated with, endorsed by, or connected to WhatsApp LLC or Meta Platforms, Inc. WhatsApp is a trademark of its respective owner.
