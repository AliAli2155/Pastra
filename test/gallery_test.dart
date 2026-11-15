import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens.dart';

/// Screenshots of every screen for the gallery of the preview site
/// (https://…/Pastra/preview/shots/). Only runs when SHOTS_DIR is set:
///
///     SHOTS_DIR=build/shots flutter test test/gallery_test.dart
void main() {
  quietApp();
  final dir = Platform.environment['SHOTS_DIR'];
  const sizes = <Size>[Size(844, 390), Size(1280, 720)];
  const languages = <String>['tr', 'en'];
  final shots = <String>[];

  for (final language in languages) {
    for (final size in sizes) {
      for (final screen in sweepScreens) {
        final name = '${language}_${size.width.toInt()}x${size.height.toInt()}_${screen.name}.png';
        testWidgets('shot $name', (tester) async {
          await loadRealFonts();
          await pumpSweepScreen(tester, screen, size, language);
          final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          await tester.runAsync(() async {
            final image = await layer.toImage(Offset.zero & size, pixelRatio: 1.5);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$dir/$name')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data!.buffer.asUint8List());
          });
          shots.add(name);
          await leaveSweepScreen(tester);
        }, skip: dir == null);
      }
    }
  }

  tearDownAll(() {
    if (dir == null || shots.isEmpty) return;
    final commit = Platform.environment['GITHUB_SHA'] ?? '';
    final rows = StringBuffer();
    for (final s in shots) {
      rows.writeln(
          '<figure><a href="$s"><img src="$s" loading="lazy" alt="$s"></a><figcaption>$s</figcaption></figure>');
    }
    File('$dir/index.html').writeAsStringSync('''<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pastra screens</title>
<style>
body{margin:0;padding:16px;background:#111316;color:#F3EEE2;font:14px/1.4 -apple-system,Segoe UI,Roboto,sans-serif}
h1{font-size:20px;margin:0 0 4px}p{color:#A7B0BA;margin:0 0 16px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}
figure{margin:0;background:#181B20;border:1px solid #2A2E36;border-radius:12px;overflow:hidden}
img{display:block;width:100%;height:auto}figcaption{padding:6px 10px;color:#A7B0BA;font-size:12px}
</style></head><body>
<h1>Pastra – every screen</h1><p>ui-v2 ${commit.length > 7 ? commit.substring(0, 7) : commit} · ${shots.length} screenshots</p>
<div class="grid">
$rows</div></body></html>
''');
  });
}
