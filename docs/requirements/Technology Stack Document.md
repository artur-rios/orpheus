# Technology Stack Document — Orpheus

The single source of truth for every technology this project depends on. The
reasoning behind these choices is in
[Technology Stack](../initial/Technology%20Stack.md); this document is the list.

A dependency added without a row here is a Definition of Done failure.

## 1. Toolchain

| | Version | Notes |
| --- | --- | --- |
| **Flutter** | 3.47.2, stable channel | The version the project is built and tested against. |
| **Dart SDK** | `^3.13.2` | Declared in `pubspec.yaml`. |
| **Java** | 17 | `sourceCompatibility`, `targetCompatibility` and the Kotlin JVM target for the Android build. |

## 2. Platform targets

| Target | Floor | Notes |
| --- | --- | --- |
| **Android** | API 23 (Android 6) | Not Flutter's own floor. The playback engine requires it, and 23 is where runtime permissions begin — below it there would be no permission to ask for and no engine to play with. |
| **Android compile SDK** | 37 | Required by `permission_handler_android`, which refuses to be consumed by anything compiled against less. Compiling against a newer platform is not the same as targeting one. |
| **Linux** | GTK, x64 | Requires `libmpv` present at runtime — `libmpv-dev` and `mpv` on Debian and Ubuntu. |
| **Windows** | x64 | The engine's DLLs are bundled by `media_kit_libs_audio`; no extra dependency. |

## 3. Runtime dependencies

| Package | Version | What it is for |
| --- | --- | --- |
| `flutter_riverpod` | `^3.0.0` | State management and the single composition root. The queue outlives the screen that started it, so it cannot live in a widget. |
| `media_kit` | `^1.2.6` | The playback engine. libmpv-backed, and the one engine in its class covering all three targets with one API and no transcoding. |
| `media_kit_libs_audio` | `^1.0.7` | The engine's bundled native libraries for Windows and Android. |
| `audio_metadata_reader` | `^1.7.1` | Tag reading — ID3, Vorbis comments, iTunes atoms, RIFF, APE — **in pure Dart**, which is what makes it testable and what avoids a native build per target. |
| `audio_service` | `^0.18.19` | The Android foreground service, its notification, the lock screen, and media buttons. Android-only in effect; behind the `MediaSession` seam. |
| `audio_session` | `^0.2.4` | Audio focus — the phone call that should pause the music, and the headphones pulled out of the socket. Reaches the player through the same seam. |
| `path_provider` | `^2.1.6` | Where this application may write, per platform. |
| `path` | `^1.9.1` | Path manipulation, including inside the scan isolate. |
| `shared_preferences` | `^2.5.5` | Preferences, library folders, resume points, repeat mode, volume. |
| `file_picker` | `^12.2.0` | The folder picker. Chosen over `file_selector` because `getDirectoryPath` answers on Android as well as on both desktops, and this project has a mobile target. |
| `permission_handler` | `^13.0.1` | Android's `READ_MEDIA_AUDIO`, its pre-13 predecessor, and the notification permission. Asked for on Android and nowhere else. |
| `window_manager` | `^0.5.2` | The desktop window's minimum size and restored geometry. Desktop-only by nature and guarded as such at every call. |
| `logging` | `^1.3.0` | Structured logging, one logger per feature area. |
| `intl` | `^0.20.2` | Localization support for the generated catalogs. |
| `flutter_localizations` | SDK | English and Brazilian Portuguese. |

## 4. Development dependencies

| Package | Version | What it is for |
| --- | --- | --- |
| `flutter_test` | SDK | Unit and widget tests. |
| `flutter_lints` | `^6.0.0` | The base lint set, with the strict language modes and this project's own rules layered on top in `analysis_options.yaml`. |

## 5. Analyzer configuration

Beyond `flutter_lints`, the project enables:

| Setting | Effect |
| --- | --- |
| `strict-casts`, `strict-inference`, `strict-raw-types` | The strict language modes, all three. |
| `public_member_api_docs` | Every public member is documented. |
| `only_throw_errors`, `unawaited_futures` | Every failure is surfaced; no future is dropped by accident. |
| `avoid_dynamic_calls`, `cast_nullable_to_non_nullable` | No dynamic dispatch, no unchecked nullable casts. |
| `prefer_const_*`, `prefer_final_locals`, `require_trailing_commas`, `prefer_single_quotes` | Consistency, mechanically enforced. |
| `missing_required_param`, `missing_return` promoted to **error** | A missing translation is a build failure, not a string that renders as its key. |

There is **no known-warnings list**, and adding one is not an option. The moment
there is one, warnings stop being read.

## 6. What is deliberately absent

| Not used | Why |
| --- | --- |
| Any HTTP client | There is no network access of any kind (`NFR-02`). |
| Any database | The whole library is read at once and never queried piecemeal; JSON documents answer everything a database would. |
| Any code generator beyond `gen_l10n` | Generated state classes and models would add a build step for no behaviour this project needs. |
| Any crash or analytics reporter | Nothing leaves the machine (`BR-03`). |
| A Rust core over FFI | This is the dependency Orpheus exists to shed; it has no Android build, which is what kept Alexandria's music on the desk. |
