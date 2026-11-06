import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/ui/theme.dart';
import 'package:pastra/ui/widgets/playing_card.dart';

void main() {
  test('card pictures are made once and reused', () {
    final a = CardArt.face(5);
    expect(identical(CardArt.face(5), a), isTrue);
    expect(identical(CardArt.face(5, highlighted: true), a), isFalse);
    expect(a.width, (PlayingCardView.baseWidth * CardArt.ratio).ceil());
    expect(identical(CardArt.back(CardBackStyle.aegean), CardArt.back(CardBackStyle.aegean)), isTrue);
  });

  testWidgets('a dealt card waits before it turns over', (tester) async {
    Widget card(bool up) => Center(
          child: SizedBox(
            width: 60,
            height: 85,
            child: PlayingCardView(
              card: 7,
              faceUp: up,
              backStyle: CardBackStyle.aegean,
              flipDelay: const Duration(milliseconds: 300),
            ),
          ),
        );
    ui(WidgetTester t) => t.widget<RawImage>(find.byType(RawImage)).image;

    await tester.pumpWidget(card(false));
    expect(ui(tester), same(CardArt.back(CardBackStyle.aegean)));

    await tester.pumpWidget(card(true));
    await tester.pump(const Duration(milliseconds: 200));
    // Still waiting: the back, lying flat.
    expect(ui(tester), same(CardArt.back(CardBackStyle.aegean)));
    expect(find.descendant(of: find.byType(PlayingCardView), matching: find.byType(Transform)), findsNothing);

    await tester.pump(const Duration(milliseconds: 270));
    // Turning: the new side opens out of its edge.
    expect(find.descendant(of: find.byType(PlayingCardView), matching: find.byType(Transform)), findsOneWidget);
    expect(ui(tester), same(CardArt.face(7)));

    await tester.pumpAndSettle();
    expect(ui(tester), same(CardArt.face(7)));
    expect(find.descendant(of: find.byType(PlayingCardView), matching: find.byType(Transform)), findsNothing);
  });
}
