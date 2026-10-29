import 'dart:js_interop';

// The Web Audio sound engine in web/index.html (`window.pastraSfx`).

@JS('pastraSfx')
external JSObject? get _engine;

@JS('pastraSfx.load')
external void _load(String files);

@JS('pastraSfx.play')
external void _play(String file, double volume);

bool webSoundAvailable() => _engine != null;

void webSoundLoad(List<String> files) {
  if (_engine != null) _load(files.join(','));
}

void webSoundPlay(String file, double volume) {
  if (_engine != null) _play(file, volume);
}
