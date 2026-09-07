/// Where a fetched sheet is kept.
///
/// Beside the track, as a `.lrc` — which makes this the one place in the whole
/// application that writes into the owner's music folders. Everything else
/// Orpheus produces goes to its own support directory, and this does not: a
/// sheet written here is one every other player on the machine can read, and
/// one the owner can correct in a text editor and Orpheus will then prefer
/// over anything a network says.
///
/// The cost of that choice is that the write is the one operation here most
/// likely to be refused — a read-only mount, a NAS share mounted without write
/// access, and on Android a scoped-storage sandbox that hands out
/// `READ_MEDIA_AUDIO` and nothing that would let a process write next to the
/// file it just read. So [write] reports rather than throws, and a refusal
/// costs the owner the sheet on the next launch and nothing in this one.
abstract interface class LyricsSidecar {
  /// Writes [text] as the `.lrc` beside the track at [path].
  ///
  /// Answers whether it landed. Never replaces a sidecar that is already
  /// there: that file is the owner's, and it outranks anything fetched.
  Future<bool> write(String path, String text);
}
