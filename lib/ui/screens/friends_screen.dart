import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../game/friends.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/invites.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../../online/social_service.dart';
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

  /// Live status of every friend (online, current name and code).
  final Map<String, PlayerStatus> _status = <String, PlayerStatus>{};
  final Map<String, StreamSubscription<PlayerStatus?>> _subs = <String, StreamSubscription<PlayerStatus?>>{};

  @override
  void initState() {
    super.initState();
    final settings = SettingsScope.read(context);
    // Gives the player their code (and shows them online to their friends).
    SocialService.instance.start(settings).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchFriends(SettingsScope.of(context).friends);
  }

  void _watchFriends(List<Friend> friends) {
    final settings = SettingsScope.read(context);
    final uids = friends.map((f) => f.uid).toSet();
    for (final uid in _subs.keys.where((u) => !uids.contains(u)).toList()) {
      _subs.remove(uid)?.cancel();
    }
    for (final uid in uids) {
      if (_subs.containsKey(uid)) continue;
      _subs[uid] = SocialService.watch(uid).listen(
        (st) {
          if (st == null || !mounted) return;
          setState(() => _status[uid] = st);
          settings.updateFriendInfo(uid, name: st.name, tag: st.tag);
        },
        onError: (Object _) {},
      );
    }
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

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

  /// "Add friend": name + code, like Ali #2155.
  Future<void> _addFriend() async {
    final settings = SettingsScope.read(context);
    final t = SocialStrings(settings.language);
    final o = OnlineStrings(settings.language);
    final messenger = ScaffoldMessenger.of(context);
    final text = await showDialog<String>(context: context, builder: (_) => const _AddFriendDialog());
    if (text == null || !mounted) return;
    final parsed = PlayerHandle.parse(text);
    if (parsed == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.addFriendHint)));
      return;
    }
    setState(() => _busy = true);
    try {
      final found = await SocialService.find(parsed.$1, parsed.$2);
      if (!mounted) return;
      if (found == null) {
        messenger.showSnackBar(SnackBar(content: Text(t.codeNotFound)));
      } else if (found.uid == OnlineService.uid) {
        messenger.showSnackBar(SnackBar(content: Text(t.thatsYou)));
      } else {
        final already = settings.friends.any((f) => f.uid == found.uid && f.favorite);
        settings.addFriend(uid: found.uid, name: found.name, tag: found.tag);
        final handle = PlayerHandle.format(found.name, found.tag);
        messenger.showSnackBar(SnackBar(content: Text(already ? t.alreadyFriend(handle) : t.friendAdded(handle))));
      }
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
    bool online(Friend f) => _status[f.uid]?.online ?? false;
    List<Friend> sorted(Iterable<Friend> list) {
      final l = list.toList();
      // Online first, otherwise the order of the list (newest first).
      l.sort((a, b) => (online(b) ? 1 : 0).compareTo(online(a) ? 1 : 0));
      return l;
    }

    final favs = sorted(friends.where((f) => f.favorite));
    final recent = sorted(friends.where((f) => !f.favorite));
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
    Widget row(Friend f) => _FriendRow(
          friend: f,
          busy: _busy,
          status: _status[f.uid],
          onInvite: () => _invite(f),
          onRemove: () => settings.removeFriend(f.uid),
        );
    return Scaffold(
      body: Felt(
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  GameHeader(
                    title: t.friends,
                    icon: Icons.people_alt_rounded,
                    trailing: <Widget>[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: PastraColors.gold, foregroundColor: Colors.black),
                        onPressed: _busy ? null : _addFriend,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: Text(t.addFriend, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          children: <Widget>[
                            const _MyCodeCard(),
                            if (friends.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: <Widget>[
                                    const Icon(Icons.people_outline_rounded, color: Colors.white38, size: 52),
                                    const SizedBox(height: 10),
                                    Text(
                                      t.noFriends,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            if (favs.isNotEmpty) ...<Widget>[
                              section(t.favorites, Icons.star_rounded),
                              for (final f in favs) row(f),
                            ],
                            if (recent.isNotEmpty) ...<Widget>[
                              section(t.recent, Icons.history_rounded),
                              for (final f in recent) row(f),
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

/// The player's own code with a copy button.
class _MyCodeCard extends StatelessWidget {
  const _MyCodeCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final s = Strings.of(context);
    final name = settings.playerName.isEmpty ? s.you : settings.playerName;
    final tag = settings.playerTag;
    final handle = tag == null ? null : PlayerHandle.format(name, tag);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: <Color>[Color(0xFF1E5A43), Color(0xFF0B2A1E)]),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: <Widget>[
          PlayerAvatar(name: name, frame: settings.avatarFrame, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(t.friendCode, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (handle == null)
                  Text(t.codeWait, style: const TextStyle(color: Colors.white70, fontSize: 14))
                else
                  _HandleText(name: name, tag: tag!, size: 20),
                Text(t.friendCodeHint, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (handle != null)
            IconButton(
              tooltip: t.codeCopied,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: handle));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(t.codeCopied), duration: const Duration(seconds: 2)));
              },
              icon: const Icon(Icons.copy_rounded, color: PastraColors.gold),
            ),
        ],
      ),
    );
  }
}

/// "Ali #2155": the name in white, the code in gold.
class _HandleText extends StatelessWidget {
  const _HandleText({required this.name, required this.tag, this.size = 16});

  final String name;
  final String tag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: name, style: const TextStyle(color: Colors.white)),
          if (tag.isNotEmpty) TextSpan(text: ' #$tag', style: const TextStyle(color: PastraColors.gold)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w900),
    );
  }
}

class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog();

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SocialStrings(SettingsScope.of(context).language);
    void done() => Navigator.of(context).pop(_text.text);
    return AlertDialog(
      icon: const Icon(Icons.person_add_alt_1_rounded, color: PastraColors.gold, size: 40),
      title: Text(t.addFriend, textAlign: TextAlign.center),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLength: 24,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: 'Ali #2155',
          helperText: t.addFriendHint,
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.25),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (_) => done(),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(Strings.of(context).cancel)),
        FilledButton(onPressed: done, child: Text(t.add)),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.busy,
    required this.onInvite,
    this.inviteLabel,
    this.status,
    this.onRemove,
  });

  final Friend friend;
  final bool busy;
  final VoidCallback onInvite;
  final String? inviteLabel;
  final PlayerStatus? status;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = SocialStrings(settings.language);
    final o = OnlineStrings(settings.language);
    final name = friend.name.isEmpty ? o.defaultName : friend.name;
    final now = DateTime.now();
    final online = status?.online ?? false;
    final seen = status?.seen ?? 0;
    final String line;
    if (online) {
      line = t.online;
    } else if (seen > 0) {
      line = t.lastSeen(t.when(DateTime.fromMillisecondsSinceEpoch(seen), now));
    } else {
      line = '${t.when(DateTime.fromMillisecondsSinceEpoch(friend.lastPlayed), now)}'
          '${friend.games > 0 ? ' · ${t.gamesTogether(friend.games)}' : ''}';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: online ? const Color(0xFF5BD69A).withValues(alpha: 0.7) : (friend.favorite ? PastraColors.gold.withValues(alpha: 0.5) : Colors.white12),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Avatar with a green dot while online.
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              PlayerAvatar(name: name, size: 42),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: online ? const Color(0xFF3DDC84) : const Color(0xFF6B7280),
                    border: Border.all(color: const Color(0xFF0E2A1F), width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _HandleText(name: name, tag: friend.tag),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: online ? const Color(0xFF5BD69A) : Colors.white54, fontSize: 12, fontWeight: online ? FontWeight.w700 : FontWeight.w400),
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
          if (onRemove != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
              onSelected: (_) => onRemove!(),
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'remove', child: Text(t.removeFriend)),
              ],
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
