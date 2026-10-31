import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../online/room_social.dart';
import '../theme.dart';

/// Picks a ready-made message or an emoji and sends it to the table (no
/// free text: nothing rude can be written).
Future<void> showQuickChat(BuildContext context, RoomSocial social) {
  final t = SocialStrings(SettingsScope.read(context).language);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xF20E2A1F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      void send(String message) {
        social.send(message);
        Navigator.of(ctx).pop();
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(t.quickChat, style: const TextStyle(color: PastraColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final id in SocialStrings.messages)
                    ActionChip(
                      label: Text(t.chat('m:$id'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => send('m:$id'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.spaceAround,
                children: <Widget>[
                  for (final e in SocialStrings.emojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => send('e:$e'),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(e, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A message bubble that pops up next to a seat.
class QuickChatBubble extends StatelessWidget {
  const QuickChatBubble({super.key, required this.text, this.emoji = false});

  final String text;
  final bool emoji;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: EdgeInsets.symmetric(horizontal: emoji ? 10 : 12, vertical: emoji ? 4 : 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: emoji ? 30 : 14,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
