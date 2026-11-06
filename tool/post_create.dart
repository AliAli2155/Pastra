// Run once after `flutter create` (setup.bat / setup.sh do it for you):
//
//     dart run tool/post_create.dart
//
// * app name: "Pastra", and "Πάστρα" on Greek phones
// * launcher icons (Android legacy + adaptive, iOS, Windows)
// * landscape only (the game is played sideways)
// * Windows: the window title, a smallest window size the table fits in and
//   a dark title bar
//
// Safe to run again; it only touches the files listed here.
import 'dart:io';

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the project folder (where pubspec.yaml is).');
    exit(1);
  }
  _android();
  _ios();
  _windows();
  stdout.writeln('Done.');
}

void _android() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stdout.writeln('android/ not found – run `flutter create` first. Skipping Android.');
    return;
  }
  var xml = manifest.readAsStringSync();
  final label = RegExp(r'android:label="[^"]*"');
  if (label.hasMatch(xml)) {
    xml = xml.replaceFirst(label, 'android:label="@string/app_name"');
    stdout.writeln('AndroidManifest.xml: label -> @string/app_name');
  }
  if (!xml.contains('android:screenOrientation')) {
    xml = xml.replaceFirst('<activity', '<activity\n            android:screenOrientation="sensorLandscape"');
    stdout.writeln('AndroidManifest.xml: landscape only');
  }
  manifest.writeAsStringSync(xml);

  const res = 'android/app/src/main/res';
  _write('$res/values/strings.xml', _strings('Pastra'));
  _write('$res/values-el/strings.xml', _strings('Πάστρα'));
  _write(
    '$res/values/ic_launcher_background.xml',
    '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#0A5A39</color>\n'
        '</resources>\n',
  );
  _write(
    '$res/mipmap-anydpi-v26/ic_launcher.xml',
    '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
  );

  const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
  for (final d in densities) {
    for (final name in ['ic_launcher.png', 'ic_launcher_foreground.png']) {
      final src = File('tool/launcher_icons/android/mipmap-$d/$name');
      if (!src.existsSync()) continue;
      final dst = File('$res/mipmap-$d/$name');
      dst.parent.createSync(recursive: true);
      src.copySync(dst.path);
    }
  }
  stdout.writeln('Android: app name + launcher icons installed.');
}

void _ios() {
  final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  if (!dir.existsSync()) return;
  var copied = 0;
  for (final entity in Directory('tool/launcher_icons/ios').listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final dst = File('${dir.path}/$name');
    if (dst.existsSync()) {
      entity.copySync(dst.path);
      copied++;
    }
  }
  final plist = File('ios/Runner/Info.plist');
  if (plist.existsSync()) {
    var text = plist.readAsStringSync();
    final display = RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)');
    if (display.hasMatch(text)) {
      text = text.replaceFirstMapped(display, (m) => '${m[1]}Pastra${m[2]}');
    }
    // iPhone: landscape only.
    final orientations = RegExp(r'(<key>UISupportedInterfaceOrientations</key>\s*<array>)[\s\S]*?(</array>)');
    text = text.replaceFirstMapped(
      orientations,
      (m) => '${m[1]}\n\t\t<string>UIInterfaceOrientationLandscapeLeft</string>'
          '\n\t\t<string>UIInterfaceOrientationLandscapeRight</string>\n\t${m[2]}',
    );
    plist.writeAsStringSync(text);
  }
  stdout.writeln('iOS: $copied icons replaced.');
}

void _windows() {
  final runner = Directory('windows/runner');
  if (!runner.existsSync()) return;

  final icon = File('tool/launcher_icons/windows/app_icon.ico');
  if (icon.existsSync()) {
    Directory('windows/runner/resources').createSync(recursive: true);
    icon.copySync('windows/runner/resources/app_icon.ico');
  }

  _patch('windows/runner/main.cpp', 'window title', (text) => text.replaceFirst('L"pastra"', 'L"Pastra"'));
  _patch(
    'windows/runner/Runner.rc',
    'app name',
    (text) => text
        .replaceFirst('VALUE "FileDescription", "pastra"', 'VALUE "FileDescription", "Pastra"')
        .replaceFirst('VALUE "ProductName", "pastra"', 'VALUE "ProductName", "Pastra"'),
  );
  _patch('windows/runner/win32_window.cpp', 'smallest size and dark title bar', (text) {
    // The table needs some room: the window cannot be made smaller than
    // 800 x 450 (at 100 % scaling).
    if (!text.contains('WM_GETMINMAXINFO')) {
      text = text.replaceFirst(
        '  switch (message) {\n    case WM_DESTROY:',
        '  switch (message) {\n'
            '    case WM_GETMINMAXINFO: {\n'
            '      // Pastra: the table needs at least this much room.\n'
            '      const double scale = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;\n'
            '      auto info = reinterpret_cast<MINMAXINFO*>(lparam);\n'
            '      info->ptMinTrackSize.x = static_cast<LONG>(800 * scale);\n'
            '      info->ptMinTrackSize.y = static_cast<LONG>(450 * scale);\n'
            '      return 0;\n'
            '    }\n'
            '    case WM_DESTROY:',
      );
    }
    // The game is dark: a dark title bar also when Windows is set to light.
    return text.replaceFirst('BOOL enable_dark_mode = light_mode == 0;', 'BOOL enable_dark_mode = TRUE;  // Pastra: always dark');
  });
  stdout.writeln('Windows: icon, title, smallest window size, dark title bar.');
}

/// Changes a generated file with [change]; tells when it found nothing to
/// change (a newer Flutter may have moved things around).
void _patch(String path, String what, String Function(String text) change) {
  final file = File(path);
  if (!file.existsSync()) return;
  final before = file.readAsStringSync();
  final after = change(before);
  if (after == before) {
    stdout.writeln('$path: $what already set or not found.');
    return;
  }
  file.writeAsStringSync(after);
}

String _strings(String name) => '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <string name="app_name">$name</string>\n'
    '</resources>\n';

void _write(String path, String content) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}
