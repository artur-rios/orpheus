/// When a track counts as having been played.
///
/// The rule lives in one function rather than as a condition spread through
/// the player, because it is the whole of what "played" means in this
/// application and it is the thing most likely to be argued with later.
library;

/// The point past which a track counts however long it is.
///
/// Four minutes. Without a cap, an hour-long live set would have to be heard
/// for thirty minutes to count, which is not what anyone means by having
/// listened to it.
const Duration playThresholdCap = Duration(minutes: 4);

/// Whether a track [duration] long, heard as far as [position], counts as
/// played.
///
/// **Half the track, or four minutes, whichever comes first** — the convention
/// scrobblers have used for twenty years, and it is the right shape in both
/// directions. A two-minute song abandoned after forty seconds was not
/// listened to. A long record does not stop counting because the owner left
/// before the end. A track heard all the way through counts however short it
/// is, which is the same rule arrived at from the other side.
///
/// A length the engine has not reported yet counts nothing. With nothing to
/// take half of, every version of this rule reduces to a guess, and the next
/// status carries the real duration a moment later.
bool countsAsPlayed({required Duration position, Duration? duration}) {
  if (duration == null || duration <= Duration.zero) return false;
  if (position <= Duration.zero) return false;
  if (position >= playThresholdCap) return true;

  return position >= duration ~/ 2;
}
