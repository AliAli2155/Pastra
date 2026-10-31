import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/friends.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/invites.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/game_header.dart';
import 'online_screen.dart';

/// People met online: favourites first, then the most recent. One tap opens
/// a private table and invites them.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _busy = false;

  /// Opens a private 1v1 table, invites [f] and goes to the waiting room.
  Future<void> _invite(Friend f) async {
    final settings = SettingsScope.read(context);
    final t = SocialStrings(settings.language);
    final o = OnlineStrings(settings.language);
    final s = Strings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (await OnlineService.ensureReady() != null) throw const OnlineException('network');
      final name = settings.playerName.isEmpty ? s.you : settings.playerName;
      final room = await HostRoom.create(
        settings,
        players: 2,
        level: settings.level,
        name: name,
        stake: Economy.enabled ? Economy.salons.first.stake : 0,
      );
      await Invites.send(toUid: f.uid, name: name, code: room.code);
      if (!mounted) {
        room.close();
        return;
      }
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(t.inviteSent(f.name.isEmpty ? o.defaultName : f.name))));
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(o.error('network'))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final friends = settings.friends;
    final favs = <Friend>[for (final f in friends) if (f.favorite) f];
    final recent = <Friend>[for (final f in friends) if (!f.favorite) f];
    Widget section(String title, IconData icon) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: PastraColors.gold, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: PastraColors.gold, fontSize: 15, fontWeight: FontWeight.w900)),
            ],
          ),
        );
    return Scaffold(
      body: Felt(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  GameHeader(title: t.friends, icon: Icons.people_alt_rounded),
                  Expanded(
                    child: friends.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.people_outline_rounded, color: Colors.white38, size: 56),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.noFriends,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                children: <Widget>[
                                  if (favs.isNotEmpty) ...<Widget>[
                                    section(t.favorites, Icons.star_rounded),
                                    for (final f in favs) _FriendRow(friend: f, busy: _busy, onInvite: () => _invite(f)),
                                  ],
                                  if (recent.isNotEmpty) ...<Widget>[
                                    section(t.recent, Icons.history_rounded),
                                    for (final f in recent) _FriendRow(friend: f, busy: _busy, onInvite: () => _invite(f)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.busy, required this.onInvite, this.inviteLabel});

  final Friend friend;
  final bool busy;
  final VoidCallback onInvite;
  final String? inviteLabel;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final o = OnlineStrings(settings.language);
    final name = friend.name.isEmpty ? o.defaultName : friend.name;
    final when = t.when(DateTime.fromMillisecondsSinceEpoch(friend.lastPlayed), DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: friend.favorite ? PastraColors.gold.withValues(alpha: 0.6) : Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          PlayerAvatar(name: name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  '$when · ${t.gamesTogether(friend.games)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.favorites,
            onPressed: () => settings.setFavorite(friend.uid, !friend.favorite),
            icon: Icon(
              friend.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: friend.favorite ? PastraColors.gold : Colors.white54,
            ),
          ),
          FilledButton.icon(
            onPressed: busy ? null : onInvite,
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(inviteLabel ?? t.invite),
          ),
        ],
      ),
    );
  }
}

/// Lobby: invites friends to this room (one tap each).
Future<void> showInviteFriendsSheet(BuildContext context, String code) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0E2A1F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _InviteSheet(code: code),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.code});

  final String code;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final Set<String> _sent = <String>{};

  Future<void> _send(Friend f) async {
    final settings = SettingsScope.read(context);
    final name = settings.playerName.isEmpty ? Strings.of(context).you : settings.playerName;
    setState(() => _sent.add(f.uid));
    final ok = await Invites.send(toUid: f.uid, name: name, code: widget.code);
    if (!ok && mounted) setState(() => _sent.remove(f.uid));
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final friends = settings.friends;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(t.inviteFriends, style: const TextStyle(color: PastraColors.gold, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(t.noFriends, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final f in friends)
                        _FriendRow(
                          friend: f,
                          busy: _sent.contains(f.uid),
                          inviteLabel: _sent.contains(f.uid) ? '✓' : null,
                          onInvite: () => _send(f),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
