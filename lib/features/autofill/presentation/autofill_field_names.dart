import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/autofill_field.dart';

/// [field] as the owner reads it.
String autofillFieldName(AppLocalizations l10n, AutofillField field) =>
    switch (field) {
      AutofillField.title => l10n.autofillFieldTitle,
      AutofillField.artist => l10n.autofillFieldArtist,
      AutofillField.albumArtist => l10n.autofillFieldAlbumArtist,
      AutofillField.album => l10n.autofillFieldAlbum,
      AutofillField.trackNumber => l10n.autofillFieldTrackNumber,
      AutofillField.trackTotal => l10n.autofillFieldTrackTotal,
      AutofillField.discNumber => l10n.autofillFieldDiscNumber,
      AutofillField.discTotal => l10n.autofillFieldDiscTotal,
      AutofillField.year => l10n.autofillFieldYear,
      AutofillField.genre => l10n.autofillFieldGenre,
      AutofillField.cover => l10n.autofillFieldCover,
    };
