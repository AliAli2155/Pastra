import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../build_info.dart';
import '../../game/device_info.dart';
import '../../game/freeze_log.dart';
import '../../l10n/strings.dart';
import '../fx/fx.dart';
import '../premium/premium.dart';
import '../theme.dart';

/// Preview builds, Settings > About: the freezes recorded on this device,
/// to copy and send to the developer.
class FreezeLogPanel extends StatelessWidget {
  const FreezeLogPanel({super.key});

  /// How many freezes the panel lists (the copy has them all).
  static const int shown = 6;

  static String report() => FreezeLog.report(
        device: '${deviceDescription()}\ngraphics ${Fx.mode.name}${Fx.low.value ? ' (low now)' : ''}',
        build: '${BuildInfo.channel} ${BuildInfo.commit}'.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return ValueListenableBuilder<List<Freeze>>(
      valueListenable: FreezeLog.entries,
      builder: (context, list, _) => SectionPanel(
        title: s.freezeLog,
        icon: Icons.speed_rounded,
        accent: PastraColors.coral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(s.freezeLogHint, style: PremiumText.secondary.copyWith(height: 1.4)),
            const SizedBox(height: 10),
            if (list.isEmpty)
              Text(s.freezeNone, style: PremiumText.secondary.copyWith(color: PastraColors.muted))
            else
              for (final f in list.take(shown)) _FreezeRow(freeze: f),
            if (list.length > shown)
              Text('+${list.length - shown}', style: PremiumText.secondary.copyWith(color: PastraColors.muted)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                  child: GlassButton(
                    label: s.freezeClear,
                    icon: Icons.delete_outline_rounded,
                    height: 44,
                    fontSize: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: list.isEmpty ? null : FreezeLog.clear,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: GoldButton(
                    label: s.freezeCopy,
                    icon: Icons.copy_rounded,
                    height: 44,
                    fontSize: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      await Clipboard.setData(ClipboardData(text: report()));
                      messenger?.showSnackBar(SnackBar(content: Text(s.freezeCopied), duration: const Duration(seconds: 2)));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "14:32:05 · 1.8 s" and the last things that happened before it.
class _FreezeRow extends StatelessWidget {
  const _FreezeRow({required this.freeze});

  final Freeze freeze;

  @override
  Widget build(BuildContext context) {
    final t = freeze.at;
    String two(int v) => v.toString().padLeft(2, '0');
    final notes = freeze.notes.length > 3 ? freeze.notes.sublist(freeze.notes.length - 3) : freeze.notes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${two(t.hour)}:${two(t.minute)}:${two(t.second)}  ·  ${(freeze.ms / 1000).toStringAsFixed(1)} s',
            style: const TextStyle(color: PastraColors.text, fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          for (final n in notes)
            Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PastraColors.muted, fontSize: 11.5)),
        ],
      ),
    );
  }
}
