/// The areas the shell can show.
///
/// Three, and deliberately few. This application does one thing, and a
/// navigation panel that listed six ways into it would be six ways of asking
/// the owner where they want to be before they have heard anything.
enum ShellDestination {
  /// The library, browsed by artist, album or song.
  music,

  /// What is queued, in the order it will play.
  queue,

  /// The folders the library is built from, and what the last scan found.
  folders,
}
