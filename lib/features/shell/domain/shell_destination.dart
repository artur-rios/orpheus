/// The areas the shell can show.
///
/// Five, and deliberately few. This application does one thing, and a
/// navigation panel that listed eight ways into it would be eight ways of
/// asking the owner where they want to be before they have heard anything.
///
/// The second is a second way into the library rather than a new thing to do:
/// an owner who wants jazz is not thinking of an artist, and making them
/// remember which artists play it would be asking the library's question back
/// at them. It sits beside Music for that reason. The third is the owner's own
/// lists of it, and sits beside those two for the same one.
enum ShellDestination {
  /// The library, browsed by artist, album or song.
  music,

  /// The library, browsed by genre and then as Music browses it.
  genres,

  /// The playlists the owner made, and each one's songs.
  playlists,

  /// What is queued, in the order it will play.
  queue,

  /// The folders the library is built from, and what the last scan found.
  folders,
}
