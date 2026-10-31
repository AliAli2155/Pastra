import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/progression.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/game_header.dart';
import '../widgets/playing_card.dart';

/// One reward on the path.
sealed class _PathReward {
  const _PathReward();
}

class _TableReward extends _PathReward {
  const _TableReward(this.theme);
  final TableTheme theme;
}

class _BackReward extends _PathReward {
  const _BackReward(this.back);
  final CardBackStyle back;
}

class _FrameReward extends _PathReward {
  const _FrameReward(this.frame);
  final AvatarFrame frame;
}

class _TitleReward extends _PathReward {
  const _TitleReward(this.title);
  final PlayerTitle title;
}

class _ChipsReward extends _PathReward {
  const _ChipsReward(this.chips);
  final int chips;
}

List<_PathReward> _rewardsAt(int level) {
  final r = Progression.rewardsAt(level);
  return <_PathReward>[
    for (final t in r.tables) _TableReward(t),
    for (final b in r.backs) _BackReward(b),
    for (final f in r.frames) _FrameReward(f),
    for (final t in r.titles) _TitleReward(t),
    if (r.isEmpty && Economy.enabled && level > 1) _ChipsReward(Economy.levelUpChips(level)),
  ];
}

/// Levels 1–30 as a horizontal path (like a season pass): a gold track
/// through the level stops, the rewards above them, the player's place
/// marked. Unlocked rewards can be put to use right here.
class LevelPathScreen extends StatefulWidget {
  const LevelPathScreen({super.key});

  @override
  State<LevelPathScreen> createState() => _LevelPathScreenState();
}

class _LevelPathScreenState extends State<LevelPathScreen> {
  static const double _cardW = 118;
  static const double _emptyW = 62;
  static const double _gap = 10;

  final ScrollController _scroll = ScrollController();
  bool _scrolled = false;

  /// The player's own stop is wide enough for the "You are here" label.
  double _widthOf(int level, int current) {
    final n = _rewardsAt(level).length;
    final w = n == 0 ? _emptyW : n * _cardW + (n - 1) * 8 + 2 * _gap;
    return level == current ? max(w, 112) : w;
  }

  /// Puts the player's level in the middle of the screen (once).
  void _scrollToCurrent(int level, double viewport) {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      var start = 0.0;
      for (var l = 1; l < level; l++) {
        start += _widthOf(l, level);
      }
      final target = (start + _widthOf(level, level) / 2 - viewport / 2).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final level = settings.playerLevel;
    final progress = Progression.progress(settings.xp);
    final fraction = progress.needed == 0 ? 1.0 : progress.into / progress.needed;
    return Scaffold(
      body: Felt(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              GameHeader(
                title: p.levelPath,
                icon: Icons.route_rounded,
                trailing: <Widget>[HeaderPill(icon: Icons.bolt_rounded, text: '${settings.xp} XP')],
              ),
              _Summary(level: level, into: progress.into, needed: progress.needed),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    _scrollToCurrent(level, box.maxWidth);
                    // Never smaller than this: scroll down on tiny windows.
                    final h = max(box.maxHeight, 210.0);
                    final track = SizedBox(
                      height: h,
                      child: ListView.builder(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: Progression.maxLevel,
                        itemBuilder: (context, i) => SizedBox(
                          width: _widthOf(i + 1, level),
                          child: _Stop(
                            level: i + 1,
                            current: level,
                            fraction: fraction,
                            rewards: _rewardsAt(i + 1),
                            cardWidth: _cardW,
                          ),
                        ),
                      ),
                    );
                    return h > box.maxHeight ? SingleChildScrollView(child: track) : track;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, name, title, the level and the bar towards the next one.
class _Summary extends StatelessWidget {
  const _Summary({required this.level, required this.into, required this.needed});

  final int level;
  final int into;
  final int needed;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final s = Strings.of(context);
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;
    final maxed = needed == 0;
    int? next;
    for (var l = level + 1; l <= Progression.maxLevel && next == null; l++) {
      if (_rewardsAt(l).isNotEmpty) next = l;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.32),
          border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: <Widget>[
            PlayerAvatar(name: name, frame: settings.avatarFrame, size: 50),
            const SizedBox(width: 12),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(p.title(settings.title), style: const TextStyle(color: PastraColors.gold, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PastraColors.gold,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text('$level', style: const TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    maxed ? p.maxLevel : (next != null ? p.nextReward(next) : s.levelN(level + 1)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: maxed ? 1 : (into / needed).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 10,
                        color: PastraColors.gold,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  if (!maxed) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      '$into / $needed XP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One level on the path: its rewards on top, the track and the level stop
/// below.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.level,
    required this.current,
    required this.fraction,
    required this.rewards,
    required this.cardWidth,
  });

  final int level;
  final int current;

  /// Progress inside the current level (0..1).
  final double fraction;
  final List<_PathReward> rewards;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final p = ProgressStrings(SettingsScope.of(context).language);
    final reached = level <= current;
    final here = level == current;
    // Gold up to the player: full before, part of the way after the
    // current stop.
    final leftFill = level > 1 && level <= current;
    final rightFill = level < current ? 1.0 : (here && level < Progression.maxLevel ? fraction.clamp(0.0, 1.0) : 0.0);
    const trackH = 8.0;
    return Column(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: rewards.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var i = 0; i < rewards.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 8),
                        SizedBox(width: cardWidth, child: _RewardCard(reward: rewards[i], level: level, reached: reached)),
                      ],
                    ],
                  ),
          ),
        ),
        SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Track: left half, right half.
              Positioned(
                left: 0,
                right: 0,
                child: Row(
                  children: <Widget>[
                    Expanded(child: _Bar(fill: level == 1 ? null : (leftFill ? 1 : 0), height: trackH)),
                    Expanded(child: _Bar(fill: level == Progression.maxLevel ? null : rightFill, height: trackH)),
                  ],
                ),
              ),
              _Node(level: level, reached: reached, here: here),
            ],
          ),
        ),
        SizedBox(
          height: 20,
          child: here
              ? Text(
                  p.youAreHere,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: PastraColors.gold, fontSize: 11, fontWeight: FontWeight.w900),
                )
              : null,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill, required this.height});

  /// 0..1, or null for no track (before level 1, after the last level).
  final double? fill;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fill;
    if (f == null) return SizedBox(height: height);
    return Container(
      height: height,
      color: Colors.white12,
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: f,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: <Color>[Color(0xFFFFE08A), PastraColors.gold]),
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.level, required this.reached, required this.here});

  final int level;
  final bool reached;
  final bool here;

  @override
  Widget build(BuildContext context) {
    final size = here ? 46.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: reached
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFFE08A), Color(0xFFD9A21E)])
            : null,
        color: reached ? null : const Color(0xFF123227),
        border: Border.all(color: here ? Colors.white : (reached ? const Color(0xFFFFE9A6) : Colors.white24), width: here ? 3 : 1.5),
        boxShadow: here ? <BoxShadow>[BoxShadow(color: PastraColors.gold.withValues(alpha: 0.7), blurRadius: 16)] : null,
      ),
      child: Text(
        '$level',
        style: TextStyle(color: reached ? Colors.black : Colors.white54, fontSize: here ? 18 : 14, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// A reward: its picture, name and state (locked / use / in use).
class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward, required this.level, required this.reached});

  final _PathReward reward;
  final int level;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final s = Strings.of(context);
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;

    late final String kind;
    late final String label;
    late final Widget picture;
    // null: nothing to put to use (titles, chips).
    bool? inUse;
    VoidCallback? use;
    switch (reward) {
      case _TableReward(:final theme):
        kind = p.reward('table');
        label = p.table(theme);
        picture = LayoutBuilder(
          builder: (context, box) => DecoratedBox(
            decoration: theme.decoration.copyWith(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: SizedBox(width: min(box.maxWidth, 84), height: min(box.maxHeight, 54)),
          ),
        );
        inUse = settings.tableTheme == theme;
        use = () => settings.tableTheme = theme;
      case _BackReward(:final back):
        kind = p.reward('back');
        label = p.back(back);
        picture = AspectRatio(aspectRatio: 0.7, child: PlayingCardView(card: 0, faceUp: false, backStyle: back));
        inUse = settings.cardBack == back;
        use = () => settings.cardBack = back;
      case _FrameReward(:final frame):
        kind = p.reward('frame');
        label = p.frame(frame);
        picture = LayoutBuilder(builder: (context, box) => PlayerAvatar(name: name, frame: frame, size: min(56.0, box.maxHeight)));
        inUse = settings.avatarFrame == frame;
        use = () => settings.avatarFrame = frame;
      case _TitleReward(:final title):
        kind = p.reward('title');
        label = p.title(title);
        picture = const Icon(Icons.workspace_premium_rounded, color: PastraColors.gold, size: 44);
      case _ChipsReward(:final chips):
        kind = ShopStrings(settings.language).chips;
        label = '+${Economy.short(chips)}';
        picture = const Icon(Icons.toll_rounded, color: PastraColors.gold, size: 44);
    }

    final Widget footer;
    if (!reached) {
      footer = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.lock_rounded, color: Colors.white38, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(s.levelN(level), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    } else if (inUse == null) {
      footer = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: PastraColors.gold, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(p.unlocked, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PastraColors.gold, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    } else if (inUse) {
      footer = Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: PastraColors.gold)),
        child: Text(p.inUse, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PastraColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
      );
    } else {
      footer = SizedBox(
        height: 26,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: PastraColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
          onPressed: use,
          child: Text(p.use),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: reached
              ? <Color>[const Color(0xFF2A4A3A).withValues(alpha: 0.95), Colors.black.withValues(alpha: 0.55)]
              : <Color>[Colors.black.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.5)],
        ),
        border: Border.all(
          color: inUse == true ? PastraColors.gold : (reached ? PastraColors.gold.withValues(alpha: 0.45) : Colors.white12),
          width: inUse == true ? 2 : 1.2,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            kind.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: reached ? PastraColors.gold : Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Opacity(
              opacity: reached ? 1 : 0.4,
              child: Center(child: picture),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: reached ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          footer,
        ],
      ),
    );
  }
}
