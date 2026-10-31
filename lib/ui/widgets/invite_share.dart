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

    Widget round(String tooltip, Widget icon, Color color, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
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
          round(
            'WhatsApp',
            const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
            const Color(0xFF25D366),
            () => openLink(InviteLink.whatsapp(text)),
          ),
          round(
            'Telegram',
            const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            const Color(0xFF229ED9),
            () => openLink(InviteLink.telegram(link, t.inviteText(code, '').trim())),
          ),
          round(t.copyLink, const Icon(Icons.link_rounded, color: Colors.white, size: 22), Colors.white24, copy),
        ],
      ],
    );
  }
}
