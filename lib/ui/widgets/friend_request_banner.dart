import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../online/social_service.dart';
import '../theme.dart';
import 'avatar.dart';

/// A friend request (somebody added this player by code), over every
/// screen: accept or decline it right there. Not a game invitation: it only
/// puts the two players in each other's friends list.
class FriendRequestBanner extends StatefulWidget {
  const FriendRequestBanner({super.key});

  @override
  State<FriendRequestBanner> createState() => _FriendRequestBannerState();
}

class _FriendRequestBannerState extends State<FriendRequestBanner> {
  /// Requests closed with ✕ in this session (they stay in the friends
  /// screen).
  final Set<String> _later = <String>{};

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PlayerStatus>>(
      valueListenable: SocialService.instance.requests,
      builder: (context, list, _) {
        final waiting = list.where((r) => !_later.contains(r.uid)).toList();
        if (waiting.isEmpty) return const SizedBox.shrink();
        final r = waiting.first;
        final settings = SettingsScope.of(context);
        final t = SocialStrings(settings.language);
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>(r.uid),
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.translate(offset: Offset(0, -90 * (1 - v)), child: child),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xF2181B20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: PastraColors.teal.withValues(alpha: 0.8), width: 1.5),
                      boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PlayerAvatar(name: r.name, size: 42),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                t.friendRequests,
                                style: const TextStyle(color: PastraColors.teal, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(text: r.name),
                                    TextSpan(text: ' #${r.tag}', style: const TextStyle(color: PastraColors.gold)),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: PastraColors.text, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => SocialService.instance.declineRequest(r),
                          child: Text(t.decline, style: const TextStyle(color: PastraColors.text2, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: () => SocialService.instance.acceptRequest(settings, r),
                          child: Text(t.accept),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                          onPressed: () => setState(() => _later.add(r.uid)),
                          icon: const Icon(Icons.close_rounded, color: PastraColors.muted, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
