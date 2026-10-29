import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/game_state.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../game/tournament.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/cup_logic.dart';
import '../../online/cup_service.dart';
import '../../online/leaderboard.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../theme.dart';
import '../widgets/bracket_view.dart';
import '../widgets/menu_tiles.dart';
import 'game_screen.dart';
import 'online_screen.dart';

/// The scheduled online tournament: registration for the next one, and the
/// live bracket of the one you play in. Your matches start by themselves
/// while this screen is open.
class CupScreen extends StatefulWidget {
  const CupScreen({super.key, required this.name});

  /// Name shown to the other players.
  final String name;

  @override
  State<CupScreen> createState() => _CupScreenState();
}

class _CupScreenState extends State<CupScreen> {
  late int _current = CupRules.currentSlot(OnlineService.serverNow);
  CupData? _currentData;
  CupData? _nextData;
  StreamSubscription<CupData>? _currentSub;
  StreamSubscription<CupData>? _nextSub;
  StreamSubscription<void>? _presence;
  int? _presenceSlot;
  Timer? _tick;
  bool _busy = false;

  /// Shows the next cup even though the current one (ours) is over.
  bool _showNext = false;

  // ---- the match being played
  bool _playing = false;
  final Set<String> _launched = <String>{};
  final Set<String> _claimed = <String>{};
  HostRoom? _host;
  GuestRoom? _guest;
  String? _activeMatch;
  int _activeMe = -1;
  int _activeOpp = -1;

  int get _next => _current + CupRules.slotMs;

  String get _uid => OnlineService.uid;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _subscribe() {
    _currentSub?.cancel();
    _nextSub?.cancel();
    _currentData = null;
    _nextData = null;
    _currentSub = CupService.watch(_current).listen((d) {
      if (mounted) setState(() => _currentData = d);
    });
    _nextSub = CupService.watch(_next).listen((d) {
      if (mounted) setState(() => _nextData = d);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _currentSub?.cancel();
    _nextSub?.cancel();
    _presence?.cancel();
    super.dispose();
  }

  bool get _inCurrent => _currentData?.isRegistered(_uid) ?? false;

  bool get _inNext => _nextData?.signups.any((x) => x.uid == _uid) ?? false;

  CupBracket? _bracket(CupData? data) {
    if (data == null) return null;
    final entrants = CupBracket.entrantsFor(data.slot, data.signups, botNames: Strings.botNameCount);
    return CupBracket.compute(slot: data.slot, entrants: entrants, results: data.results);
  }

  void _onTick() {
    if (!mounted) return;
    final now = OnlineService.serverNow;
    // A new cup began: the "next" one is now the current one.
    if (CupRules.currentSlot(now) != _current) {
      _current = CupRules.currentSlot(now);
      _showNext = false;
      _subscribe();
    }
    _keepPresence();
    final data = _currentData;
    final bracket = _bracket(data);
    if (data != null && bracket != null && _inCurrent) {
      for (final claim in bracket.claims(now, data.present)) {
        if (_claimed.add(claim.matchId)) CupService.report(data.slot, claim.matchId, claim.winner);
      }
      _checkActiveGame(data);
      _payBonus(bracket);
      _maybeLaunch(bracket);
    }
    setState(() {});
  }

  /// Present for the cup we are in (the running one, or the next one).
  void _keepPresence() {
    final slot = _inCurrent ? _current : (_inNext ? _next : null);
    if (slot == _presenceSlot) return;
    _presence?.cancel();
    _presence = slot == null ? null : CupService.keepPresent(slot);
    _presenceSlot = slot;
  }

  void _payBonus(CupBracket bracket) {
    final settings = SettingsScope.read(context);
    final me = bracket.positionOf(_uid);
    if (me < 0 || settings.cupBonusPaid == bracket.slot) return;
    final out = bracket.lostIn(me) >= 0;
    if (!out && !bracket.finished) return;
    final wins = bracket.winsOf(me);
    settings.cupBonusPaid = bracket.slot;
    settings.addXp(_bonusFor(wins));
    Leaderboard.submit(settings, fallbackName: Strings.of(context).you);
  }

  /// XP bonus by matches won: 30, 80, 200 for the title (like the offline
  /// tournament).
  static int _bonusFor(int wins) => const <int>[0, 30, 80, 200][wins < 0 ? 0 : (wins > 3 ? 3 : wins)];

  // ---- playing a match

  void _maybeLaunch(CupBracket bracket) {
    if (_playing || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final me = bracket.positionOf(_uid);
    if (me < 0) return;
    final m = bracket.openMatchOf(me);
    if (m == null || m.status != CupMatchStatus.ready || _launched.contains(m.id)) return;
    _launched.add(m.id);
    _play(bracket, m, me);
  }

  Future<void> _play(CupBracket bracket, CupMatch m, int me) async {
    final settings = SettingsScope.read(context);
    final s = Strings.of(context);
    final opp = m.a == me ? m.b! : m.a!;
    final rules = settings.rules.copyWith(targetScore: CupRules.targetScore);
    setState(() => _playing = true);
    try {
      final other = bracket.entrants[opp];
      if (other.isBot) {
        final c = GameController.tournamentMatch(
          settings,
          level: Tournament.levelFor(m.round),
          botIndex: other.botIndex,
          rules: rules,
        );
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)));
        if (c.state.phase == GamePhase.gameOver) {
          await CupService.report(bracket.slot, m.id, c.state.winner == 0 ? me : opp);
        } else {
          _launched.remove(m.id);
        }
        return;
      }
      final code = 'c${bracket.slot ~/ 60000}${m.id}';
      final oppName = other.name.isEmpty ? s.you : other.name;
      _activeMe = me;
      _activeOpp = opp;
      if (me < opp) {
        final room = await HostRoom.createWithCode(settings, code: code, name: widget.name, rules: rules);
        if (!mounted) {
          room.close();
          return;
        }
        _host = room;
        _activeMatch = m.id;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room, cupOpponent: oppName)),
        );
      } else {
        GuestRoom? room;
        final until = DateTime.now().add(CupRules.noShow);
        while (room == null && mounted && DateTime.now().isBefore(until)) {
          try {
            room = await GuestRoom.join(code, settings, widget.name);
          } on OnlineException {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
        }
        if (!mounted) {
          room?.close();
          return;
        }
        if (room == null) {
          _launched.remove(m.id);
          return;
        }
        _guest = room;
        _activeMatch = m.id;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LobbyScreen(guest: room, cupOpponent: oppName)),
        );
      }
    } catch (_) {
      _launched.remove(m.id);
      _clearActive(retry: false);
    } finally {
      // An online match goes on after the waiting room is replaced by the
      // game; [_checkActiveGame] reports it.
      if (_activeMatch == null && mounted) setState(() => _playing = false);
    }
  }

  void _checkActiveGame(CupData data) {
    final id = _activeMatch;
    if (id == null) return;
    final c = _host?.controller ?? _guest?.controller.value;
    if (c != null && c.state.phase == GamePhase.gameOver) {
      // Host and guest both see their own side as team 0.
      CupService.report(data.slot, id, c.state.winner == 0 ? _activeMe : _activeOpp);
      _clearActive(retry: false);
      return;
    }
    // Decided without being played (the other player did not come, or it
    // took too long): back to the bracket.
    if (data.results.containsKey(id)) {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) Navigator.of(context).popUntil((r) => r == route);
      _clearActive(retry: false);
      return;
    }
    // Back on this screen without a finished game: the match was left.
    if (ModalRoute.of(context)?.isCurrent ?? false) _clearActive(retry: true);
  }

  void _clearActive({required bool retry}) {
    if (retry && _activeMatch != null) _launched.remove(_activeMatch);
    _activeMatch = null;
    _host = null;
    _guest = null;
    if (mounted) setState(() => _playing = false);
  }

  // ---- registration

  Future<void> _toggleRegistration() async {
    setState(() => _busy = true);
    try {
      if (_inNext) {
        await CupService.unregister(_next);
      } else {
        await CupService.register(_next, widget.name);
      }
    } catch (_) {
      if (mounted) {
        final t = OnlineStrings(SettingsScope.read(context).language);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.error('network'))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  // ---- UI

  String _clock(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _countdown(int ms) {
    // (No `1 << 40` here: on the web shifts are 32-bit and that is 256.)
    final diff = ms - OnlineService.serverNow;
    final left = Duration(milliseconds: diff < 0 ? 0 : diff);
    final m = left.inMinutes;
    final sec = left.inSeconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _name(Strings s, CupEntrant e) {
    if (e.isBot) return s.botName(e.botIndex);
    if (e.uid == _uid) return widget.name;
    return e.name.isEmpty ? OnlineStrings(SettingsScope.read(context).language).defaultName : e.name;
  }

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    final live = _inCurrent && !_showNext;
    return Scaffold(
      appBar: AppBar(title: Text(live ? t.cupLive : t.cup, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          top: false,
          child: _currentData == null || _nextData == null
              ? const Center(child: CircularProgressIndicator())
              : live
                  ? _liveView(t, s)
                  : _signupView(t, s),
        ),
      ),
    );
  }

  Widget _twoPanes(Widget left, Widget right) => LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 640) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Expanded(flex: 3, child: Center(child: left)),
                      const SizedBox(width: 16),
                      SizedBox(width: 320, child: Center(child: SingleChildScrollView(child: right))),
                    ],
                  ),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                Expanded(child: Center(child: left)),
                const SizedBox(height: 12),
                right,
              ],
            ),
          );
        },
      );

  Widget _signupView(OnlineStrings t, Strings s) {
    final data = _nextData!;
    final counted = data.signups.toList()..sort((a, b) => a.time.compareTo(b.time));
    final names = counted.take(CupRules.size).map((x) => x.uid == _uid ? widget.name : (x.name.isEmpty ? t.defaultName : x.name));
    final left = MenuPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.emoji_events_rounded, color: PastraColors.gold, size: 52),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.nextCup(_clock(_next)),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.startsIn(_countdown(_next)),
            style: const TextStyle(color: PastraColors.gold, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            t.cupPlayers(counted.length > CupRules.size ? CupRules.size : counted.length),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final n in names)
                Chip(
                  label: Text(n, style: const TextStyle(fontWeight: FontWeight.w700)),
                  avatar: const Icon(Icons.person, size: 18),
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                ),
            ],
          ),
        ],
      ),
    );
    final right = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_inNext) ...<Widget>[
          Text(
            t.cupRegistered,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          BigOutlineButton(icon: Icons.logout_rounded, label: t.cupUnregister, onPressed: _busy ? null : _toggleRegistration),
        ] else
          BigButton(icon: Icons.how_to_reg_rounded, label: t.cupRegister, onPressed: _busy ? null : _toggleRegistration),
        if (_showNext && _inCurrent) ...<Widget>[
          const SizedBox(height: 12),
          BigOutlineButton(
            icon: Icons.account_tree_outlined,
            label: t.cupLive,
            onPressed: () => setState(() => _showNext = false),
          ),
        ],
      ],
    );
    return _twoPanes(SingleChildScrollView(child: left), right);
  }

  Widget _liveView(OnlineStrings t, Strings s) {
    final bracket = _bracket(_currentData)!;
    final me = bracket.positionOf(_uid);
    final open = me >= 0 ? bracket.openMatchOf(me) : null;
    final cells = <List<BracketCell>>[
      for (final round in bracket.matches)
        <BracketCell>[
          for (final m in round)
            BracketCell(
              a: m.a == null ? null : _name(s, bracket.entrants[m.a!]),
              b: m.b == null ? null : _name(s, bracket.entrants[m.b!]),
              winner: m.winner == null ? null : (m.winner == m.a ? 0 : 1),
              meA: m.a == me,
              meB: m.b == me,
              current: open != null && open.id == m.id,
            ),
        ],
    ];
    final view = BracketView(
      titles: <String>[for (var r = 0; r < CupRules.rounds; r++) s.tournamentRound(r)],
      cells: cells,
    );
    final lost = me >= 0 ? bracket.lostIn(me) : -1;
    final children = <Widget>[];
    if (bracket.champion == me || lost >= 0) {
      final won = bracket.champion == me;
      final wins = bracket.winsOf(me);
      final bonus = _bonusFor(wins);
      children.addAll(<Widget>[
        Icon(won ? Icons.emoji_events : Icons.sentiment_neutral, color: PastraColors.gold, size: 40),
        Text(
          won ? s.championMsg : s.eliminatedMsg(s.tournamentRound(lost)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (bonus > 0)
          Text(s.tournamentBonus(bonus), style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        BigButton(icon: Icons.schedule_rounded, label: t.cupNext, onPressed: () => setState(() => _showNext = true)),
      ]);
    } else if (open != null && open.status == CupMatchStatus.ready) {
      final opp = open.a == me ? open.b! : open.a!;
      children.addAll(<Widget>[
        Text(
          s.tournamentRound(open.round),
          style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          s.vsName(_name(s, bracket.entrants[opp])),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (_playing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 10),
              Flexible(child: Text(t.cupStarting, style: const TextStyle(color: Colors.white70))),
            ],
          )
        else
          BigButton(
            icon: Icons.play_arrow_rounded,
            label: s.playMatch,
            onPressed: () {
              _launched.remove(open.id);
              _maybeLaunch(bracket);
            },
          ),
      ]);
    } else {
      children.addAll(<Widget>[
        const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(height: 10),
        Text(t.cupWaiting, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ]);
    }
    final panel = MenuPanel(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    return _twoPanes(view, panel);
  }
}
