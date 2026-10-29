import 'dart:js_interop';

// The full screen helpers in web/index.html (`window.pastraFullscreen`).

@JS('pastraFullscreen')
external JSObject? get _helper;

@JS('pastraFullscreen.supported')
external bool _supported();

@JS('pastraFullscreen.isOn')
external bool _isOn();

@JS('pastraFullscreen.isIos')
external bool _isIos();

@JS('pastraFullscreen.standalone')
external bool _standalone();

@JS('pastraFullscreen.toggle')
external void _toggle();

bool fullscreenSupported() => _helper != null && _supported();

bool fullscreenOn() => _helper != null && _isOn();

/// iPhone/iPad Safari, not already opened from the home screen: full screen
/// only through "Add to Home Screen".
bool fullscreenNeedsHomeScreen() => _helper != null && _isIos() && !_standalone() && !_supported();

void fullscreenToggle() {
  if (_helper != null) _toggle();
}
