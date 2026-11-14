import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../l10n/social_strings.dart';
import '../../online/invite_link.dart';
import '../share_stub.dart' if (dart.library.js_interop) '../share_web.dart';
import '../premium/premium.dart';

/// The two ways to bring people to the room: the invite link (the phone's
/// share sheet; copied where there is none) and, with [onInviteFriends],
/// a direct invite to friends. Two equal buttons side by side.
class InviteShareRow extends StatelessWidget {
  const InviteShareRow({super.key, required this.code, this.onInviteFriends});

  final String code;
  final VoidCallback? onInviteFriends;

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

    final friends = onInviteFriends;
    return Row(
      children: <Widget>[
        Expanded(
          child: GoldButton(
            label: kIsWeb ? t.shareInvite : t.copyLink,
            icon: kIsWeb ? Icons.ios_share_rounded : Icons.link_rounded,
            height: 46,
            fontSize: 15,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: kIsWeb ? share : copy,
          ),
        ),
        if (friends != null) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: GlassButton(
              label: t.inviteFriends,
              icon: Icons.people_alt_rounded,
              height: 46,
              fontSize: 15,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: friends,
            ),
          ),
        ],
      ],
    );
  }
}
