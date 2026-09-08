# Build and package Windows

## Validated environment

The 2.0.3 test build used Flutter 3.44.2, Dart 3.12.2, Visual Studio Community 2026 18.9.2 with Desktop development with C++, Windows SDK 10.0.26100.0 and Inno Setup 6.7.3. The app targets Windows x64; the installer requires Windows build 19041 or later. Building requires the C++ toolchain, Windows SDK and CMake tools reported by `flutter doctor -v`.

## Run checks and build

From the repository root on Windows:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter config --build-dir=build-final
flutter build windows --release
```

Keep `pubspec.lock` to reproduce dependency resolution. The `share_plus` dependency override points to `packages/share_plus`, which contains essential Windows fixes. Do not remove it or replace it with the unpatched package casually. Dependency downloads and native media build assets require network access on a fresh setup.

The release payload is `build-final/windows/x64/runner/Release/`. Run `farooq_chat_viewer.exe` there with all companion DLLs/data present. Flutter's build-dir setting affects later builds in that Flutter configuration; reset it if your other projects expect the default.

## Prepare distribution files

Bundle the appropriate unmodified x64 Visual C++ runtime redistributable DLLs under Microsoft's redistribution terms, or provide a separately managed runtime prerequisite. The owner package used Visual Studio's `VC/Redist/MSVC/14.51.36231/x64/Microsoft.VC145.CRT` files. Installed versions and paths may differ; do not copy debug runtimes.

Include the application license, privacy information, third-party notices and required dependency licenses with the payload. Review libmpv corresponding-source obligations before public distribution. The owner test binary is unsigned; public signing remains a separate task.

Compile `installer/windows.iss` with Inno Setup. It reads the `build-final` payload, installs per user under LocalAppData Programs, creates a Start menu entry and offers an optional desktop shortcut. The script's existing output path is `../../../outputs` relative to `installer/`, inherited from the original workspace layout. Override it for an ordinary clone:

```powershell
ISCC.exe /O"dist" installer/windows.iss
```

Use an absolute output path if the compiler's working directory differs. Archive the complete prepared release folder for the portable package; an executable alone is insufficient. Keep installer version and `pubspec.yaml` version aligned when producing a new build. Record SHA-256 hashes for every delivered package.

## Additional diagnostics

`tool/media_test.dart` exercises local media playback with supplied sample files. `tool/share_native_test.cpp` is a Windows C++/WinRT harness for asynchronous file-share preparation and collection lifetime. It needs an initialized MSVC developer environment, Windows SDK headers/libraries and the local patched plugin headers. These are developer diagnostics, not automatic proof of live share destination delivery.

`tool/benchmark.dart` creates a synthetic workload. Run it only in a disposable directory with sufficient storage. Historical timings were measured before the current full-text index; remeasure current builds before making performance claims.

## Release gate

Check clean-machine installation, upgrade/uninstall, native sharing, actual media rendering and clipboard behavior separately. Complete signing/licensing work before publishing binaries. There is currently no implemented macOS runner, signed Store package or completed Store validation in this handoff. See [VALIDATION.md](VALIDATION.md).
