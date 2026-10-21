import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/confidence.dart';

/// Why [doubt] kept a record for the owner, in a few words.
String doubtReasonName(
  Doubtful doubt,
  AppLocalizations l10n,
) => switch (doubt.reason) {
  DoubtReason.noMatch => l10n.autofillDoubtNoMatch,
  DoubtReason.notOfficial => l10n.autofillDoubtNotOfficial,
  DoubtReason.differentAlbum => l10n.autofillDoubtDifferentAlbum,
  DoubtReason.differentArtist => l10n.autofillDoubtDifferentArtist,
  DoubtReason.unmatchedSongs => l10n.autofillDoubtUnmatchedSongs(doubt.count),
  DoubtReason.differentSongs => l10n.autofillDoubtDifferentSongs(doubt.count),
  DoubtReason.wouldSplitAlbum => l10n.autofillDoubtWouldSplitAlbum,
  DoubtReason.uncertainTrack => l10n.autofillDoubtUncertainTrack,
};
