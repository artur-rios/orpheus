/// The letter every name that does not start with A to Z is filed under:
/// digits, punctuation, and scripts other than the Latin one.
const String indexOther = '#';

/// The letters of the index, in the order they are shown: [indexOther]
/// first, then A to Z.
///
/// Every letter always, whether or not the library has a name under it, so
/// the index looks the same in every list and a letter is always where the
/// owner's thumb last found it.
final List<String> indexLetters = List.unmodifiable([
  indexOther,
  for (var code = 0x41; code <= 0x5A; code++) String.fromCharCode(code),
]);

/// The accented Latin letters, each followed by the plain letter it is filed
/// under. Upper case only: a name is upper-cased before it is looked up.
///
/// Spelled out rather than worked out from Unicode decomposition, which Dart
/// does not offer without a package: the letters a music library actually
/// starts with are these, and an unlisted one falls under [indexOther] rather
/// than under a wrong letter.
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

final Map<String, String> _plain = {
  for (var i = 0; i < _accented.length; i += 2) _accented[i]: _accented[i + 1],
};

/// The letter of [indexLetters] that [name] is filed under, or `null` for a
/// name that is absent or blank.
///
/// By its first character that is not a space, upper-cased, with any accent
/// dropped: *Édith Piaf* is under E, which is where an owner looks for her.
/// Anything that is then not A to Z is under [indexOther].
///
/// `null` rather than [indexOther] for the absent name: the untagged group is
/// listed last, under a name the presentation chose, and filing it under a
/// letter shown first would send the owner to the wrong end of the list.
String? indexLetterOf(String? name) {
  final trimmed = name?.trimLeft();
  if (trimmed == null || trimmed.isEmpty) return null;

  final first = String.fromCharCode(trimmed.runes.first).toUpperCase();
  final letter = _plain[first] ?? first;
  final code = letter.codeUnitAt(0);

  return letter.length == 1 && code >= 0x41 && code <= 0x5A
      ? letter
      : indexOther;
}

/// Where each letter's names start in [names], which are in the order they
/// are listed: the position of the first name filed under it.
///
/// A letter with no name under it is absent. The first appearance wins where
/// a letter comes back further down — an accented name, which sorts after Z,
/// does not move the letter away from the block of names the owner sees
/// under it.
Map<String, int> firstIndexByLetter(Iterable<String?> names) {
  final starts = <String, int>{};
  var index = 0;
  for (final name in names) {
    final letter = indexLetterOf(name);
    if (letter != null) starts.putIfAbsent(letter, () => index);
    index++;
  }

  return starts;
}
