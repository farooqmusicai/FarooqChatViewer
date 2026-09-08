# Farooq Chat Viewer — testing and maintenance handoff

**Prepared:** 8 September 2026. **Application:** 2.0.3+203. **Platform:** Windows x64. **Owner:** Mohammad Farooq.

## Current decision

The owner reports that the app is working fine and wants 1–2 days of testing. Preserve this version as the test baseline. Do not treat that report as final release approval. The immediate next step is to collect results from [TESTING.md](docs/TESTING.md), fix reproducible defects and rerun the relevant checks. No public binary release, signing or Store submission is part of this documentation handoff.

## What is complete

- Working Flutter Windows app, per-user Setup and portable test package.
- Folder and ZIP workflows, read-only transcript/media browsing, latest-message opening and folder-name cleanup.
- Chat-like photos, stickers, voice controls, videos and opt-in link previews.
- Windows share freeze fix using asynchronous file preparation and retained native payload lifetime.
- Media-aware previews, first-two-word initials, visible search results and play/pause state repair.
- Version 2.0.3: normalized full-content left search, saved parent-folder restoration until disconnect, and centered recognized WhatsApp system notices excluded from user-message statistics/search.
- Static analysis clean, 22 automated tests passing and Windows release build completed before this handoff. The documentation update does not change the tested runtime behavior.

The [README](README.md) is the public overview; [validation](docs/VALIDATION.md) records evidence boundaries. User-provided private archives and screenshots are not repository documentation assets.

## Baseline package identity

The existing owner test files are named `FarooqChatViewer-Setup.exe` and `FarooqChatViewer-Portable.zip`. Keep the whole portable folder after extraction; its executable needs companion DLLs and data. These hashes identify the already-built test packages, not a newly published GitHub release:

```text
3938FED37E95FAED3DC860A8E3A982F29CDFBAEF0C0C686031FA3DA8C483D758  FarooqChatViewer-Setup.exe
2E72E8AE07310FC5917D74E0C0F7FDE7A0A812FE23250377796CBDD914B5FF45  FarooqChatViewer-Portable.zip
```

Source and documentation can advance after these binaries. Any runtime fix requires a version bump, fresh tests/build/packages and replacement checksums. Do not relabel these old binaries as a newer build.

## Architecture and critical invariants

| Component | Responsibility and maintenance notes |
| --- | --- |
| `lib/main.dart` | Home/library state, saved preferences, search UI and actions. `archiveWorker` is a top-level isolate entry; do not capture widget state in worker messages. |
| `lib/archive.dart` | Parse common exported timestamps and multiline text, normalize search, calculate previews and classify system notices. Preserve original files and retained notice text. |
| `lib/media_widgets.dart` | Media rendering, bounded metadata caching, explicit online previews and player event subscriptions. Subscribe correctly when a player is already playing. |
| `lib/zip_import.dart` | Unique extraction root, validated paths, entry/size limits and failure cleanup. Never extract over the user's existing archive. |
| `windows/runner/media_preview.h` | Shell metadata work off the UI thread; completion is posted back to the window. |
| `windows/runner/flutter_window.cpp` | Native media/clipboard channels. |
| `packages/share_plus/windows/` | Required local plugin fixes; preserve this override until an upstream replacement has equivalent regression evidence. |

Sharing previously froze because file preparation blocked the UI thread and native collection lifetime was unsafe. The current path uses asynchronous StorageFile completion and DataRequest deferrals, heap-owned collections, callback cleanup and reset payload state. Do not reintroduce polling/sleep loops on the UI thread. Test repeated shares, cancellation and a missing file after changing this code.

The saved library path survives app restarts and temporary missing drives. Disconnect removes the preference, not archive files. Search indexes complete transcript text locally in memory, not media contents. System notice detection handles known English patterns and senderless export records; keep negative cases to prevent ordinary messages being swallowed.

## Reproduction and verification

Use Flutter 3.44.2 / Dart 3.12.2 with the committed lockfile and Visual Studio Desktop development with C++. See [BUILDING.md](docs/BUILDING.md) for exact standard commands and installer input/output paths. The tested build used `build-final` as Flutter's build directory; an older `build` directory must not accidentally be packaged.

Before a runtime handover: run analysis and tests, build the Windows release, verify the executable version, prepare runtime DLLs/notices, compile Setup, archive the complete portable payload and record SHA-256 hashes. Run the relevant native and playback diagnostics when those areas change. Unit/widget/native harness checks do not prove a receiving app accepted a share.

## Outstanding checks and risks

1. Owner's daily use: left search on older phrases, folder restoration after real desktop restart, disconnect/reconnect, system notice presentation, play/pause and repeated share cancellation.
2. Release environment: fresh installation, upgrade/uninstall, actual share destination acceptance, image clipboard paste, rendered video/fullscreen, codecs, cloud-drive loss and low disk.
3. Quality: current full-index memory/performance measurements, complete translations and accessibility at 200% scaling/screen reader.
4. Distribution: signing, complete third-party corresponding-source/runtime obligations and any Microsoft Store identity/migration work. macOS remains future work.

These are open checks, not confirmed bugs. Do not claim they passed from static analysis, screenshots or successful compilation alone.

## Next-session starting point

- Read this file, the current version and git status before changing anything.
- Ask for the owner's observed test failures only if none are already supplied; use the issue template in [TESTING.md](docs/TESTING.md).
- Reproduce with fictional minimal exports, preserve the working baseline, fix the smallest relevant behavior and run meaningful regressions.
- Update [CHANGELOG.md](CHANGELOG.md), validation and package identity only for actual new results.
- Keep public issues and fixtures free of private messages, contact names, archive paths and screenshots.

Owner test result: **pending**. Final release approval: **pending**. Follow-up date: after the owner's requested 1–2 days of testing; no automatic reminder is configured by this handoff.
