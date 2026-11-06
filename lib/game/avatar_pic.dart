/// The picture in the player's avatar: their initial, or one of these
/// pictures, unlocked level by level.
enum AvatarPic {
  letter(1),
  spade(1),
  heart(1),
  diamond(1),
  club(1),
  anchor(2),
  sun(3),
  boat(5),
  olive(7),
  cat(9),
  star(11),
  bolt(13),
  castle(15),
  fire(17),
  music(19),
  gem(21),
  crown(24),
  rocket(28);

  const AvatarPic(this.level);

  /// The level that unlocks it.
  final int level;

  static AvatarPic byName(Object? name) => values.where((p) => p.name == name).firstOrNull ?? letter;
}
