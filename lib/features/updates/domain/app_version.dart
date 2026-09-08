/// A released version of this application: `1.2.3`, or `1.2.3-beta.1`.
///
/// Its whole job is answering which of two releases is later, which is the
/// question the update check exists to ask. Written out rather than taken from
/// a package because the comparison this needs is small and exact, and because
/// what it compares — the tag the release workflow publishes and the version
/// the running build reports — are both produced by this repository and no
/// other.
///
/// The ordering is the part of semantic versioning that applies here:
/// numbers compare as numbers, so 1.10.0 is after 1.9.0 rather than before it;
/// and a pre-release is *earlier* than the release it leads to, so
/// `1.1.0-beta.1` never offers itself as an update to somebody running
/// `1.1.0`.
class AppVersion implements Comparable<AppVersion> {
  /// Creates a version from its parts.
  const AppVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = const [],
  });

  /// The version this string names, or `null` where it names none.
  ///
  /// A leading `v` is accepted because that is how the tags are written, and
  /// build metadata after `+` is dropped because it never affects precedence —
  /// `1.0.1+2` and `1.0.1+7` are the same release, differing only in a number
  /// Android reads.
  static AppVersion? tryParse(String text) {
    var rest = text.trim();
    if (rest.startsWith('v') || rest.startsWith('V')) rest = rest.substring(1);

    rest = rest.split('+').first;

    final parts = rest.split('-');
    final numbers = parts.first.split('.');
    if (numbers.length != 3) return null;

    final parsed = [for (final number in numbers) int.tryParse(number)];
    if (parsed.any((number) => number == null || number < 0)) return null;

    return AppVersion(
      parsed[0]!,
      parsed[1]!,
      parsed[2]!,
      preRelease: parts.length > 1
          ? parts.sublist(1).join('-').split('.')
          : const [],
    );
  }

  /// The first number: an incompatible change.
  final int major;

  /// The second: something added.
  final int minor;

  /// The third: something fixed.
  final int patch;

  /// The dot-separated identifiers after a `-`, empty for a full release.
  final List<String> preRelease;

  /// Whether this names a pre-release rather than a finished version.
  bool get isPreRelease => preRelease.isNotEmpty;

  /// Whether [other] is a version this one should be offered as an update to.
  bool isAfter(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final difference = pair.$1.compareTo(pair.$2);
      if (difference != 0) return difference;
    }

    // A release outranks any pre-release of the same numbers, and two
    // pre-releases are ordered by their identifiers: numeric ones numerically,
    // and a numeric one before a textual one, which is what makes `beta.9`
    // come before `beta.10` rather than after it.
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;

    for (var index = 0; index < preRelease.length; index++) {
      if (index >= other.preRelease.length) return 1;

      final mine = preRelease[index];
      final theirs = other.preRelease[index];
      if (mine == theirs) continue;

      final mineNumber = int.tryParse(mine);
      final theirsNumber = int.tryParse(theirs);

      if (mineNumber != null && theirsNumber != null) {
        return mineNumber.compareTo(theirsNumber);
      }
      if (mineNumber != null) return -1;
      if (theirsNumber != null) return 1;

      return mine.compareTo(theirs);
    }

    return preRelease.length.compareTo(other.preRelease.length);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    final core = '$major.$minor.$patch';

    return preRelease.isEmpty ? core : '$core-${preRelease.join('.')}';
  }
}
