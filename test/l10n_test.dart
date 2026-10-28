import 'package:flutter_test/flutter_test.dart';
import 'package:pastra/engine/rules.dart';
import 'package:pastra/game/app_settings.dart';
import 'package:pastra/l10n/strings.dart';
import 'package:pastra/l10n/translations.dart';

void main() {
  test('every language has every text, with the same placeholders', () {
    final english = kTranslations['en']!;
    final placeholder = RegExp(r'\{(\w+)\}');
    Set<String> names(String s) => placeholder.allMatches(s).map((m) => m.group(1)!).toSet();
    for (final code in AppSettings.languages) {
      final table = kTranslations[code];
      expect(table, isNotNull, reason: code);
      expect(table!.keys.toSet(), english.keys.toSet(), reason: code);
      for (final key in english.keys) {
        expect(names(table[key]!), names(english[key]!), reason: '$code.$key');
      }
      expect(kLanguageNames[code], isNotNull);
      expect(kBotNames[code], hasLength(40), reason: code);
      expect(kBotNames[code]!.toSet(), hasLength(40), reason: '$code: duplicate bot names');
      for (final v in GameVariant.values) {
        expect(Strings(code).rulesSections(v), hasLength(8), reason: '$code ${v.name}');
      }
    }
  });

  test('placeholders are filled in', () {
    expect(Strings('en').stats(3, 5), 'Won 3 of 5');
    expect(Strings('tr').takes(4), '4 kart alırsın');
    expect(Strings('de').round(2), 'Runde 2');
  });
}
