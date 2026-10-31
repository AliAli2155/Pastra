import '../ui/share_stub.dart' if (dart.library.js_interop) '../ui/share_web.dart';

/// Invite links that open the game and join a room:
/// `https://aliali2155.github.io/Pastra/#/oda/1234`.
class InviteLink {
  InviteLink._();

  /// The published web version (used by the phone apps).
  static const String home = 'https://aliali2155.github.io/Pastra/';

  static String forCode(String code) => '${pageAddress() ?? home}#/oda/$code';

  static String whatsapp(String text) => 'https://wa.me/?text=${Uri.encodeComponent(text)}';

  static String telegram(String url, String text) =>
      'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(text)}';

  /// The code of the link the web app was opened with (once).
  static String? takePending() => takeInviteCode();

  /// The room code in an address like `…#/oda/1234` (or `#/room/1234`).
  static String? codeIn(String address) {
    final m = RegExp(r'#/(?:oda|room)/(\d{4})/?$').firstMatch(address);
    return m?.group(1);
  }
}
