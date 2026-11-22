import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/freeze_log.dart';
import 'package:pastra/l10n/social_strings.dart';
import 'package:pastra/ui/screens/settings_screen.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/font_warmup.dart';
import 'package:pastra/ui/widgets/freeze_log_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screens.dart';

/// The freeze log of the preview builds: a timer that ticks every 100 ms
/// notices when the page stood still, and keeps what happened just before.
void main() {
  quietApp();

  var clock = 0;
  setUp(() {
    clock = 0;
    FreezeLog.startForTest(() => clock);
  });
  tearDown(FreezeLog.stopForTest);

  /// [n] ticks on time.
  void ticks(int n) {
    for (var i = 0; i < n; i++) {
      clock += 100;
      FreezeLog.check();
    }
  }

  test('ticks on time: nothing is recorded', () {
    ticks(50);
    expect(FreezeLog.entries.value, isEmpty);
  });

  test('a tick 1.5 s late is a freeze of 1.5 s, with what happened just before it', () {
    ticks(10);
    FreezeLog.note('long ago');
    clock += 7000;
    FreezeLog.check();
    ticks(5);
    FreezeLog.note('bot on seat 1 (master) thinks');
    clock += 300;
    FreezeLog.note('seat 1 plays (pastra)');
    clock += 1300;
    FreezeLog.check();
    final list = FreezeLog.entries.value;
    expect(list, hasLength(2), reason: 'the 7 s gap is one too');
    final f = list.first;
    expect(f.ms, 1500, reason: '300 + 1300 ms without a tick, less the 100 ms one was due anyway');
    expect(f.notes.last, contains('pastra'));
    expect(f.notes.any((n) => n.contains('master')), isTrue);
    expect(f.notes.any((n) => n.contains('long ago')), isFalse, reason: 'only the last seconds');
    // Shorter stutters are not freezes.
    clock += 500;
    FreezeLog.check();
    expect(FreezeLog.entries.value, hasLength(2));
  });

  test('time in the background does not count', () {
    ticks(3);
    FreezeLog.lifecycleForTest(AppLifecycleState.hidden);
    clock += 60000;
    FreezeLog.check();
    FreezeLog.lifecycleForTest(AppLifecycleState.resumed);
    // The first tick back is late because of the hidden time.
    clock += 900;
    FreezeLog.check();
    ticks(3);
    expect(FreezeLog.entries.value, isEmpty);
  });

  test('the newest 30 are kept, newest first', () {
    for (var i = 0; i < 40; i++) {
      FreezeLog.note('n$i');
      clock += 800 + i;
      FreezeLog.check();
    }
    final list = FreezeLog.entries.value;
    expect(list, hasLength(FreezeLog.keep));
    expect(list.first.ms, 700 + 39);
    FreezeLog.clear();
    expect(FreezeLog.entries.value, isEmpty);
  });

  test('the copy says which device, and lists every freeze with its notes', () {
    FreezeLog.note('round over');
    clock += 2100;
    FreezeLog.check();
    final text = FreezeLog.report(device: 'Safari on iPhone', build: 'preview abc1234');
    expect(text, contains('preview abc1234'));
    expect(text, contains('Safari on iPhone'));
    expect(text, contains('2.0 s'));
    expect(text, contains('round over'));
  });

  test('saved and read back', () {
    final f = Freeze(at: DateTime.utc(2026, 11, 22), ms: 900, notes: <String>['-0.4 s deal'], frame: 'frame 900 ms');
    final back = Freeze.fromJson(f.toJson());
    expect(back.ms, 900);
    expect(back.notes, f.notes);
    expect(back.frame, f.frame);
    expect(back.at.millisecondsSinceEpoch, f.at.millisecondsSinceEpoch);
    expect(Freeze.fromJson(const <String, dynamic>{}).ms, 0);
  });

  test('outside preview builds nothing is noted', () {
    FreezeLog.stopForTest();
    expect(FreezeLog.enabled, isFalse);
    FreezeLog.note('ignored');
    expect(FreezeLog.entries.value, isEmpty);
  });

  Future<void> pump(WidgetTester tester, Widget home, {Size size = const Size(844, 390)}) async {
    await loadRealFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{'language': 'en', 'sound': false});
    final settings = await AppSettings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: buildPastraTheme(), debugShowCheckedModeBanner: false, home: home),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('the panel lists the freezes; Copy puts the report on the clipboard; Clear empties it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, const Scaffold(body: SingleChildScrollView(child: FreezeLogPanel())));
    expect(find.text('No freezes so far.'), findsOneWidget);

    FreezeLog.note('bot on seat 1 (hard) thinks');
    clock += 1600;
    FreezeLog.check();
    await tester.pumpAndSettle();
    expect(find.textContaining('1.5 s'), findsOneWidget);
    expect(find.textContaining('hard'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, contains('bot on seat 1 (hard) thinks'));
    expect(find.text('Copied'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No freezes so far.'), findsOneWidget);
  });

  for (final size in <Size>[const Size(844, 390), const Size(1280, 720)]) {
    testWidgets('Settings > About shows the log in preview builds (${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      for (var i = 0; i < 8; i++) {
        FreezeLog.note('note $i');
        clock += 900;
        FreezeLog.check();
      }
      await pump(tester, const SettingsScreen(initialTab: 4), size: size);
      expect(find.byType(FreezeLogPanel), findsOneWidget);
      expect(find.text('Freeze log'), findsOneWidget);
    });
  }

  testWidgets('the chat emojis are laid out (their font fetched) once the online part asks for them', (tester) async {
    await pump(tester, const Scaffold(body: FontWarmup()));
    String sample() => tester.widget<Text>(find.byType(Text, skipOffstage: false)).data!;
    expect(sample(), contains('♣'));
    expect(sample(), isNot(contains(SocialStrings.emojis.first)));
    FontWarmup.wantEmojis();
    await tester.pump();
    for (final e in SocialStrings.emojis) {
      expect(sample(), contains(e));
    }
  });
}
