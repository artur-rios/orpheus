/// The areas the shell can show.
///
/// Four, and deliberately few. This application does one thing, and a
/// navigation panel that listed six ways into it would be six ways of asking
/// the owner where they want to be before they have heard anything.
///
/// The fourth is a second way into the library rather than a new thing to do:
/// an owner who wants jazz is not thinking of an artist, and making them
/// remember which artists play it would be asking the library's question back
/// at them. It sits beside Music for that reason.
enum ShellDestination {
  /// The library, browsed by artist, album or song.
  music,

  /// The library, browsed by genre and then as Music browses it.
  genres,

  /// What is queued, in the order it will play.
  queue,

  /// The folders the library is built from, and what the last scan found.
  folders,
}
