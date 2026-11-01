import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/ui/widgets/ui_scale.dart';

void main() {
  test('phones are not scaled', () {
    expect(UiScale.zoomFor(const Size(844, 390)), 1);
    expect(UiScale.zoomFor(const Size(932, 430)), 1);
    expect(UiScale.zoomFor(const Size(390, 844)), 1);
  });

  test('big screens grow like a phone held sideways', () {
    final z = UiScale.zoomFor(const Size(1688, 780));
    expect(z, closeTo(2.0, 0.01));
    expect(UiScale.zoomFor(const Size(1440, 850)), closeTo(1.7, 0.02));
  });

  test('the zoom is capped and never below 1', () {
    expect(UiScale.zoomFor(const Size(5000, 3000)), UiScale.maxZoom);
    expect(UiScale.zoomFor(const Size(700, 600)), 1);
  });
}
