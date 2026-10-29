// Not on the web: no Web Audio engine (see sound_web.dart).

bool webSoundAvailable() => false;

void webSoundLoad(List<String> files) {}

void webSoundPlay(String file, double volume) {}
