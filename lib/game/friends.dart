/// A person met at an online table. Favourites stay; the others are the
/// most recent players. Pure Dart; [AppSettings] stores the list.
class Friend {
  const Friend({required this.uid, required this.name, required this.lastPlayed, this.favorite = false, this.games = 1});

  final String uid;
  final String name;

  /// Milliseconds since the epoch of the last game together.
  final int lastPlayed;
  final bool favorite;
  final int games;

  Friend copyWith({String? name, int? lastPlayed, bool? favorite, int? games}) => Friend(
        uid: uid,
        name: name ?? this.name,
        lastPlayed: lastPlayed ?? this.lastPlayed,
        favorite: favorite ?? this.favorite,
        games: games ?? this.games,
      );

  Map<String, Object> toJson() => <String, Object>{'u': uid, 'n': name, 't': lastPlayed, 'f': favorite, 'g': games};

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
