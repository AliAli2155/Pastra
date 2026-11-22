import 'dart:js_interop';

// The web: the browser's own description and the screen (see device_info.dart).

@JS('navigator.userAgent')
external String get _userAgent;

@JS('screen.width')
external int get _screenWidth;

@JS('screen.height')
external int get _screenHeight;

@JS('devicePixelRatio')
external double get _pixelRatio;

String? browserDescription() {
  try {
    return '$_userAgent  screen ${_screenWidth}x$_screenHeight @$_pixelRatio';
  } catch (_) {
    return null;
  }
}
