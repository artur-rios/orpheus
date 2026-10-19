/// The songs the owner has picked in one list, and where a Shift-click starts.
///
/// Immutable: every operation answers a new selection. It remembers the paths
/// and never their order, because the order an action wants is the order of
/// the list the songs were picked in, and only that list knows it.
class SongSelection {
  /// A selection of [paths] made in [scope], whose last toggle was [anchor].
  const SongSelection({this.scope, this.paths = const {}, this.anchor});

  /// Nothing selected.
  static const SongSelection none = SongSelection();

  /// The identity of the list the songs were picked in; `null` when nothing is
  /// selected.
  ///
  /// Any object compared with `==`: a song list names itself however suits it,
  /// and a selection made in one list means nothing in another.
  final Object? scope;

  /// The selected songs, by file path.
  final Set<String> paths;

  /// The last song toggled, on or off: where a Shift-click range starts.
  final String? anchor;

  /// Whether anything is selected.
  bool get isActive => paths.isNotEmpty;

  /// Whether something is selected in the list named [scope].
  bool isActiveIn(Object scope) => isActive && this.scope == scope;

  /// Flips [path] in [scope].
  ///
  /// Another list's selection does not carry over: the song starts a fresh
  /// selection in this one.
  SongSelection toggle(Object scope, String path) {
    if (!isActiveIn(scope)) {
      return SongSelection(scope: scope, paths: {path}, anchor: path);
    }

    final next = {...paths};
    if (!next.remove(path)) next.add(path);

    return _of(scope, next, path);
  }

  /// Adds every song from the anchor to [path], in [order], to the selection.
  ///
  /// With no anchor in this list, or one that has left [order], there is no
  /// range to draw and it is a toggle.
  SongSelection rangeTo(Object scope, String path, List<String> order) {
    final from = isActiveIn(scope) && anchor != null
        ? order.indexOf(anchor!)
        : -1;
    final to = order.indexOf(path);

    if (from < 0 || to < 0) return toggle(scope, path);

    final low = from < to ? from : to;
    final high = from < to ? to : from;

    return _of(scope, {...paths, ...order.sublist(low, high + 1)}, path);
  }

  /// Every song in [order].
  SongSelection selectAll(Object scope, List<String> order) =>
      _of(scope, order.toSet(), anchor);

  /// Keeps the selected songs still in [order], so that a selection follows
  /// its list as the list changes under it.
  ///
  /// A selection made in another list does not survive this one. An anchor
  /// that left is dropped; a selection that lost every song ends.
  SongSelection retainIn(Object scope, List<String> order) {
    if (!isActiveIn(scope)) return none;

    final present = order.toSet();
    final kept = paths.where(present.contains).toSet();

    return _of(scope, kept, present.contains(anchor) ? anchor : null);
  }

  static SongSelection _of(Object scope, Set<String> paths, String? anchor) =>
      paths.isEmpty
      ? none
      : SongSelection(
          scope: scope,
          paths: Set.unmodifiable(paths),
          anchor: anchor,
        );

  @override
  bool operator ==(Object other) =>
      other is SongSelection &&
      other.scope == scope &&
      other.anchor == anchor &&
      other.paths.length == paths.length &&
      other.paths.containsAll(paths);

  @override
  int get hashCode =>
      Object.hash(scope, anchor, Object.hashAllUnordered(paths));
}
