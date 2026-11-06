import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/ui/ege/fly_card.dart';

void main() {
  Widget harness(Rect rect, {Duration delay = Duration.zero, Object? key}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: <Widget>[
            FlyCard(
              key: const ValueKey<int>(1),
              rect: rect,
              angle: 0,
              duration: const Duration(milliseconds: 300),
              delay: delay,
              delayKey: key,
              hop: false,
              child: const ColoredBox(color: Colors.red),
            ),
          ],
        ),
      );

  const deck = Rect.fromLTWH(10, 10, 50, 70);
  const hand = Rect.fromLTWH(400, 300, 50, 70);
  const delay = Duration(milliseconds: 400);

  testWidgets('a dealt card waits its turn once, then never stops in the air', (tester) async {
    await tester.pumpWidget(harness(deck, key: 0));
    await tester.pumpWidget(harness(hand, delay: delay, key: 1));
    await tester.pump(const Duration(milliseconds: 300));
    // Still waiting on the deck.
    expect(tester.getTopLeft(find.byType(FlyCard)), deck.topLeft);

    await tester.pump(const Duration(milliseconds: 200));
    final flying = tester.getTopLeft(find.byType(FlyCard));
    expect(flying.dx, greaterThan(deck.left));

    // The mouse makes it rise while it flies (same deal): it goes on at once.
    await tester.pumpWidget(harness(hand.shift(const Offset(0, -6)), delay: delay, key: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.getTopLeft(find.byType(FlyCard)).dx, greaterThan(flying.dx));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FlyCard)), hand.shift(const Offset(0, -6)).topLeft);
  });

  testWidgets('a card rising under the mouse is quick', (tester) async {
    await tester.pumpWidget(harness(hand, key: 1));
    await tester.pumpWidget(harness(hand.shift(const Offset(0, -6)), delay: delay, key: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getTopLeft(find.byType(FlyCard)).dy, closeTo(hand.top - 6, 0.01));
  });
}
