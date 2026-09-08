# Validation — 8 September 2026

**Current baseline: 2.0.3+203; 22 automated tests passed, static analysis clean, Windows release built.** Owner reports the app working and has requested 1–2 days of testing. Final acceptance remains pending. Earlier sections below are historical evidence, not additional claims about the final build. See [TESTING.md](TESTING.md).

## Historical initial-build evidence

- Flutter/Dart static checks and unit/widget tests were run locally.
- Twelve tests cover iPhone/Android timestamps, AM/PM, RTL text preservation, multiline content, ambiguity override, invalid dates, original-byte preservation, size/date semantics, multiple transcripts, ambiguous attachments, unsafe ZIP paths, extraction and live background-worker UI navigation/search/narrow Urdu layout.
- The actual Windows executable launched and its native welcome, Help/Licenses and reader were inspected. The owner opened a real library: eight conversations, including a displayed 3.59 GB conversation containing 10,374 parsed messages. This observation does not prove completeness against the phone.
- Historical synthetic benchmark (before the current full-text search index; remeasurement required): 3,590,000,000 logical bytes, 25,000 messages. Scan 1,147 ms, parse 911 ms, one-match search 6,142 microseconds, process RSS approximately 237 MB. The large synthetic file was not a playable video; these timings are not measurements of the owner's real archive.
- Muted libmpv tests exercised WAV, OPUS and MP4 playback advancement, duration, pause, seek and 1.5x speed. No decoder errors were reported. This is not an audible listening check or a rendered-video visual check.
- Widget layout tests cover narrow Urdu mode. Widget capture uses test fonts and is not a production screenshot.

## Remaining release checks

Fresh clean-machine installation, upgrade/uninstall lifecycle, live Windows share destination acceptance, clipboard image paste in another app, rendered-video/fullscreen behavior, full codec inventory, low-disk preflight, disconnected cloud drives, measured offline process-network observation and comprehensive screen-reader/200% scaling tests remain separate from source checks. No claim that all handoff acceptance criteria are finished.

Windows Setup signing and existing Store identity/migration require release inputs. macOS and complete translation coverage are outstanding. No private handoff screenshots or original chats are included in distributable files.

## Requested updates verified

The 12-test suite passes after the latest-message initial position, folder display-name cleanup, visible share arrow and text-sharing payload checks. Static analysis reports no issues. The final Windows release built successfully, launched and was visually inspected with the updated arrows and names. The share_plus Windows plugin is vendored with payload reset and callback cleanup; actual receiving-app delivery remains unverified. Setup compiled successfully; a clean-machine installation has not been exercised.

## Version 2.0.1 checks

- 16 Flutter unit/widget tests pass. Static analysis has no issues. Tests cover media captions, compact voice/video cards, online-preview opt-in, decoded photos/stickers, latest-message position and share payloads.
- Native WinRT regression: 11 repeated asynchronous file preparations retained valid collections after the helper callback lifetime; missing-file preparation completed with a failure. Dispatch took 0-16 ms. This uses a test DataRequest around real Windows StorageFile/DataPackage APIs, not a receiving app.
- A rendered widget layout with Segoe UI and Material icons was inspected. Fixtures are synthetic; video metadata was mocked in the widget test. Real desktop control was unavailable (native pipe missing), so live share-sheet cancellation/repetition and receiving-app acceptance remain unverified for 2.0.1.
- Windows video thumbnail/duration support depends on local shell codecs. The voice seek decoration is stylized rather than an extracted amplitude waveform. Link preview loading is explicit and can fail for sites that block metadata requests.

## Version 2.0.2 checks

19 tests cover the earlier suite plus Unicode/name initials, sticker row previews, and play/pause/resume state including the initial attachment of an already-playing player. Reader tests check visible search result rows and no-result feedback. UI tests use mocked playback events and metadata; live desktop behavior is not claimed as verified.

## Version 2.0.3 checks

22 automated tests pass. New tests verify startup restoration from saved preferences; normalized left-panel content search and opening an older match; disconnect persistence across widget restarts; known notice classification with ordinary-text negative cases; and excluding system records from user counts, latest dates, previews and search. System records remain retained in the parsed transcript. Desktop app restart was simulated through fresh widget instances; no additional live desktop claim is made.
