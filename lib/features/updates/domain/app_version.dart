/// A released version of this application: `1.2.3`, or `1.2.3-beta.1`.
///
/// Its whole job is answering which of two releases is later, which is the
/// question the update check exists to ask. Written out rather than taken from
/// a package because the comparison this needs is small and exact, and because
/// what it compares — the tag the release workflow publishes and the version
/// the running build reports — are both produced by this repository and no
/// other.
///
/// The ordering is SemVer 2.0.0 precedence, whole: numbers compare as
/// numbers, so 1.10.0 is after 1.9.0 rather than before it; a pre-release is
/// *earlier* than the release it leads to, so `1.1.0-beta.1` never offers
/// itself as an update to somebody running `1.1.0`, while somebody running it
/// is offered `1.1.0-beta.2` and then `1.1.0`; and build metadata is ignored.
/// The running build's half of that comparison carries its pre-release only
/// because `pubspec.yaml` does — see CONTRIBUTING.md, *Versioning*.
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
  /// The text has to be a SemVer 2.0.0 version, optionally after a leading
  /// `v`, because that is how the tags are written. Build metadata after `+`
  /// is checked and then dropped, because it never affects precedence —
  /// `1.0.1+2` and `1.0.1+7` are the same release, differing only in a number
  /// Android reads.
  static AppVersion? tryParse(String text) {
    var rest = text.trim();
    if (rest.startsWith('v') || rest.startsWith('V')) rest = rest.substring(1);

    final match = _semVer.firstMatch(rest);
    if (match == null) return null;

    final numbers = [
      for (final group in [1, 2, 3]) int.tryParse(match.group(group)!),
    ];
    // Valid SemVer, but beyond what a version of this application will ever
    // reach; refusing it is safer than comparing it wrongly.
    if (numbers.any((number) => number == null)) return null;

    final preRelease = match.group(4);

    return AppVersion(
      numbers[0]!,
      numbers[1]!,
      numbers[2]!,
      preRelease: preRelease == null ? const [] : preRelease.split('.'),
    );
  }

  /// SemVer 2.0.0's own grammar (semver.org, "Is there a suggested regular
  /// expression"): no leading zeros in a number, no empty identifier, and
  /// nothing but `[0-9A-Za-z-]` in one.
  static final RegExp _semVer = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?'
    r'(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$',
  );

  /// Whether a pre-release identifier is numeric: digits and nothing else.
  ///
  /// Not `int.tryParse`, which also accepts `-1`, `+1` and `0x1` — all of
  /// them alphanumeric identifiers to SemVer.
  static final RegExp _numeric = RegExp(r'^[0-9]+$');

  /// Two numeric identifiers in numeric order, at any length: the grammar has
  /// already ruled out leading zeros, so the longer one is the larger.
  static int _compareNumerically(String mine, String theirs) {
    final byLength = mine.length.compareTo(theirs.length);

    return byLength != 0 ? byLength : mine.compareTo(theirs);
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

      final mineIsNumeric = _numeric.hasMatch(mine);
      final theirsIsNumeric = _numeric.hasMatch(theirs);

      if (mineIsNumeric && theirsIsNumeric) {
        return _compareNumerically(mine, theirs);
      }
      if (mineIsNumeric) return -1;
      if (theirsIsNumeric) return 1;

      // ASCII order, which is what SemVer asks for: the grammar admits
      // nothing outside ASCII, so code units are characters here.
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
