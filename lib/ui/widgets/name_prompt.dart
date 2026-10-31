import 'package:flutter/material.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../theme.dart';

/// Asks the player's name (first game, joining by link) and saves it.
/// Returns the name, or null when the player chose "later".
Future<String?> askPlayerName(BuildContext context) async {
  final settings = SettingsScope.read(context);
  final t = SocialStrings(settings.language);
  final controller = TextEditingController(text: settings.playerName);
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      void done() => Navigator.of(ctx).pop(controller.text.trim());
      return AlertDialog(
        icon: const Icon(Icons.badge_rounded, color: PastraColors.gold, size: 40),
        title: Text(t.yourName, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 16,
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: t.nameHint,
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.25),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => done(),
            ),
            Text(t.nameWhy, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.later)),
          FilledButton(onPressed: done, child: Text(t.save)),
        ],
      );
    },
  );
  if (name == null || name.isEmpty) return null;
  settings.playerName = name.length > 16 ? name.substring(0, 16) : name;
  return settings.playerName;
}
