/// A person met at an online table. Favourites stay; the others are the
/// most recent players. Pure Dart; [AppSettings] stores the list.
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    required this.lastPlayed,
    this.favorite = false,
    this.games = 1,
    this.tag = '',
  });

  final String uid;
  final String name;

  /// The 4-digit code after the name ("Ali #2155"); empty when unknown.
  final String tag;

  /// Milliseconds since the epoch of the last game together.
  final int lastPlayed;
  final bool favorite;
  final int games;

  Friend copyWith({String? name, int? lastPlayed, bool? favorite, int? games, String? tag}) => Friend(
        uid: uid,
        name: name ?? this.name,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        favorite: favorite ?? this.favorite,
        games: games ?? this.games,
        tag: tag ?? this.tag,
      );

  /// "Ali #2155" (or just the name when the code is not known).
  String get handle => tag.isEmpty ? name : '$name #$tag';

  Map<String, Object> toJson() =>
      <String, Object>{'u': uid, 'n': name, 't': lastPlayed, 'f': favorite, 'g': games, 'c': tag};

  static Friend? fromJson(Object? j) {
    if (j is! Map) return null;
    final u = j['u'];
    final n = j['n'];
    final t = j['t'];
    if (u is! String || u.isEmpty || n is! String || t is! num) return null;
    return Friend(
      uid: u,
      name: n,
      lastPlayed: t.toInt(),
      favorite: j['f'] == true,
      games: (j['g'] as num?)?.toInt() ?? 1,
      tag: j['c'] is String ? j['c'] as String : '',
    );
  }

  /// Adds (or refreshes) the people of a game: newest first, favourites are
  /// never dropped, at most [maxRecent] others are kept.
  static List<Friend> merge(List<Friend> list, Map<String, String> people, int now, {int maxRecent = 30}) {
    final byUid = <String, Friend>{for (final f in list) f.uid: f};
    people.forEach((uid, name) {
      final old = byUid[uid];
      final clean = name.trim().isEmpty ? (old?.name ?? '') : name.trim();
      byUid[uid] = old == null
          ? Friend(uid: uid, name: clean, lastPlayed: now)
          : old.copyWith(name: clean, lastPlayed: now, games: old.games + 1);
    });
    final all = byUid.values.toList()..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    var others = 0;
    return <Friend>[
      for (final f in all)
        if (f.favorite || others++ < maxRecent) f,
    ];
  }
}

/// Player codes ("Ali #2155"): every player gets a random 4-digit tag, and
/// name + tag finds them (like in other online games).
class PlayerHandle {
  PlayerHandle._();

  /// The lookup key of a name and tag in the database (lower case, without
  /// the characters a database key may not contain).
  static String keyOf(String name, String tag) => '${normalize(name)}~$tag';

  static String normalize(String name) {
    var n = name.trim().toLowerCase().replaceAll(RegExp(r'[.#$\[\]/~\s]+'), '_');
    if (n.isEmpty) n = 'player';
    return n;
  }

  /// Reads "Ali #2155", "ali#2155" or "Ali 2155"; null when it is not a code.
  static (String, String)? parse(String text) {
    final m = RegExp(r'^\s*(.+?)\s*[#\s]\s*(\d{4})\s*$').firstMatch(text);
    if (m == null) return null;
    final name = m.group(1)!.trim();
    if (name.isEmpty || name == '#') return null;
    return (name, m.group(2)!);
  }

  static String format(String name, String tag) => tag.isEmpty ? name : '$name #$tag';
}
