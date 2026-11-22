import 'package:flutter/widgets.dart';

import '../../l10n/social_strings.dart';

/// Web: Flutter fetches a font for characters the app's own fonts lack
/// (Arabic, Chinese, the card suits ♣♦♠♥, emojis) only when such text is
/// first laid out, and taking a new font in makes the page stand still for
/// a moment (measured: ~120 ms for one emoji font piece on a fast laptop at
/// phone speed). Text drawn before the font arrives also stays garbled.
///
/// This lays samples out, hidden, ahead of time: the languages and the card
/// suits at the start, the quick chat emojis once the online part is opened
/// (so a chat emoji in a game does not stop the table).
class FontWarmup extends StatelessWidget {
  const FontWarmup({super.key});

  static final ValueNotifier<bool> _emojis = ValueNotifier<bool>(false);

  /// The online part opens: fetch the quick chat emojis now.
  static void wantEmojis() => _emojis.value = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _emojis,
      builder: (context, emojis, _) => Offstage(
        child: Text('العربية 中文 Ελληνικά Български ♣♦♠♥${emojis ? ' ${SocialStrings.emojis.join(' ')}' : ''}'),
      ),
    );
  }
}
