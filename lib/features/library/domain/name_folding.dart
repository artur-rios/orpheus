/// The accented Latin letters, each followed by the plain letter it is read
/// as. Capitals only; the small letters are derived from them.
///
/// Spelled out rather than worked out from Unicode decomposition, which Dart
/// does not offer without a package: the letters a music library's names are
/// actually spelled with are these, and an unlisted one is left as it is
/// rather than read as a wrong letter.
const String _accented =
    'ÀAÁAÂAÃAÄAÅAĀAĂAĄA'
    'ÇCĆCĈCĊCČC'
    'ĎDĐD'
    'ÈEÉEÊEËEĒEĔEĖEĘEĚE'
    'ĜGĞGĠGĢG'
    'ĤHĦH'
    'ÌIÍIÎIÏIĨIĪIĬIĮIİI'
    'ĴJ'
    'ĶK'
    'ĹLĻLĽLĿLŁL'
    'ÑNŃNŅNŇN'
    'ÒOÓOÔOÕOÖOØOŌOŎOŐO'
    'ŔRŖRŘR'
    'ŚSŜSŞSŠS'
    'ŢTŤTŦT'
    'ÙUÚUÛUÜUŨUŪUŬUŮUŰUŲU'
    'ŴW'
    'ÝYŸYŶY'
    'ŹZŻZŽZ';

/// Every accented letter of [_accented], capital and small, to its plain
/// letter in the same case.
///
/// A capital whose small letter is not one character — `İ` lowers to `i`
/// with a combining dot — has no small form here; the dot is left in.
final Map<int, int> _plain = () {
  final plain = <int, int>{};
  for (var i = 0; i < _accented.length; i += 2) {
    final capital = _accented[i];
    final base = _accented[i + 1];
    plain[capital.codeUnitAt(0)] = base.codeUnitAt(0);

    final small = capital.toLowerCase();
    if (small.length == 1 && small != capital) {
      plain[small.codeUnitAt(0)] = base.toLowerCase().codeUnitAt(0);
    }
  }

  return plain;
}();

/// [name] with every accent on a Latin letter dropped, each letter keeping its
/// case: *Björk* is read as *Bjork*, *ação* as *acao*.
///
/// What a name is sorted and filed by, so that *Édith Piaf* is found among
/// the Es rather than after *Zappa*. Anything not in the table — a plain
/// letter, a digit, another script — is left as it is.
String foldAccents(String name) {
  // Most names are plain ASCII, and this runs on every comparison of a sort.
  if (!name.codeUnits.any((unit) => unit >= 0x80)) return name;

  return String.fromCharCodes([
    for (final unit in name.codeUnits) _plain[unit] ?? unit,
  ]);
}
