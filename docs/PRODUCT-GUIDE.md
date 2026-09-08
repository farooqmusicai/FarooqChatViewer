# User guide

Applies to Windows test version 2.0.3. See the [README](../README.md) for platform and release status.

## Connect your conversations

Export each chat from WhatsApp and keep its text transcript and media together. Place separate chat folders under one parent folder, then open that parent in the viewer. You can also select one chat folder. For ZIP import, choose the archive and destination; the app creates a unique child folder instead of overwriting an existing archive.

The folder connection is remembered when the app closes. Selecting a different folder replaces it. Disconnect folder removes the saved connection only. If a drive is temporarily missing, reconnect the drive and retry; the saved path is retained. Files in cloud storage need to be available locally.

## Read a chat

The displayed name comes from its folder, with the common WhatsApp export prefix removed. Initials use the first letters of the first two name words; a single-word name has one initial. Select a chat to open at the newest user message. Choose Me to align your messages separately from other senders. Scroll or search for earlier history.

Photos and stickers display inline when their saved files are available. Voice notes have play/pause, progress and speed controls. Videos use local playback and, when available, Windows thumbnail metadata. Missing or unsupported media can require checking the original export or opening a supported file with another installed application.

System cards represent recognized WhatsApp notices such as encryption, changed security codes and disappearing-message settings. They remain in the transcript but do not count as user messages or replace the chat-list preview. An export containing only notices has no user-message preview to invent.

## Find older messages

Type a name or message phrase in the left search. Content search can match messages from any indexed date. Select a matching conversation and use its result list to open a matching message. The open-chat search supports sender/body matching, result navigation and an explicit no-results state. Clear the query to return to normal browsing.

If dates look reversed, review the date-order setting. A numeric date such as 06/07 can mean June 7 or July 6 depending on the exporter. Compare several unambiguous dates before choosing an override.

## Share, copy and save

Use the share arrow for a message or saved attachment. Windows lists compatible destinations installed/configured on your machine; their order and availability are controlled by Windows. Select a destination and finish within that app, or cancel. The viewer does not independently send a WhatsApp message.

Copy/save actions apply to the selected content. Save creates a separate copy outside the connected chat folder. Opening links or loading an online preview is an explicit external action. Link previews do not load automatically while reading.

## Understand the chat list

The latest date comes from parsed user messages. System notices are excluded. Media previews use labels/icons such as Sticker or voice/audio information instead of exposing attachment markers where recognized. Audio metadata can take time or be unavailable. The stored size alongside the date refers to archive files, not audio duration.

## Protect and check your archive

The viewer cannot display messages or media WhatsApp omitted from its export. It does not decrypt account backups or restore exports into WhatsApp. Keep an independent copy, verify important dates and media, and review any parsing warnings. Disconnecting the library never deletes it.

For troubleshooting, see [Support](SUPPORT.md). For the current owner review, use the [1–2 day checklist](TESTING.md).
