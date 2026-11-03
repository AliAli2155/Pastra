import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the chosen graphics quality decides', () {
    Fx.setMode(FxMode.low);
    expect(Fx.low.value, isTrue);
    Fx.setMode(FxMode.high);
    expect(Fx.low.value, isFalse);
    // Automatic starts with full quality; only slow frames lower it.
    Fx.setMode(FxMode.auto);
    expect(Fx.low.value, isFalse);
  });

  test('the graphics quality is saved with the settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    expect(settings.fxMode, FxMode.auto);
    settings.fxMode = FxMode.low;
    expect(Fx.low.value, isTrue);
    final again = await AppSettings.load();
    expect(again.fxMode, FxMode.low);
    expect(Fx.low.value, isTrue);
    settings.fxMode = FxMode.auto;
  });
}
