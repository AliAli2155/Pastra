import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../online/invites.dart';
import '../screens/online_screen.dart';
import '../theme.dart';
import 'avatar.dart';

/// Off in widget tests (no Firebase there).
bool inviteListenerEnabled = true;

/// A friend's invitation to a table, over every screen: join with one tap.
/// Only listens for players who have played online (they have friends).
class InviteBanner extends StatefulWidget {
  const InviteBanner({super.key, required this.navigator});

  final GlobalKey<NavigatorState> navigator;

  @override
  State<InviteBanner> createState() => _InviteBannerState();
}

class _InviteBannerState extends State<InviteBanner> {
  StreamSubscription<List<TableInvite>>? _sub;
  List<TableInvite> _invites = const <TableInvite>[];
  final Set<String> _hidden = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = SettingsScope.of(context);
    if (_sub == null && inviteListenerEnabled && settings.friends.isNotEmpty) {
      _sub = Invites.watch().listen(
        (list) {
          if (mounted) setState(() => _invites = list);
        },
        onError: (Object _) {},
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _key(TableInvite i) => '${i.fromUid}/${i.time}';

  void _close(TableInvite i) {
    setState(() => _hidden.add(_key(i)));
    Invites.dismiss(i.fromUid);
  }

  void _join(TableInvite i) {
    _close(i);
    widget.navigator.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => OnlineScreen(joinCode: i.code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _invites.where((i) => !_hidden.contains(_key(i))).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final invite = visible.first;
    final t = SocialStrings(SettingsScope.of(context).language);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: TweenAnimationBuilder<double>(
            key: ValueKey<String>(_key(invite)),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Transform.translate(offset: Offset(0, -80 * (1 - v)), child: child),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                  color: const Color(0xF2102A1F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: PastraColors.gold, width: 1.5),
                  boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PlayerAvatar(name: invite.name, size: 38),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        t.invitedYou(invite.name.isEmpty ? '?' : invite.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: PastraColors.gold, foregroundColor: Colors.black),
                      onPressed: () => _join(invite),
                      child: Text(t.join),
                    ),
                    IconButton(
                      onPressed: () => _close(invite),
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
