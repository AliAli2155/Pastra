# Pastra (Πάστρα)

**Pastra** is the Greek fishing card game, built with Flutter. It runs as an Android app, a web
app (playable on iPhone through Safari → Add to Home Screen) and a Windows desktop app.
Languages: English (default), Greek, Turkish, German, French, Spanish, Italian, Portuguese,
Russian, Bulgarian, Arabic and Chinese.

Play it in the browser: <https://aliali2155.github.io/Pastra/>

## Features

- **Play against the computer:** 1v1, or 2v2 with a partner who sits opposite you.
- **Online multiplayer:** create a room, share the 4-digit code and play 1v1 or 2v2 with
  friends; empty seats are filled by bots. Disconnected players can rejoin, and a bot plays for
  them in the meantime.
- **Three difficulty levels:** Easy / Medium / Hard. The hard bot uses Monte Carlo sampling and an
  exact search near the end of a round, and never cheats: it only uses what a player can see.
- **Landscape play**, like Okey or Uno apps. On the web, a phone held upright gets a rotate hint.
- **Turn timer** (15 s by default; 10 / 15 / 20 / 30 s or off). When it runs out, a card is played
  for you.
- **Drag a card onto the table** to play it (the cards it would capture light up), or tap twice.
- Pastra effects, a round summary and play to a target score. The game is saved after every move,
  so you can continue later.
- **Two game variants:** *Stoiva* (default, the Greek Xeri style: one pile, only the top card is
  visible) and *Athroismata* (the Cypriot capture-by-sum style).
- **Settings:** target score (51 / 101 / 151 / 251), 4 or 6 cards per deal, jack-on-jack points,
  whether a jack taking a single card counts as a pastra, pastra on the last card.
- **Statistics and achievements**, table and card-back colors, real card sounds.
- **Offline tournament**: 8 players, knockout over three rounds (quarterfinal, semifinal, final) against computers that get stronger every round (easy → medium → hard), with an XP bonus for how far you get.
- **Levels and XP** (30 levels): every game, win and pastra earns XP, and beating a harder computer pays more. New table and card-back colors unlock at certain levels.
- Sound effects: Kenney.nl "Casino Audio", "Interface Sounds" and "Music Jingles" (CC0).
  `python tool/make_sounds.py` builds `assets/sounds/` from the packs in `tool/sounds_raw/`.

## Rules (default: Stoiva / Xeri)

The bottom card of the deck (the *kapak alti*) is turned face up and stays under the deck; it is
the last card dealt, so the dealer gets it and everyone knows it. A jack never lies there alone:
another card is turned face up next to it (and another one if that is a jack too). Every player is
dealt 6 cards.
Four cards are opened side by side in the middle and the rightmost one is the top card. A jack may
not be the top card: it is turned face up next to the bottom card, so there are now two face-up
cards under the deck, and another card is opened for the table. If that card is a jack again, it
joins them under the deck too, and so on. When the first card is
played, the four cards are gathered into one pile, and from then on only the top card is visible
(you have to remember what is underneath).

A card of the same rank as the top card, or a jack, takes the **whole pile**; any other card is
laid on top. Taking a single card with a card of the same rank is a **pastra: 10 points**; a jack
on a lone jack is worth 20. The final card of a round does not make a pastra.

Round scoring: the 10♦ 3 points; each ace 1; each jack 1; the 2♣ 2; and the side with more cards at
the end of the round gets 3 (nobody on a 26–26 tie). That is 16 points per round plus pastras. The
first side to reach the target score (151 by default) wins.

If a player is dealt **four cards of the same rank**, the deal is void: the hand is shown to
everyone, and the same dealer shuffles and deals again.

Settings → Variant switches to the Cypriot capture-by-sum game (open table, sums such as 8 → 5+3,
101 points).

## Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install). Then:

```
flutter pub get
flutter test
flutter run            # pick a device, or: flutter run -d chrome
```

The repository does not contain the `android/`, `ios/` or `windows/` boilerplate that
`flutter create` generates. The setup scripts create it and apply the app name and icons:

- **macOS / Linux:** `./setup.sh`
- **Windows:** `setup.bat`

Both run `flutter create`, `flutter pub get`, `dart run tool/post_create.dart` and `flutter test`.

### Android APK

```
flutter build apk --release
```

The file is `build/app/outputs/flutter-apk/app-release.apk`. Without Android Studio, copy
`tool/ci/android-apk.yml` to `.github/workflows/`; GitHub then builds the APK on every push to
`main` and you can download it from the run's **Artifacts**.

### Windows (.exe)

Install Visual Studio 2022 with the **Desktop development with C++** workload, then run
`windows_exe.bat`. It creates the `windows/` folder, builds a release and writes
`Pastra-Windows.zip`. Unzip it anywhere and run `pastra.exe`. If Windows warns about an unsigned
app, choose **More info → Run anyway**.

### Web / iPhone

- Try it on your computer: `flutter run -d chrome`.
- Try it on an iPhone on the same Wi-Fi: run `web_telefon.bat` and open the printed address in
  Safari.
- Publish for free with **GitHub Pages**: the workflow in `.github/workflows/web-pages.yml`
  runs the tests, builds the web app and deploys it on every push to `main`. In the repository,
  choose **Settings → Pages → Source: GitHub Actions** once.

On an iPhone, **Share → Add to Home Screen** opens the game full screen like an app; the saved
game and settings stay on the phone.

## Online multiplayer

Online play uses **Firebase** (Anonymous Auth and Realtime Database; the free Spark plan is
enough). One player, the room host, runs the game engine; the others receive their own view of
the game (other hands are hidden) and send their moves to the host.

Rooms can be private (join with a 4-digit code) or listed in the lobby as **open tables** that
anybody can join. **Quick match** joins an open 1v1 table, or opens one and starts as soon as an
opponent sits down (or plays against the computer if you prefer).

**Online tournaments** come in four kinds: a *quick cup* every 15 minutes (1v1 to 51), a *classic
cup* every 30 minutes (1v1 to 101), a *team cup* at :15 and :45 (2v2 to 51), and a *friends cup*
that someone creates and shares with a 5-digit code (it starts when the creator presses Start).
Players register; at the start they play knockouts of 8: players 1–8 in the first bracket, 9–16 in
a second one at the same time, and so on (up to 12 brackets, as the free Firebase plan allows
about 100 connections at once). Empty places get bots. There is no game server: every device
computes the same bracket from the registrations and the results written by the players. Nobody
there when a match is ready loses after 90 seconds; a match that takes too long is decided.

The **leaderboard** lists the players with the most XP (name, level, wins). Players can turn
it off in the settings; it trusts the app, so it is for fun, not a secure ranking.

Limits of this design: the host could technically cheat, and if the host leaves, the game ends.

Setup: create a Firebase project, enable **Anonymous** sign-in, create a Realtime Database,
deploy `database.rules.json` (`firebase deploy --only database`), run
`flutterfire configure` to generate `lib/firebase_options.dart`, and add your web domain (for
example `<user>.github.io`) to **Authentication → Settings → Authorized domains**. Pick a database
region that answers from your network: a database in `europe-west1` never responded during
development, while `us-central1` worked. A step-by-step guide (in Turkish) is in
[docs/ONLINE_KURULUM.md](docs/ONLINE_KURULUM.md).

## Project structure

```
lib/
  engine/            pure Dart game logic (no Flutter, so it can run anywhere)
    cards.dart         card ids (0..51) and point values
    rules.dart         configurable rules
    game_state.dart    serializable game state and round results
    pastra_engine.dart dealing, capturing, pastra, scoring
    pastra_ai.dart     the bots (easy / medium / hard)
    perspective.dart   rotates a state so that any seat sees itself as seat 0
  game/
    game_controller.dart  game flow: turns, bot moves, dealing, saving, online host/guest
    app_settings.dart     settings, statistics and the saved game (shared_preferences)
    seats.dart            seats (human / bot / remote player)
    progression.dart     XP, levels and the colors that unlock at each level
    tournament.dart      the offline knockout tournament (bracket, rounds, results)
  online/            Firebase: sign-in, rooms, host and guest sessions
  l10n/              UI texts (generated from tool/l10n/)
  ui/
    table_layout.dart  where every card is drawn (every change of place is animated)
    screens/           home, game table, settings, rules, statistics, online
    widgets/           card drawing, round summary
web/                 web app (iPhone Safari / home-screen app)
test/                engine tests, bot games, localisation and widget tests
tool/                setup helpers, translation generator, sound builder
docs/                design notes and research
```

### Translations

All texts live in the tables in `tool/l10n/`. After changing them, run
`python tool/l10n/gen.py` to regenerate `lib/l10n/translations.dart`.

## Contributing and commits

Commit messages are written in English, in the imperative mood ("Add online lobby", not
"added online lobby").

## Credits

Made by A. Ali. Sound effects by [Kenney](https://kenney.nl) (CC0).
