import 'dart:math';

import 'package:flutter/widgets.dart';

/// Big screens (a desktop browser window, a tablet) show the whole app
/// zoomed, as if it ran on a phone held sideways: the layouts are designed
/// for about 844 x 390, and a large window just gets them bigger instead of
/// tiny and lost in empty space. Phones are not scaled.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child});

  final Widget child;

  /// Design size (a phone held sideways).
  static const double baseWidth = 844;
  static const double baseHeight = 390;

  /// Zoom for a window of [size]: 1 on phones, up to [maxZoom] on big screens.
  static double zoomFor(Size size) {
    if (size.shortestSide < 560) return 1;
    return min(size.width / baseWidth, size.height / baseHeight).clamp(1.0, maxZoom).toDouble();
  }

  static const double maxZoom = 2.4;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final zoom = zoomFor(data.size);
    if (zoom < 1.04) return child;
    final virtual = Size(data.size.width / zoom, data.size.height / zoom);
    return SizedBox.fromSize(
      size: data.size,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: virtual,
          child: MediaQuery(
            data: data.copyWith(
              size: virtual,
              padding: data.padding / zoom,
              viewPadding: data.viewPadding / zoom,
              viewInsets: data.viewInsets / zoom,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
