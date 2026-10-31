import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/quests.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/wallet_bar.dart';

/// Today's three quests and the daily chest, laid out for a phone held
/// sideways: three tall cards next to each other and the chest on the right
/// (one under the other on a narrow screen).
class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  Timer? _tick;

  /// "+80 XP" texts flying up after collecting.
  final List<_Burst> _bursts = <_Burst>[];
  int _burstId = 0;

  @override
  void initState() {
    super.initState();
    // The countdown, and new quests at midnight while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _burst(String text) {
    final b = _Burst(_burstId++, text);
    setState(() => _bursts.add(b));
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _bursts.remove(b));
    });
  }

  /// Level-ups and achievements unlocked by collecting.
  void _afterClaim(int xp, int levelBefore) {
    final settings = SettingsScope.read(context);
    final s = Strings.of(context);
    _burst('+$xp XP');
    final parts = <String>[
      if (settings.playerLevel > levelBefore) s.levelN(settings.playerLevel),
      for (final id in settings.unlockEarned()) '${s.achUnlocked}: ${s.achTitle(id)}',
    ];
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(parts.join(' · ')), duration: const Duration(seconds: 3)));
  }

  void _claim(QuestState q) {
    final settings = SettingsScope.read(context);
    final before = settings.playerLevel;
    final xp = settings.claimQuest(q.def.id);
    if (xp != null) _afterClaim(xp, before);
  }

  void _claimChest() {
    final settings = SettingsScope.read(context);
    final before = settings.playerLevel;
    if (settings.claimQuestBonus()) _afterClaim(Quests.allBonusXp, before);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final quests = settings.quests;
    final claimedCount = quests.where((q) => q.claimed).length;

    Widget card(QuestState q, {required bool tall}) => _QuestCard(
          quest: q,
          p: p,
          tall: tall,
          canReroll: settings.canRerollQuest && q.progress == 0 && !q.done,
          onClaim: () => _claim(q),
          onReroll: () => settings.rerollQuest(q.def.id),
        );
    Widget chest({required bool tall}) => _ChestPanel(
          p: p,
          tall: tall,
          claimed: claimedCount,
          ready: settings.questBonusReady,
          done: settings.questBonusClaimed,
          onOpen: _claimChest,
        );

    return Scaffold(
      body: Felt(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  GameHeader(
                    title: p.quests,
                    icon: Icons.task_alt_rounded,
                    trailing: <Widget>[
                      HeaderPill(
                        icon: Icons.schedule_rounded,
                        text: p.questsNew(p.duration(Quests.untilTomorrow(DateTime.now()))),
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final wide = box.maxWidth >= 640 && box.maxWidth > box.maxHeight * 1.15;
                        if (!wide) {
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                            children: <Widget>[
                              for (final q in quests) Padding(padding: const EdgeInsets.only(bottom: 10), child: card(q, tall: false)),
                              chest(tall: false),
                              const SizedBox(height: 10),
                              Text(p.questsHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          );
                        }
                        // Sideways: never squeeze the cards below 250 px,
                        // scroll instead (very small windows).
                        final h = max(box.maxHeight, 250.0);
                        final content = SizedBox(
                          height: h,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 420),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    for (final q in quests) ...<Widget>[
                                      Expanded(child: card(q, tall: true)),
                                      const SizedBox(width: 12),
                                    ],
                                    SizedBox(width: min(230.0, box.maxWidth * 0.24), child: chest(tall: true)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                        return h > box.maxHeight ? SingleChildScrollView(child: content) : content;
                      },
                    ),
                  ),
                ],
              ),
              for (final b in _bursts)
                Positioned.fill(
                  child: IgnorePointer(child: Center(child: _BurstText(key: ValueKey<int>(b.id), text: b.text))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Burst {
  _Burst(this.id, this.text);

  final int id;
  final String text;
}

/// Big gold text that pops, rises and fades.
class _BurstText extends StatelessWidget {
  const _BurstText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1300),
      builder: (context, t, child) {
        final pop = Curves.elasticOut.transform((t / 0.4).clamp(0.0, 1.0));
        final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -90 * Curves.easeOut.transform(t)),
            child: Transform.scale(scale: 0.4 + 0.6 * pop, child: child),
          ),
        );
      },
      child: GoldText(text, size: 54),
    );
  }
}

Color _tierColor(QuestTier t) => switch (t) {
      QuestTier.easy => const Color(0xFF5BD69A),
      QuestTier.medium => const Color(0xFF4CA8FF),
      QuestTier.hard => const Color(0xFFFF8A5B),
    };

IconData _kindIcon(String kind) => switch (kind) {
      'play' || 'rounds' => Icons.style_rounded,
      'win' || 'win1' => Icons.emoji_events_rounded,
      'pastra' => Icons.auto_awesome,
      'jack' => Icons.stars_rounded,
      'team' || 'teamWin' => Icons.groups_rounded,
      'online' || 'onlineWin' => Icons.public,
      'hard' => Icons.psychology_alt_rounded,
      'round' => Icons.trending_up_rounded,
      'good' => Icons.diamond_outlined,
      'streak' => Icons.local_fire_department_rounded,
      _ => Icons.flag_rounded,
    };

/// Repeats a soft glow while [active] (a quest or the chest ready to collect).
class _Glow extends StatefulWidget {
  const _Glow({required this.active, required this.color, required this.radius, required this.child});

  final bool active;
  final Color color;
  final double radius;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Glow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: <BoxShadow>[
            BoxShadow(color: widget.color.withValues(alpha: 0.25 + 0.35 * _c.value), blurRadius: 10 + 14 * _c.value),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// One quest. Tall: a column card (sideways layout). Otherwise a row.
class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.p,
    required this.tall,
    required this.canReroll,
    required this.onClaim,
    required this.onReroll,
  });

  final QuestState quest;
  final ProgressStrings p;
  final bool tall;
  final bool canReroll;
  final VoidCallback onClaim;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    final def = quest.def;
    final tier = _tierColor(def.tier);
    final ready = quest.done && !quest.claimed;
    final accent = quest.done ? PastraColors.gold : tier;
    const radius = 22.0;

    final stars = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 3; i++)
          Icon(
            i <= def.tier.index ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: i <= def.tier.index ? tier : Colors.white24,
          ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            p.tier(def.tier).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tier, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
        ),
      ],
    );
    final reroll = canReroll
        ? Tooltip(
            message: p.rerollHint,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onReroll,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.autorenew_rounded, color: Colors.white70, size: 20),
              ),
            ),
          )
        : const SizedBox(height: 28);
    final title = Text(
      p.quest(def),
      textAlign: tall ? TextAlign.center : TextAlign.start,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: quest.claimed ? Colors.white60 : Colors.white,
        fontSize: tall ? 16 : 15,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
    final count = Text(
      '${quest.progress} / ${def.goal}',
      style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w900),
    );
    final reward = _RewardPill(xp: def.xp, chips: Economy.enabled ? Quests.chipsFor(def) : 0);
    final button = SizedBox(
      height: 38,
      width: tall ? double.infinity : null,
      child: quest.claimed
          ? Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded, color: PastraColors.gold, size: 20),
                  const SizedBox(width: 6),
                  Text(p.claimed, style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800)),
                ],
              ),
            )
          : FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PastraColors.gold,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              onPressed: ready ? onClaim : null,
              child: Text(p.claim),
            ),
    );

    final body = tall
        ? LayoutBuilder(
            builder: (context, box) {
              final ring = (box.maxHeight * 0.3).clamp(46.0, 96.0);
              return Column(
                children: <Widget>[
                  Row(children: <Widget>[Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: stars)), reroll]),
                  Expanded(
                    child: Center(
                      child: _Ring(
                        size: ring,
                        fraction: quest.progress / def.goal,
                        color: accent,
                        icon: quest.claimed ? Icons.check_rounded : _kindIcon(def.kind),
                        filled: quest.done,
                      ),
                    ),
                  ),
                  title,
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: <Widget>[count, const SizedBox(width: 6), reward],
                  ),
                  const SizedBox(height: 10),
                  button,
                ],
              );
            },
          )
        : Row(
            children: <Widget>[
              _Ring(
                size: 58,
                fraction: quest.progress / def.goal,
                color: accent,
                icon: quest.claimed ? Icons.check_rounded : _kindIcon(def.kind),
                filled: quest.done,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: stars)), reroll]),
                    title,
                    const SizedBox(height: 4),
                    Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[count, reward]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 108, child: button),
            ],
          );

    return _Glow(
      active: ready,
      color: PastraColors.gold,
      radius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.fromLTRB(14, tall ? 10 : 10, tall ? 10 : 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: quest.claimed
                ? <Color>[Colors.black.withValues(alpha: 0.28), Colors.black.withValues(alpha: 0.38)]
                : <Color>[Color.lerp(tier, Colors.black, 0.72)!.withValues(alpha: 0.92), Colors.black.withValues(alpha: 0.5)],
          ),
          border: Border.all(
            color: ready ? PastraColors.gold : tier.withValues(alpha: quest.claimed ? 0.2 : 0.55),
            width: ready ? 2.2 : 1.4,
          ),
        ),
        child: body,
      ),
    );
  }
}

/// A progress ring with the quest's icon in the middle.
class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.fraction, required this.color, required this.icon, required this.filled});

  final double size;
  final double fraction;
  final Color color;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final stroke = max(4.0, size * 0.08);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.white12,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(stroke + 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? PastraColors.gold : Colors.white.withValues(alpha: 0.07),
              ),
              child: Icon(icon, size: size * 0.38, color: filled ? Colors.black : color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.xp, this.chips = 0, this.diamonds = 0, this.dark = false});

  final int xp;
  final int chips;
  final int diamonds;

  /// Black text (on the gold chest).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.black : PastraColors.gold;
    final style = TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bolt_rounded, color: color, size: 15),
          Text('$xp XP', style: style),
          if (chips > 0) ...<Widget>[
            const SizedBox(width: 6),
            const ChipIcon(size: 13),
            const SizedBox(width: 2),
            Text(Economy.short(chips), style: style),
          ],
          if (diamonds > 0) ...<Widget>[
            const SizedBox(width: 6),
            const DiamondIcon(size: 13),
            const SizedBox(width: 2),
            Text('$diamonds', style: style),
          ],
        ],
      ),
    );
  }
}

/// The daily chest: fills up with every collected quest, opens at three.
class _ChestPanel extends StatelessWidget {
  const _ChestPanel({
    required this.p,
    required this.tall,
    required this.claimed,
    required this.ready,
    required this.done,
    required this.onOpen,
  });

  final ProgressStrings p;
  final bool tall;
  final int claimed;
  final bool ready;
  final bool done;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const radius = 22.0;
    final icon = _ChestIcon(ready: ready, done: done, size: tall ? 84 : 56);
    final segments = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: tall ? 38 : 30,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i < claimed ? (ready ? Colors.black : PastraColors.gold) : Colors.white.withValues(alpha: ready ? 0.4 : 0.14),
            ),
          ),
      ],
    );
    final fg = ready ? Colors.black : Colors.white;
    final heading = Text(
      p.chest,
      textAlign: tall ? TextAlign.center : TextAlign.start,
      style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w900),
    );
    final info = Text(
      done ? p.allBonusDone : p.allBonus,
      textAlign: tall ? TextAlign.center : TextAlign.start,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: ready ? Colors.black87 : Colors.white60, fontSize: 12),
    );
    final reward = _RewardPill(
      xp: Quests.allBonusXp,
      chips: Economy.enabled ? Quests.allBonusChips : 0,
      diamonds: Economy.enabled ? Quests.allBonusDiamonds : 0,
      dark: ready,
    );
    final button = done
        ? const SizedBox.shrink()
        : SizedBox(
            height: 40,
            width: tall ? double.infinity : null,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: PastraColors.gold,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              onPressed: ready ? onOpen : null,
              icon: Icon(ready ? Icons.lock_open_rounded : Icons.lock_rounded, size: 18),
              label: Text(ready ? p.open : '$claimed / 3'),
            ),
          );

    final body = tall
        ? Column(
            children: <Widget>[
              heading,
              Expanded(child: Center(child: icon)),
              segments,
              const SizedBox(height: 8),
              if (!done) reward,
              const SizedBox(height: 6),
              info,
              const SizedBox(height: 10),
              button,
            ],
          )
        : Row(
            children: <Widget>[
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    heading,
                    const SizedBox(height: 4),
                    segments,
                    const SizedBox(height: 4),
                    info,
                  ],
                ),
              ),
              if (!done) ...<Widget>[
                const SizedBox(width: 8),
                Column(mainAxisSize: MainAxisSize.min, children: <Widget>[reward, const SizedBox(height: 6), button]),
              ],
            ],
          );

    return _Glow(
      active: ready,
      color: PastraColors.gold,
      radius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ready
                ? const <Color>[Color(0xFFFFE08A), Color(0xFFD9A21E)]
                : <Color>[const Color(0xFF3A2A10).withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.5)],
          ),
          border: Border.all(color: PastraColors.gold.withValues(alpha: ready ? 1 : 0.45), width: ready ? 2 : 1.4),
        ),
        child: body,
      ),
    );
  }
}

/// A chest drawn from icons: shakes a little when it can be opened.
class _ChestIcon extends StatelessWidget {
  const _ChestIcon({required this.ready, required this.done, required this.size});

  final bool ready;
  final bool done;
  final double size;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: ready
              ? <Color>[Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)]
              : <Color>[PastraColors.gold.withValues(alpha: 0.25), Colors.transparent],
        ),
      ),
      child: Icon(
        done ? Icons.inventory_2_rounded : Icons.redeem_rounded,
        size: size * 0.62,
        color: ready ? const Color(0xFF6B3E00) : (done ? Colors.white38 : PastraColors.gold),
      ),
    );
    if (!ready) return circle;
    return _Shake(child: circle);
  }
}

class _Shake extends StatefulWidget {
  const _Shake({required this.child});

  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // A short wiggle, then a pause.
        final t = _c.value;
        final angle = t < 0.3 ? sin(t / 0.3 * pi * 4) * 0.12 * (1 - t / 0.3) : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
    );
  }
}
