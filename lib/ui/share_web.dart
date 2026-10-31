import 'dart:js_interop';

// The helpers in web/index.html (`pastraTakeInvite`, `pastraShare`, …).

@JS('pastraTakeInvite')
external JSFunction? get _takeFn;

@JS('pastraTakeInvite')
external String _take();

@JS('pastraCanShare')
external JSFunction? get _canShareFn;

@JS('pastraCanShare')
external bool _canShare();

@JS('pastraShare')
external bool _share(String text, String url);

@JS('pastraOpen')
external JSFunction? get _openFn;

@JS('pastraOpen')
external void _open(String url);

String? takeInviteCode() {
  if (_takeFn == null) return null;
  try {
    final code = _take();
    return RegExp(r'^\d{4}$').hasMatch(code) ? code : null;
  } catch (_) {
    return null;
  }
}

String? pageAddress() => Uri.base.removeFragment().toString();

bool shareSheet(String text, String url) {
  try {
    if (_canShareFn == null || !_canShare()) return false;
    return _share(text, url);
  } catch (_) {
    return false;
  }
}

bool openLink(String url) {
  if (_openFn == null) return false;
  try {
    _open(url);
    return true;
  } catch (_) {
    return false;
  }
}
