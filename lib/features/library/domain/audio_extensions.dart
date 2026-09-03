import 'package:path/path.dart' as p;

/// The file extensions a scan collects, lower-case and with their dot.
///
/// The intersection of what the tag reader parses and what the playback engine
/// decodes, and deliberately not a superset of either: a file collected here
/// that the engine cannot open is a track the owner sees in their library and
/// cannot play, which is worse than one that was never listed.
const Set<String> audioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
  '.m4b',
  '.mp4',
  '.aac',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.wma',
  '.aif',
  '.aiff',
  '.aifc',
  '.ape',
};

/// The extensions a sidecar cover is looked for under, when a file carries no
/// embedded picture.
const Set<String> coverExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

/// The names a sidecar cover is looked for under, in order of preference.
///
/// Lower-case and without an extension. `cover` before `folder` before
/// `front`, which is the order the three conventions turn up in and the order
/// a listener would pick between them.
const List<String> coverBaseNames = ['cover', 'folder', 'front', 'albumart'];

/// Whether [path] names a file this application would collect.
bool isAudioPath(String path) =>
    audioExtensions.contains(p.extension(path).toLowerCase());

/// Whether [path] names a picture that could be a sidecar cover.
bool isCoverPath(String path) {
  final extension = p.extension(path).toLowerCase();
  if (!coverExtensions.contains(extension)) return false;

  return coverBaseNames.contains(
    p.basenameWithoutExtension(path).toLowerCase(),
  );
}
