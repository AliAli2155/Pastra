import 'dart:js_interop';

import 'package:flutter/widgets.dart';

// The safe area helper in web/index.html (`window.pastraSafeArea`).

@JS('pastraSafeArea')
external JSFunction? get _helper;

@JS('pastraSafeArea')
external String _safeArea();

/// The notch / home bar insets of the phone. The page draws over the whole
/// screen, so the content has to stay out of these by itself.
EdgeInsets webSafeArea() {
  if (_helper == null) return EdgeInsets.zero;
  try {
    final v = _safeArea().split(',').map((e) => double.tryParse(e) ?? 0).toList();
    if (v.length != 4) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(v[3], v[0], v[1], v[2]);
  } catch (_) {
    return EdgeInsets.zero;
  }
}
