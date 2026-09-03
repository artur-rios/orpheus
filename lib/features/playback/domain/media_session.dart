/// What the platform is showing about the track playing.
///
/// A flat value rather than the player's own state: what a notification and a
/// lock screen need is a title, who it is by, how long it is, where playback
/// is in it, and which of the transport buttons should be lit. Everything
/// else the player knows — the queue, the repeat mode, which files were
/// skipped — has nowhere to go on a lock screen.
class NowPlaying {
  /// Creates what the session should show.
  const NowPlaying({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.artPath,
    this.position = Duration.zero,
    this.isPlaying = false,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  /// What identifies the track — its path, as everywhere else.
  final String id;

  /// What to call it.
  ///
  /// Not nullable, unlike the tag it comes from: a notification has to say
  /// something, and the presentation layer has already made the choice about
  /// what an absent title is called by the time it reaches here.
  final String title;

  /// Who performed it, where the tags say.
  final String? artist;

  /// The record it is on, where the tags say.
  final String? album;

  /// How long it is, once it is known.
  final Duration? duration;

  /// The sleeve, as a file on disk, or `null` where there is none.
  ///
  /// A path rather than the bytes: every platform media session takes a URI it
  /// will load the picture from itself, and the cover store already holds one
  /// file per distinct picture.
  final String? artPath;

  /// Where playback is, which is what draws the scrubber.
  final Duration position;

  /// Whether audio is running, which is which way round the play button faces.
  final bool isPlaying;

  /// Whether the next button should do anything.
  final bool hasNext;

  /// Whether the previous button should.
  ///
  /// True for the first track of a queue as well, because pressing back near
  /// the start of a track restarts it — the button is never dead while
  /// something is playing.
  final bool hasPrevious;

  /// Whether [other] describes the same track as this, however playback of it
  /// has moved on.
  ///
  /// The narrower of the two questions, and the one the platform adapter asks:
  /// a session distinguishes *what* is playing from *how* it is playing, and
  /// the first of those is the expensive half — it carries the sleeve, which
  /// the platform loads from disk and scales. Re-announcing the track on every
  /// position tick would be that work several times a second for a
  /// notification that did not change.
  bool sameTrackAs(NowPlaying other) =>
      id == other.id &&
      title == other.title &&
      artist == other.artist &&
      album == other.album &&
      duration == other.duration &&
      artPath == other.artPath;

  /// Whether [other] is the same in every respect, playback position included.
  ///
  /// The wider question, and the one the controller asks before it publishes
  /// anything at all.
  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      sameTrackAs(other) &&
      position == other.position &&
      isPlaying == other.isPlaying &&
      hasNext == other.hasNext &&
      hasPrevious == other.hasPrevious;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    album,
    duration,
    artPath,
    position,
    isPlaying,
    hasNext,
    hasPrevious,
  );

  @override
  String toString() => 'NowPlaying($title, position: $position, '
      'playing: $isPlaying)';
}

/// Something the owner — or the system — asked of the player from outside the
/// application's own windows.
///
/// The notification, the lock screen, a headset button, the steering wheel,
/// and the system taking the audio output away for a phone call all arrive
/// here as the same few asks. Sealed, so the controller that routes them is
/// checked for having handled every one.
sealed class MediaSessionCommand {
  /// Creates a command.
  const MediaSessionCommand();
}

/// Start, or carry on.
final class ResumeAsked extends MediaSessionCommand {
  /// Creates the command.
  const ResumeAsked();
}

/// Stop making noise, and stay where you are.
final class PauseAsked extends MediaSessionCommand {
  /// Creates the command.
  const PauseAsked();
}

/// The next track.
final class NextAsked extends MediaSessionCommand {
  /// Creates the command.
  const NextAsked();
}

/// The previous track, or this one from the top.
final class PreviousAsked extends MediaSessionCommand {
  /// Creates the command.
  const PreviousAsked();
}

/// Stop, and put the queue away.
final class StopAsked extends MediaSessionCommand {
  /// Creates the command.
  const StopAsked();
}

/// Move to [position] in the track playing.
final class SeekAsked extends MediaSessionCommand {
  /// Creates the command for [position].
  const SeekAsked(this.position);

  /// Where playback should move to.
  final Duration position;
}

/// The platform's media session: the notification, the lock screen, and the
/// buttons on whatever the owner has plugged in.
///
/// Behind an interface for the reason the playback engine is, and for one
/// more: only one of this application's three targets has such a thing at all
/// — Android — so the alternative to this seam is a platform check in the
/// middle of the player, and a session that only exists on a device nobody can
/// run a test on.
///
/// It is a *view* of the player, in the same sense the playback bar is: it
/// shows what is playing and it sends back what was pressed. It holds no queue
/// and decides nothing.
abstract interface class MediaSession {
  /// What was asked of the player from outside the application.
  Stream<MediaSessionCommand> get commands;

  /// Shows [nowPlaying], replacing whatever was shown before.
  Future<void> show(NowPlaying nowPlaying);

  /// Takes the session down, which is what stopping leaves behind.
  Future<void> hide();

  /// Releases the session.
  Future<void> dispose();
}
