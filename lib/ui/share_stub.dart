// Phones and computers (not the web): no invite link in the address and no
// web share sheet; links open in the browser (see share_web.dart).

/// The room code of an invite link the app was opened with (web only).
String? takeInviteCode() => null;

/// The web page address the app runs on (null outside the web).
String? pageAddress() => null;

/// Opens the phone's share sheet; false when there is none.
bool shareSheet(String text, String url) => false;

/// Opens [url] in the browser / the app that handles it.
bool openLink(String url) => false;
