# Support

Report a reproducible defect through [GitHub Issues](https://github.com/farooqmusicai/FarooqChatViewer/issues) or email babaqatar@gmail.com. Include version, Windows version, steps and expected/actual results. Use the [test report template](TESTING.md). Never attach private chat archives or unredacted screenshots to public issues.

| Symptom | What to check |
| --- | --- |
| No conversations | Select the parent folder containing extracted chat folders and text transcripts; a ZIP still needs importing/extracting. |
| Saved folder unavailable | Reconnect the drive or make the cloud folder available locally, then retry. The saved connection is kept until disconnect. |
| Wrong dates | Compare original timestamps and choose the correct numeric date order. |
| Search seems unexpected | A left-panel result can match an older message. Open it and inspect the message result list; clear filters to restore normal browsing. |
| Missing media | Preserve original filenames and transcript/media placement; check that WhatsApp included the file in the export. |
| No thumbnail/duration | Windows codec/metadata support varies. Try playback or an appropriate external application. |
| Missing share target | Windows decides available destinations based on installed/configured apps and payload type. |
| Share freezes | Record the app version, payload type and repeat/cancel steps. Version 2.0.1 introduced the native freeze fix; verify you opened the current executable. |
| Online preview fails | The site may block metadata requests; the original clickable link remains available. |

Current status is owner testing, not a guarantee that every export locale, codec or Windows configuration is supported. See [known limits and evidence](VALIDATION.md).

## Dedicated website

Prepared page: https://www.mymandoob.com/chatviewer/support.html

Local website source: [`../chatviewer/support.html`](../chatviewer/support.html). Website upload and live verification are pending as of 9 September 2026.

Support: babaqatar@gmail.com · Developer: https://www.farooqmusic.com/
