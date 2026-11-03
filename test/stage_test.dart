import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/pastra_ai.dart';
import 'package:pastra/engine/pastra_engine.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/game/game_controller.dart';
import 'package:pastra/ui/ege/fly_card.dart';
import 'package:pastra/ui/ege/table_stage.dart';
import 'package:pastra/ui/fx/fx.dart';
import 'package:pastra/ui/screens/game_screen.dart';
import 'package:pastra/ui/table_layout.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/playing_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where [StageGeometry.matrix] (turned about the bottom centre, as
/// [TableStage] does it) puts a point of the flat table, on the area.
Offset throughMatrix(StageGeometry g, Offset p) {
  final pivot = Offset(g.size.width / 2, g.size.height);
  final m = Matrix4.translationValues(pivot.dx, pivot.dy, 0) *
      g.matrix *
      Matrix4.translationValues(-pivot.dx, -pivot.dy, 0);
  // The tilted table hangs from the bottom of the area.
  return MatrixUtils.transformPoint(m, p) + Offset(0, g.area.height - g.size.height);
}

void main() {
  const areas = <Size>[Size(844, 342), Size(390, 700), Size(1280, 680), Size(2200, 1200)];

  group('StageGeometry', () {
    test('project() is what the Transform does with the table', () {
      for (final area in areas) {
        final g = StageGeometry.fit(area);
        expect(g.tilted, isTrue);
        expect(g.size.width, area.width);
        expect(g.size.height, greaterThan(area.height));
        for (var i = 0; i <= 6; i++) {
          for (var j = 0; j <= 6; j++) {
            final p = Offset(g.size.width * i / 6, g.size.height * j / 6);
            final a = g.project(p);
            final b = throughMatrix(g, p);
            expect(a.dx, closeTo(b.dx, 1e-6), reason: '$area $p');
            expect(a.dy, closeTo(b.dy, 1e-6), reason: '$area $p');
          }
        }
      }
    });

    test('the near edge is the bottom of the area, the far edge a little below the top', () {
      for (final area in areas) {
        final g = StageGeometry.fit(area);
        final nearMiddle = g.project(Offset(g.size.width / 2, g.size.height));
        expect(nearMiddle.dx, closeTo(area.width / 2, 1e-6));
        expect(nearMiddle.dy, closeTo(area.height, 1e-6));
        final farMiddle = g.project(Offset(g.size.width / 2, 0));
        expect(farMiddle.dy, closeTo(StageGeometry.farMarginFor(area), 1e-6));
        // The far edge is narrower than the near edge.
        final farLeft = g.project(Offset.zero);
        expect(farLeft.dx, greaterThan(0));
        expect(g.project(Offset(0, g.size.height)).dx, closeTo(0, 1e-6));
      }
    });

    test('things are smaller further away', () {
      final g = StageGeometry.fit(areas.first);
      expect(g.scaleAt(Offset(0, g.size.height)), closeTo(1, 1e-9));
      final far = g.scaleAt(Offset.zero);
      expect(far, lessThan(0.9));
      expect(far, greaterThan(0.7));
      expect(g.scaleAt(Offset(0, g.size.height / 2)), inInclusiveRange(far, 1));
    });

    test('projectRect() holds the whole projected rectangle', () {
      final g = StageGeometry.fit(areas.first);
      final r = Rect.fromLTWH(g.size.width * 0.1, g.size.height * 0.2, g.size.width * 0.5, g.size.height * 0.4);
      final box = g.projectRect(r).inflate(1e-6);
      for (var i = 0; i <= 4; i++) {
        for (var j = 0; j <= 4; j++) {
          final p = Offset(r.left + r.width * i / 4, r.top + r.height * j / 4);
          expect(box.contains(g.project(p)), isTrue, reason: '$p');
        }
      }
    });

    test('a flat table (low quality, tiny areas) is not moved at all', () {
      for (final g in <StageGeometry>[
        StageGeometry.fit(areas.first, tilted: false),
        StageGeometry.fit(const Size(180, 120)),
      ]) {
        expect(g.tilted, isFalse);
        expect(g.size, g.area);
        const p = Offset(33, 21);
        expect(g.project(p), p);
        expect(g.scaleAt(p), 1);
        const r = Rect.fromLTWH(3, 4, 50, 70);
        expect(g.projectRect(r), r);
      }
    });
  });

  group('TableStage', () {
    Widget host(StageGeometry g, Widget stage) => MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: SizedBox.fromSize(size: g.area, child: stage)),
          ),
        );

    testWidgets('a tap lands on the card where it is seen, not where it lies flat', (tester) async {
      final g = StageGeometry.fit(const Size(600, 400));
      const card = Rect.fromLTWH(60, 20, 100, 60);
      var taps = 0;
      Offset? local;
      await tester.pumpWidget(
        host(
          g,
          TableStage(
            geometry: g,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fromRect(
                  rect: card,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => local = d.localPosition,
                    onTap: () => taps++,
                    child: const ColoredBox(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(TableStage));

      // Where the card is on the screen.
      await tester.tapAt(origin + g.project(card.topLeft + const Offset(10, 10)));
      expect(taps, 1);
      expect(local!.dx, closeTo(10, 0.01));
      expect(local!.dy, closeTo(10, 0.01));
      await tester.tapAt(origin + g.project(card.center));
      expect(taps, 2);

      // Where the flat table would have it: nothing there.
      await tester.tapAt(origin + card.topLeft + const Offset(10, 10));
      expect(taps, 2);
    });

    testWidgets('a flat stage does not move anything', (tester) async {
      final g = StageGeometry.fit(const Size(600, 400), tilted: false);
      var taps = 0;
      await tester.pumpWidget(
        host(
          g,
          TableStage(
            geometry: g,
            child: Stack(
              children: <Widget>[
                Positioned.fromRect(
                  rect: const Rect.fromLTWH(60, 20, 100, 60),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const ColoredBox(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(TableStage));
      await tester.tapAt(origin + const Offset(110, 50));
      expect(taps, 1);
    });
  });

  group('FlyCard', () {
    Widget harness(Rect rect, {bool still = false}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: <Widget>[
              FlyCard(
                key: const ValueKey<int>(1),
                rect: rect,
                angle: 0,
                duration: const Duration(milliseconds: 400),
                still: still,
                hop: false,
                child: const ColoredBox(color: Colors.red),
              ),
            ],
          ),
        );

    testWidgets('glides to a new place instead of jumping', (tester) async {
      await tester.pumpWidget(harness(const Rect.fromLTWH(10, 10, 50, 70)));
      expect(tester.getTopLeft(find.byType(FlyCard)), const Offset(10, 10));

      await tester.pumpWidget(harness(const Rect.fromLTWH(310, 210, 50, 70)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.getTopLeft(find.byType(FlyCard));
      expect(mid.dx, greaterThan(10));
      expect(mid.dx, lessThan(310));
      expect(mid.dy, greaterThan(10));
      expect(mid.dy, lessThan(210));

      await tester.pumpAndSettle();
      final end = tester.getTopLeft(find.byType(FlyCard));
      expect(end.dx, closeTo(310, 0.001));
      expect(end.dy, closeTo(210, 0.001));
    });

    testWidgets('a card held by a finger follows it at once', (tester) async {
      await tester.pumpWidget(harness(const Rect.fromLTWH(100, 100, 50, 70), still: true));
      expect(tester.getTopLeft(find.byType(FlyCard)), const Offset(100, 100));
      await tester.pumpWidget(harness(const Rect.fromLTWH(120, 90, 50, 70), still: true));
      expect(tester.getTopLeft(find.byType(FlyCard)), const Offset(120, 90));
      // Let go: it glides back (does not jump).
      await tester.pumpWidget(harness(const Rect.fromLTWH(10, 10, 50, 70)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.byType(FlyCard));
      expect(mid.dx, lessThan(120));
      expect(mid.dx, greaterThan(10));
    });
  });

  group('TableLayout', () {
    test('cards deep in a stack are drawn plain, the top of it and the hands in full', () {
      final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 7);
      final layout = TableLayout.compute(
        size: const Size(844, 390),
        state: state,
        selected: null,
        pending: null,
        highlighted: const <int>{},
      );
      final deck = state.deck;
      expect(deck.length, greaterThan(6));
      // The card at the bottom of the deck may lie face up under it (shown
      // to everybody): it is never plain.
      final faceUp = deck.where((c) => layout.cards[c]!.faceUp).toList();
      for (final c in faceUp) {
        expect(layout.cards[c]!.simple, isFalse);
      }
      // Of the face-down cards, all but the top six are plain.
      final plain = deck.where((c) => layout.cards[c]!.simple).length;
      expect(plain, deck.length - faceUp.length - 6);
      // The top card of the deck (the last one) and every card in a hand.
      expect(layout.cards[deck.last]!.simple, isFalse);
      for (final hand in state.hands) {
        for (final c in hand) {
          expect(layout.cards[c]!.simple, isFalse);
        }
      }
    });

    test('my hand is a fan: the middle cards are lower and straight, the outer ones turn', () {
      final state = PastraEngine.newGame(rules: PastraRules.pileDefaults, numPlayers: 2, seed: 7);
      final layout = TableLayout.compute(
        size: const Size(844, 390),
        state: state,
        selected: null,
        pending: null,
        highlighted: const <int>{},
      );
      final hand = state.hands[0];
      final rects = <Rect>[for (final c in hand) layout.cards[c]!.rect];
      final angles = <double>[for (final c in hand) layout.cards[c]!.angle];
      // Left to right.
      for (var i = 1; i < hand.length; i++) {
        expect(rects[i].left, greaterThan(rects[i - 1].left));
        expect(angles[i], greaterThan(angles[i - 1]));
      }
      // The ends are lower than the middle: a fan.
      final mid = hand.length ~/ 2;
      expect(rects.first.top, greaterThan(rects[mid].top));
      expect(rects.last.top, greaterThan(rects[mid].top));
      expect(angles.first.abs(), greaterThan(angles[mid].abs()));
      expect(math.max(angles.first.abs(), angles.last.abs()), lessThan(0.3));
    });
  });

  group('the game on the tilted table', () {
    setUp(() {
      Fx.setMode(FxMode.high);
    });
    tearDown(() {
      Fx.setMode(FxMode.auto);
    });

    Future<GameController> openGame(WidgetTester tester) async {
      // A phone held sideways.
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(
        <String, Object>{'language': 'en', 'sound': false, 'tutorialDone': true},
      );
      final settings = await AppSettings.load();
      final controller = GameController.newGame(settings, players: 2, level: AiLevel.easy);
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: MaterialApp(theme: buildPastraTheme(), home: GameScreen(controller: controller)),
        ),
      );
      // The four opening cards are put on the pile one by one.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return controller;
    }

    testWidgets('the whole game is there and a card can be picked up', (tester) async {
      final controller = await openGame(tester);
      expect(Fx.low.value, isFalse);
      expect(find.byType(TableStage), findsOneWidget);
      // 4 on the pile + 6 in my hand + 6 opponent cards + 36 in the deck.
      expect(find.byType(PlayingCardView), findsNWidgets(52));
      expect(find.text('Your turn'), findsOneWidget);

      // The last card of my hand is on top of the others: tap it where it is seen.
      final card = controller.state.hands[0].last;
      final finder = find.byWidgetPredicate((w) => w is PlayingCardView && w.card == card);
      expect(finder, findsOneWidget);
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.selected, card);
      expect(find.text('Your turn'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching to low quality while playing keeps the game', (tester) async {
      await openGame(tester);
      expect(find.byType(PlayingCardView), findsNWidgets(52));

      Fx.setMode(FxMode.low);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(Fx.low.value, isTrue);
      expect(find.byType(PlayingCardView), findsNWidgets(52));
      expect(find.text('Your turn'), findsOneWidget);

      Fx.setMode(FxMode.high);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PlayingCardView), findsNWidgets(52));
      expect(find.text('Your turn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
