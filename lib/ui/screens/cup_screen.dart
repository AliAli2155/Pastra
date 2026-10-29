import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/game_state.dart';
import '../../engine/pastra_ai.dart';
import '../../game/app_settings.dart';
import '../../game/game_controller.dart';
import '../../game/seats.dart';
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

String cupTitle(OnlineStrings t, CupType type) => switch (type.id) {
      'q' => t.cupQuick,
      'c' => t.cupClassic,
      't' => t.cupTeam,
      _ => t.cupFriends,
    };

/// One kind of online cup: registration for the next one (or the waiting
/// room of a friends cup), then the live bracket of the one you play in.
/// Your matches start by themselves while this screen is open.
class CupScreen extends StatefulWidget {
  const CupScreen({super.key, required this.type, required this.name, this.friendsCode});

  final CupType type;

  /// Name shown to the other players.
  final String name;

  /// A friends cup: its code.
  final String? friendsCode;

  @override
  State<CupScreen> createState() => _CupScreenState();
}

class _CupScreenState extends State<CupScreen> {
  /// A friends cup takes its mode and target from its creator's choice.
  CupType get type => _friends ? (_currentData?.friendsType ?? widget.type) : widget.type;
  bool get _friends => widget.friendsCode != null;

  late int _current = type.isScheduled ? type.currentStart(OnlineService.serverNow) : 0;
  CupData? _currentData;
  CupData? _nextData;
  StreamSubscription<CupData>? _currentSub;
  StreamSubscription<CupData>? _nextSub;
  StreamSubscription<void>? _presence;
  String? _presenceKey;
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

  int get _next => type.nextStart(OnlineService.serverNow);

  String get _uid => OnlineService.uid;

  String get _currentKey => _friends ? '${CupType.friends.id}${widget.friendsCode}' : type.keyFor(_current);

  String get _nextKey => type.keyFor(_current + type.everyMinutes * 60000);

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
    _currentSub = CupService.watch(_currentKey, scheduledStart: _friends ? null : _current).listen((d) {
      if (mounted) setState(() => _currentData = d);
    });
    if (!_friends) {
      final next = _current + type.everyMinutes * 60000;
      _nextSub = CupService.watch(_nextKey, scheduledStart: next).listen((d) {
        if (mounted) setState(() => _nextData = d);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _currentSub?.cancel();
    _nextSub?.cancel();
    _presence?.cancel();
    super.dispose();
  }

  /// We play in the running cup.
  bool get _inCurrent {
    final d = _currentData;
    return d != null && d.started && d.plays(_uid, type);
  }

  bool get _inNext => _nextData?.hasSignup(_uid) ?? false;

  /// The bracket of our group (null when we do not play in [data]).
  CupBracket? _bracket(CupData? data) {
    if (data == null || data.start == null) return null;
    final start = data.start!;
    final group = CupBracket.groupOf(start, data.signups, _uid, maxGroups: type.maxGroups);
    if (group < 0) return null;
    final entrants = CupBracket.entrantsFor(
      start,
      data.signups,
      group: group,
      teamSize: type.teamSize,
      botNames: Strings.botNameCount,
    );
    return CupBracket.compute(start: start, group: group, entrants: entrants, results: data.results);
  }

  void _onTick() {
    if (!mounted) return;
    final now = OnlineService.serverNow;
    // A new cup began: the "next" one is now the current one.
    if (type.isScheduled && type.currentStart(now) != _current) {
      _current = type.currentStart(now);
      _showNext = false;
      _subscribe();
    }
    _keepPresence();
    final data = _currentData;
    final bracket = _bracket(data);
    if (data != null && bracket != null && _inCurrent) {
      for (final claim in bracket.claims(now, data.present, timeout: type.timeout)) {
        if (_claimed.add(claim.matchId)) CupService.report(data.key, claim.matchId, claim.winner);
      }
      _checkActiveGame(data);
      _payBonus(data.key, bracket);
      _maybeLaunch(data.key, bracket);
    }
    setState(() {});
  }

  /// Present for the cup we are in (the running one, or the next one).
  void _keepPresence() {
    String? key;
    if (_friends) {
      key = (_currentData?.hasSignup(_uid) ?? false) ? _currentKey : null;
    } else {
      key = _inCurrent ? _currentKey : (_inNext ? _nextKey : null);
    }
    if (key == _presenceKey) return;
    _presence?.cancel();
    _presence = key == null ? null : CupService.keepPresent(key);
    _presenceKey = key;
  }

  /// XP bonus: 30 for one won match, 80 for two, 200 for the title.
  static int _bonus(int wins, bool champion) => champion ? 200 : const <int>[0, 30, 80, 80][wins < 0 ? 0 : (wins > 3 ? 3 : wins)];

  void _payBonus(String key, CupBracket bracket) {
    final settings = SettingsScope.read(context);
    final me = bracket.positionOf(_uid);
    if (me < 0 || settings.cupBonusPaid(key)) return;
    final champion = bracket.champion == me;
    if (bracket.lostIn(me) < 0 && !champion) return;
    settings.markCupBonusPaid(key);
    settings.addXp(_bonus(bracket.winsOf(me), champion));
    Leaderboard.submit(settings, fallbackName: Strings.of(context).you);
  }

  // ---- playing a match

  void _maybeLaunch(String key, CupBracket bracket) {
    if (_playing || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final me = bracket.positionOf(_uid);
    if (me < 0) return;
    final m = bracket.openMatchOf(me);
    if (m == null || m.status != CupMatchStatus.ready || _launched.contains(m.id)) return;
    _launched.add(m.id);
    _play(key, bracket, m, me);
  }

  /// Level of the bots: easy in the first round of 8, hard in the final.
  AiLevel _botLevel(int round) => Tournament.levelFor(round + 3 - type.rounds);

  Future<void> _play(String key, CupBracket bracket, CupMatch m, int me) async {
    final settings = SettingsScope.read(context);
    final s = Strings.of(context);
    final opp = m.a == me ? m.b! : m.a!;
    final rules = settings.rules.copyWith(targetScore: type.targetScore);
    final mine = bracket.entrants[me];
    final theirs = bracket.entrants[opp];
    final level = _botLevel(m.round);
    final people = <CupMember>[...mine.members, ...theirs.members].where((x) => !x.isBot).length;
    setState(() => _playing = true);
    try {
      if (people == 1) {
        // Only bots besides us: the match is played on this device.
        final partner = mine.members.where((x) => x.uid != _uid).toList();
        final seats = <SeatInfo>[
          const SeatInfo.human(),
          SeatInfo.bot(level, theirs.members[0].botIndex),
          if (type.teamSize == 2) ...<SeatInfo>[
            SeatInfo.bot(level, partner.single.botIndex),
            SeatInfo.bot(level, theirs.members[1].botIndex),
          ],
        ];
        final c = GameController.cupLocal(settings, seats: seats, rules: rules);
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)));
        if (c.state.phase == GamePhase.gameOver) {
          await CupService.report(key, m.id, c.state.winner == 0 ? me : opp);
        } else {
          _launched.remove(m.id);
        }
        return;
      }
      final seating = CupBracket.seating(bracket.entrants[m.a!], bracket.entrants[m.b!]);
      final mySeat = seating.indexWhere((x) => x.uid == _uid);
      final code = '${key}_${m.id}';
      final oppName = _sideName(s, theirs);
      _activeMe = me;
      _activeOpp = opp;
      if (mySeat == 0) {
        final room = await HostRoom.createWithCode(
          settings,
          code: code,
          name: widget.name,
          rules: rules,
          players: seating.length,
          seatBots: <int, int>{
            for (var i = 0; i < seating.length; i++)
              if (seating[i].isBot) i: seating[i].botIndex,
          },
          botLevel: level,
          expectedPeople: people,
          startBy: DateTime.now().add(CupRules.noShow),
        );
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
            room = await GuestRoom.join(code, settings, widget.name, seat: mySeat);
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
      // Host and guests all see their own team as team 0.
      CupService.report(data.key, id, c.state.winner == 0 ? _activeMe : _activeOpp);
      _clearActive(retry: false);
      return;
    }
    // Decided without being played (nobody came, or it took too long):
    // back to the bracket.
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        final t = OnlineStrings(SettingsScope.read(context).language);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.error('network'))));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleNext() => _run(() => _inNext ? CupService.unregister(_nextKey) : CupService.register(_nextKey, widget.name));

  Future<void> _leaveFriends() async {
    await _run(() => CupService.unregister(_currentKey));
    if (mounted) Navigator.of(context).pop();
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

  String _memberName(Strings s, CupMember x) {
    if (x.isBot) return s.botName(x.botIndex);
    if (x.uid == _uid) return widget.name;
    return x.name.isEmpty ? OnlineStrings(SettingsScope.read(context).language).defaultName : x.name;
  }

  String _sideName(Strings s, CupEntrant e) => e.members.map((x) => _memberName(s, x)).join(' & ');

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final s = Strings.of(context);
    final live = _inCurrent && !_showNext;
    final Widget body;
    if (_currentData == null || (!_friends && _nextData == null)) {
      body = const Center(child: CircularProgressIndicator());
    } else if (live) {
      body = _liveView(t, s);
    } else if (_friends) {
      body = _friendsLobby(t, s);
    } else {
      body = _signupView(t, s);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          live && !_friends ? '${cupTitle(t, type)} · ${t.cupLive}' : cupTitle(t, type),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(top: false, child: body),
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

  Widget _names(OnlineStrings t, List<CupSignup> list) {
    final sorted = list.toList()..sort((a, b) => a.time.compareTo(b.time));
    const shown = 16;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final x in sorted.take(shown))
          Chip(
            label: Text(
              x.uid == _uid ? widget.name : (x.name.isEmpty ? t.defaultName : x.name),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            avatar: Icon(x.uid == _uid ? Icons.star : Icons.person, size: 18),
            backgroundColor: Colors.black.withValues(alpha: 0.3),
          ),
        if (sorted.length > shown)
          Chip(
            label: Text('+${sorted.length - shown}', style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: Colors.black.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  Widget _signupView(OnlineStrings t, Strings s) {
    final data = _nextData!;
    final n = data.signups.length;
    final full = n >= CupRules.size * type.maxGroups && !_inNext;
    final groups = (n + CupRules.size - 1) ~/ CupRules.size;
    final next = _next;
    final left = MenuPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(type.teamSize == 2 ? Icons.groups_rounded : Icons.emoji_events_rounded, color: PastraColors.gold, size: 52),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.nextCup(_clock(next)),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.startsIn(_countdown(next)),
            style: const TextStyle(color: PastraColors.gold, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            t.cupPlayers(n, groups < 1 ? 1 : groups, type.targetScore),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _names(t, data.signups),
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
          BigOutlineButton(icon: Icons.logout_rounded, label: t.cupUnregister, onPressed: _busy ? null : _toggleNext),
        ] else
          BigButton(
            icon: full ? Icons.block : Icons.how_to_reg_rounded,
            label: full ? t.cupFull : t.cupRegister,
            onPressed: _busy || full ? null : _toggleNext,
          ),
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

  Widget _friendsLobby(OnlineStrings t, Strings s) {
    final data = _currentData!;
    final code = widget.friendsCode!;
    final isHost = data.host == _uid;
    final left = MenuPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(t.roomCode, style: const TextStyle(color: Colors.white70, fontSize: 15)),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: code)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, letterSpacing: 10, color: PastraColors.gold),
              ),
            ),
          ),
          Text(t.shareCode, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            t.cupFriendPlayers(
              data.signups.length > CupRules.size ? CupRules.size : data.signups.length,
              data.teamSize == 2 ? s.mode2v2 : s.mode1v1,
              data.targetScore,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _names(t, data.signups),
        ],
      ),
    );
    final Widget right;
    if (data.start != null) {
      // Started, but we are not in it.
      right = Text(
        t.cupAlreadyStarted,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      );
    } else {
      right = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isHost)
            BigButton(
              icon: Icons.play_arrow_rounded,
              label: t.cupStart,
              onPressed: _busy ? null : () => _run(() => CupService.startFriendsCup(_currentKey)),
            )
          else
            Text(
              t.cupWaitCreator,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          BigOutlineButton(icon: Icons.logout_rounded, label: t.cupUnregister, onPressed: _busy ? null : _leaveFriends),
        ],
      );
    }
    return _twoPanes(SingleChildScrollView(child: left), right);
  }

  Widget _liveView(OnlineStrings t, Strings s) {
    final data = _currentData!;
    final bracket = _bracket(data)!;
    final me = bracket.positionOf(_uid);
    final open = me >= 0 ? bracket.openMatchOf(me) : null;
    final cells = <List<BracketCell>>[
      for (final round in bracket.matches)
        <BracketCell>[
          for (final m in round)
            BracketCell(
              a: m.a == null ? null : _sideName(s, bracket.entrants[m.a!]),
              b: m.b == null ? null : _sideName(s, bracket.entrants[m.b!]),
              winner: m.winner == null ? null : (m.winner == m.a ? 0 : 1),
              meA: m.a == me,
              meB: m.b == me,
              current: open != null && open.id == m.id,
            ),
        ],
    ];
    final view = BracketView(
      titles: <String>[for (var r = 0; r < type.rounds; r++) s.tournamentRound(r + 3 - type.rounds)],
      cells: cells,
    );
    final lost = me >= 0 ? bracket.lostIn(me) : -1;
    final children = <Widget>[];
    if (CupBracket.groupCount(data.start!, data.signups, maxGroups: type.maxGroups) > 1) {
      children.add(Text(
        t.cupGroup(bracket.group + 1),
        style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w700),
      ));
    }
    if (bracket.champion == me || lost >= 0) {
      final won = bracket.champion == me;
      final bonus = _bonus(bracket.winsOf(me), won);
      children.addAll(<Widget>[
        Icon(won ? Icons.emoji_events : Icons.sentiment_neutral, color: PastraColors.gold, size: 40),
        Text(
          won ? s.championMsg : s.eliminatedMsg(s.tournamentRound(lost + 3 - type.rounds)),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (bonus > 0)
          Text(s.tournamentBonus(bonus), style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_friends)
          BigButton(icon: Icons.arrow_back_rounded, label: t.back, onPressed: () => Navigator.of(context).pop())
        else
          BigButton(icon: Icons.schedule_rounded, label: t.cupNext, onPressed: () => setState(() => _showNext = true)),
      ]);
    } else if (open != null && open.status == CupMatchStatus.ready) {
      final opp = open.a == me ? open.b! : open.a!;
      children.addAll(<Widget>[
        Text(
          s.tournamentRound(open.round + 3 - type.rounds),
          style: const TextStyle(color: PastraColors.gold, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        Text(
          s.vsName(_sideName(s, bracket.entrants[opp])),
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
              _maybeLaunch(data.key, bracket);
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
