import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/app_settings.dart';
import 'l10n/strings.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

class PastraApp extends StatelessWidget {
  const PastraApp({super.key, required this.settings});

  final AppSettings settings;

  static final ThemeData _theme = buildPastraTheme();

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: Strings(settings.language).appTitle,
          debugShowCheckedModeBanner: false,
          theme: _theme,
          locale: Locale(settings.language),
          supportedLocales: <Locale>[for (final code in AppSettings.languages) Locale(code)],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // A large font setting on the phone may grow the text a little, but
          // not so much that buttons and cards overflow.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: Stack(
              textDirection: TextDirection.ltr,
              children: <Widget>[
                child ?? const SizedBox.shrink(),
                if (_isPortraitPhone(context)) const Positioned.fill(child: _RotateHint()),
              ],
            ),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

/// The game is played sideways. Phones lock the orientation; a browser
/// cannot, so on the web a phone held upright gets this hint.
bool _isPortraitPhone(BuildContext context) {
  if (!kIsWeb) return false;
  final size = MediaQuery.sizeOf(context);
  return size.height > size.width && size.shortestSide < 700;
}

class _RotateHint extends StatelessWidget {
  const _RotateHint();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: PastraColors.feltDark,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.screen_rotation, size: 64, color: PastraColors.gold),
              const SizedBox(height: 16),
              Text(
                s.rotatePhone,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
