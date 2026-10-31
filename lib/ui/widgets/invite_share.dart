import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../online/invite_link.dart';
import '../share_stub.dart' if (dart.library.js_interop) '../share_web.dart';
import '../theme.dart';

/// Buttons to send the room's invite link: the phone's share sheet (or copy),
/// WhatsApp and Telegram (web), copy.
class InviteShareRow extends StatelessWidget {
  const InviteShareRow({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final t = SocialStrings(SettingsScope.of(context).language);
    final link = InviteLink.forCode(code);
    final text = t.inviteText(code, link);

    void copy() {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.linkCopied), duration: const Duration(seconds: 2)));
    }

    void share() {
      if (!shareSheet(t.inviteText(code, '').trim(), link)) copy();
    }

    // A small labelled button in the app's colour (WhatsApp green, …).
    Widget pill(String label, IconData icon, Color color, VoidCallback onTap) => Material(
          color: color,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: PastraColors.gold,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          onPressed: kIsWeb ? share : copy,
          icon: Icon(kIsWeb ? Icons.ios_share_rounded : Icons.link_rounded, size: 18),
          label: Text(kIsWeb ? t.shareInvite : t.copyLink),
        ),
        if (kIsWeb) ...<Widget>[
          pill('WhatsApp', Icons.chat_rounded, const Color(0xFF25A35A), () => openLink(InviteLink.whatsapp(text))),
          pill(
            'Telegram',
            Icons.send_rounded,
            const Color(0xFF229ED9),
            () => openLink(InviteLink.telegram(link, t.inviteText(code, '').trim())),
          ),
          pill(t.copyLink, Icons.link_rounded, Colors.white24, copy),
        ],
      ],
    );
  }
}
