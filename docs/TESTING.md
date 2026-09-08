# Owner testing — version 2.0.3

Allow 1–2 days of ordinary use. The owner reported the app working on 8 September 2026; the checks below remain open until actually exercised. Keep the current working packages as a baseline.

## Day 1: everyday use

- [ ] Open the parent Conversations folder; confirm all expected exported chats appear.
- [ ] Close the app fully and reopen. The same folder should reconnect without a picker.
- [ ] Open several chats. Each should start at its latest user message.
- [ ] Search a chat name in the left panel, then an exact phrase found only in an older message. Open the result and check the matching message is visible.
- [ ] Try different case, repeated spaces, Urdu/Arabic text and a phrase with no match. Clear search and return to the normal list.
- [ ] Check initials, folder names, voice/sticker last-message previews, dates and stored sizes against the export.
- [ ] Check security-code, encryption and disappearing-message notices. They should appear as system cards and should not replace user-message previews.
- [ ] Play, pause and resume several voice notes; verify the icon follows playback. Try seeking and speed changes.
- [ ] Open photos, transparent stickers, captions, video and a document. Check missing-file behavior using a disposable copy of an export.

## Day 2: restart, sharing and edge cases

- [ ] Open Windows Share for text, a link and an attachment. Cancel and repeat several times; the viewer should remain responsive.
- [ ] If desired, share a harmless sample to an intended destination and confirm that the receiving app accepts it. Record which destination was tested.
- [ ] Paste a copied image into another app and save a media copy to a separate folder.
- [ ] Disconnect the library, close/reopen, and confirm it stays disconnected. Select another folder and confirm that the new selection is remembered.
- [ ] On a disposable library, temporarily disconnect its drive and retry after reconnecting; files should remain untouched.
- [ ] Import a sample ZIP into a separate destination. Check messages/media and confirm the original ZIP is unchanged.
- [ ] Check a large conversation, rapid chat switching, video seeking/fullscreen, dark mode, narrow window and 200% display scaling.
- [ ] Load a link normally, then explicitly request an online preview. Sites without preview metadata should fail gracefully.

## Record an issue

```text
App version:
Windows version:
Feature and archive type (folder/ZIP/local/cloud):
Steps to reproduce:
Expected result:
Actual result:
Does it repeat after closing/reopening?:
Sanitized sample or screenshot, if available:
```

Use fictional sample messages when sharing publicly. Do not upload your full chat archive. Report a freeze, lost connection or incorrect search result with the exact action immediately before it happened.

## Completion record

Testing dates: pending. Tested Windows/share destinations: pending. Remaining issues: pending. Owner acceptance: pending.

Successful owner testing does not itself certify clean-machine installation, signing, Store acceptance or dependency redistribution compliance; those release checks are recorded in [VALIDATION.md](VALIDATION.md).
