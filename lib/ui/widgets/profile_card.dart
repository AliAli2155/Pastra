import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/avatar_pic.dart';
import '../../game/friends.dart';
import '../../game/progression.dart';
import '../../l10n/progress_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/social_service.dart';
import '../premium/premium.dart';
import '../theme.dart';
import 'avatar.dart';
import 'playing_card.dart';

/// The player's profile: avatar and frame, name and code, title, level with
/// its bar, the main statistics, the chosen table and card back, and the
/// ways to the level path and to the appearance settings.
Future<void> showMyProfile(
  BuildContext context, {
  required VoidCallback onLevelPath,
  required VoidCallback onAppearance,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => PremiumDialog(
      maxWidth: 520,
      child: _MyProfile(
        onLevelPath: () {
          Navigator.of(ctx).pop();
          onLevelPath();
        },
        onAppearance: () {
          Navigator.of(ctx).pop();
          onAppearance();
        },
      ),
    ),
  );
}

/// A friend's profile: what is known about them (avatar, name and code,
/// level, online or last seen, games together).
Future<void> showFriendProfile(BuildContext context, Friend friend, PlayerStatus? status) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => PremiumDialog(maxWidth: 420, child: _FriendProfile(friend: friend, status: status)),
  );
}

class _MyProfile extends StatelessWidget {
  const _MyProfile({required this.onLevelPath, required this.onAppearance});

  final VoidCallback onLevelPath;
  final VoidCallback onAppearance;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final p = ProgressStrings(settings.language);
    final st = settings.stats;
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;
    final tag = settings.playerTag;
    final level = settings.playerLevel;
    final prog = Progression.progress(settings.xp);
    final fraction = level >= Progression.maxLevel
        ? 1.0
        : (prog.needed == 0 ? 0.0 : (prog.into / prog.needed).clamp(0.0, 1.0).toDouble());
    final rate = st.games == 0 ? '–' : '${(st.wins * 100 / st.games).round()}%';

    Widget stat(String value, String label, IconData icon) => Expanded(
          child: Column(
            children: <Widget>[
              Icon(icon, size: 18, color: PastraColors.gold),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: PastraColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: PremiumText.secondary.copyWith(fontSize: 11, height: 1.15),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              PlayerAvatar(name: name, pic: settings.avatarPic, frame: settings.avatarFrame, size: 78),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: name),
                          if (tag != null)
                            TextSpan(text: '  #$tag', style: const TextStyle(color: PastraColors.muted, fontSize: 15)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PastraColors.text, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            p.title(settings.title),
                            style: const TextStyle(
                                color: PastraColors.goldLight, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          s.levelN(level),
                          style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: const Color(0xFF2E333B),
                          valueColor: const AlwaysStoppedAnimation<Color>(PastraColors.gold),
                        ),
                      ),
                    ),
                    if (level < Progression.maxLevel) ...<Widget>[
                      const SizedBox(height: 3),
                      Text('${prog.into} / ${prog.needed} XP', style: PremiumText.secondary.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: glassDecoration(radius: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                stat('${st.games}', s.statGames, Icons.casino_outlined),
                stat(rate, s.statWinRate, Icons.emoji_events_outlined),
                stat('${st.bestStreak}', s.statBestStreak, Icons.local_fire_department_outlined),
                stat('${st.pastras}', s.statPastras, Icons.auto_awesome),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // The table and the card back the player plays with.
          Row(
            children: <Widget>[
              Expanded(
                child: _Look(
                  label: s.tableColor,
                  child: DecoratedBox(
                    decoration: settings.tableTheme.decoration.copyWith(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: PastraColors.wood, width: 2.5),
                    ),
                    child: const SizedBox(width: 52, height: 36),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Look(
                  label: s.cardBackLabel,
                  child: SizedBox(
                    width: 28,
                    height: 39,
                    child: PlayingCardView(card: 0, faceUp: false, backStyle: settings.cardBack),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                  child:
                      GlassButton(label: p.levelPath, icon: Icons.route_rounded, height: 46, fontSize: 16, onPressed: onLevelPath)),
              const SizedBox(width: 10),
              Expanded(
                  child: GoldButton(
                      label: s.appearance, icon: Icons.palette_rounded, height: 46, fontSize: 16, onPressed: onAppearance)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small glass box: a picture and its label.
class _Look extends StatelessWidget {
  const _Look({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: glassDecoration(radius: 14),
      child: Row(
        children: <Widget>[
          child,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: PastraColors.text2, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendProfile extends StatelessWidget {
  const _FriendProfile({required this.friend, required this.status});

  final Friend friend;
  final PlayerStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final st = status;
    final name = friend.name.isEmpty ? (st?.name ?? '') : friend.name;
    final tag = st?.tag.isNotEmpty == true ? st!.tag : friend.tag;
    final online = st?.online ?? false;
    final now = DateTime.now();
    final seen = st?.seen ?? 0;
    final line = online
        ? t.online
        : (seen > 0
            ? t.lastSeen(t.when(DateTime.fromMillisecondsSinceEpoch(seen), now))
            : t.when(DateTime.fromMillisecondsSinceEpoch(friend.lastPlayed), now));
    final level = st?.level ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PlayerAvatar(
            name: name,
            size: 84,
            pic: AvatarPic.byName(st?.pic ?? friend.pic),
            frame: avatarFrameByName(st?.frame ?? friend.frame),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: name),
                if (tag.isNotEmpty)
                  TextSpan(text: '  #$tag', style: const TextStyle(color: PastraColors.muted, fontSize: 15)),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: PastraColors.text, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: <Widget>[
              if (level > 0)
                Text(s.levelN(level),
                    style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? PastraColors.teal : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(line, style: PremiumText.secondary.copyWith(fontSize: 13)),
                ],
              ),
            ],
          ),
          if (friend.games > 0) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: glassDecoration(radius: 12),
              child:
                  Text(t.gamesTogether(friend.games), style: const TextStyle(color: PastraColors.text, fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }
}
