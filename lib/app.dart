import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/app_settings.dart';
import 'l10n/strings.dart';
import 'ui/safe_area_stub.dart' if (dart.library.js_interop) 'ui/safe_area_web.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/invite_banner.dart';
import 'ui/theme.dart';

class PastraApp extends StatelessWidget {
  const PastraApp({super.key, required this.settings});

  final AppSettings settings;

  static final ThemeData _theme = buildPastraTheme();

  /// For the keyboard: Esc goes back on computers.
  static final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => MaterialApp(
          title: Strings(settings.language).appTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigator,
          theme: _theme,
          locale: Locale(settings.language),
          supportedLocales: <Locale>[for (final code in AppSettings.languages) Locale(code)],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // A large font setting on the phone may grow the text a little, but
          // not so much that buttons and cards overflow.
          builder: (context, child) => MediaQuery(
            data: _withWebSafeArea(MediaQuery.of(context)).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
            ),
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.escape): () => _navigator.currentState?.maybePop(),
              },
              child: Stack(
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  // Web: the browser fetches the fonts for Arabic and Chinese
                  // only when such text is first laid out, and text drawn
                  // before they arrive stays garbled (the language list in
                  // the settings). Laying out a hidden sample at the start
                  // loads them early.
                  if (kIsWeb) const Offstage(child: Text('العربية 中文 Ελληνικά Български')),
                  child ?? const SizedBox.shrink(),
                  // A friend's invitation, over every screen.
                  Positioned.fill(child: InviteBanner(navigator: _navigator)),
                  if (_isPortraitPhone(context)) const Positioned.fill(child: _RotateHint()),
                ],
              ),
            ),
          ),
          // Invite links (#/oda/1234) are taken out of the address by
          // web/index.html before Flutter starts, so the app always opens on
          // the home screen (which then joins the room).
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

/// Web: the page fills the whole screen (behind the notch and the home bar
/// too), so the felt reaches every edge. Flutter does not get the safe area
/// from the browser; it is read from CSS and added here, and every SafeArea
/// keeps the buttons and cards out of it. Read again whenever the size
/// changes (turning the phone).
MediaQueryData _withWebSafeArea(MediaQueryData data) {
  if (!kIsWeb) return data;
  final web = webSafeArea();
  if (web == EdgeInsets.zero) return data;
  EdgeInsets most(EdgeInsets a) => EdgeInsets.fromLTRB(
        a.left > web.left ? a.left : web.left,
        a.top > web.top ? a.top : web.top,
        a.right > web.right ? a.right : web.right,
        a.bottom > web.bottom ? a.bottom : web.bottom,
      );
  return data.copyWith(padding: most(data.padding), viewPadding: most(data.viewPadding));
}

/// The game is played sideways. Phones lock the orientation; a browser
/// cannot, so on the web a phone held upright gets this hint.
bool _isPortraitPhone(BuildContext context) {
  if (!kIsWeb) return false;
  // Only phones: a narrow browser window on a computer just gets the
  // upright layout (like a tablet held upright).
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return false;
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
