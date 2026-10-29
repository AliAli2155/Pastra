import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/lobby.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../theme.dart';
import '../widgets/menu_tiles.dart';
import 'cup_hub_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'tables_screen.dart';

/// Create a room or join one with its 4-digit code.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _checking = true;
  bool _busy = false;
  bool _configured = false;

  /// New rooms are listed in the open tables.
  bool _public = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = SettingsScope.read(context).playerName;
    _check();
  }

  Future<void> _check() async {
    final problem = await OnlineService.ensureReady();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _configured = problem == null;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String _playerName(OnlineStrings t) {
    final name = _name.text.trim();
    return name.isEmpty ? t.defaultName : name;
  }

  Future<void> _create(int players) async {
    final settings = SettingsScope.read(context);
    final t = OnlineStrings(settings.language);
    final name = _playerName(t);
    settings.playerName = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await HostRoom.create(settings, players: players, level: settings.level, name: name, public: _public);
      if (!mounted) {
        room.close();
        return;
      }
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room)),
      );
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = t.error(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = t.error('network'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() async {
    final t = OnlineStrings(SettingsScope.read(context).language);
    final code = _code.text.trim();
    if (code.length != 4) {
      setState(() => _error = t.error('notFound'));
      return;
    }
    await _joinCode(code);
  }

  /// Joins the room with this code and opens its waiting room.
  Future<void> _joinCode(String code) async {
    final settings = SettingsScope.read(context);
    final t = OnlineStrings(settings.language);
    final name = _playerName(t);
    settings.playerName = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await GuestRoom.join(code, settings, name);
      if (!mounted) {
        room.close();
        return;
      }
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(guest: room)),
      );
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = t.error(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = t.error('network'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openTables() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute<String>(builder: (_) => const TablesScreen()));
    if (code == null || !mounted) return;
    await _joinCode(code);
  }

  /// Takes a seat at an open 1v1 table; with none, opens one and waits.
  Future<void> _quickMatch() async {
    final settings = SettingsScope.read(context);
    final t = OnlineStrings(settings.language);
    final name = _playerName(t);
    settings.playerName = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      GuestRoom? guest;
      final tables = Lobby.forQuickMatch(await Lobby.list());
      for (final table in tables) {
        try {
          guest = await GuestRoom.join(table.code, settings, name);
          break;
        } on OnlineException {
          // Taken or started in the meantime: try the next one.
        }
      }
      if (!mounted) {
        guest?.close();
        return;
      }
      if (guest != null) {
        setState(() => _busy = false);
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LobbyScreen(guest: guest)));
      } else {
        final room = await HostRoom.create(
          settings,
          players: 2,
          level: settings.level,
          name: name,
          public: true,
          autoStart: true,
        );
        if (!mounted) {
          room.close();
          return;
        }
        setState(() => _busy = false);
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room)));
      }
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = t.error(e.code));
    } catch (_) {
      if (mounted) setState(() => _error = t.error('network'));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _openLeaderboard() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LeaderboardScreen()));

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = OnlineStrings(settings.language);
    final s = Strings.of(context);
    Widget nameInput({required bool compact}) => TextField(
          controller: _name,
          maxLength: 16,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: (compact
                  ? InputDecoration(
                      hintText: t.yourName,
                      hintStyle: const TextStyle(color: Colors.white54),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.25),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: PastraColors.gold),
                      ),
                    )
                  : _decoration(t.yourName))
              .copyWith(
            isDense: true,
            prefixIcon: const Icon(Icons.person_outline, color: Colors.white70, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 32),
          ),
        );
    final Widget body;
    if (_checking) {
      body = Center(child: Text(t.connecting, style: const TextStyle(color: Colors.white70, fontSize: 18)));
    } else if (!_configured) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _notConfigured(t)),
        ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 640;
          return wide ? ScaleUp(child: _wide(t, s)) : _narrow(t, s, nameInput(compact: false));
        },
      );
    }
    final showNameInBar = _configured && !_checking && MediaQuery.sizeOf(context).width >= 640;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.online, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: <Widget>[
          if (showNameInBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Center(child: SizedBox(width: 220, child: nameInput(compact: true))),
            ),
        ],
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: body),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickTile(OnlineStrings t) => MenuTile(
        icon: Icons.bolt_rounded,
        title: t.quickMatch,
        subtitle: t.quickMatchHint,
        colors: TileColors.blue,
        onTap: _busy ? null : _quickMatch,
      );

  void _openCup(OnlineStrings t) {
    final settings = SettingsScope.read(context);
    settings.playerName = _name.text.trim();
    final name = _playerName(t);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CupHubScreen(name: name)));
  }

  Widget _cupTile(OnlineStrings t) => MenuTile(
        icon: Icons.emoji_events_rounded,
        title: t.cup,
        subtitle: t.cupHint,
        colors: TileColors.gold,
        darkText: true,
        onTap: _busy ? null : () => _openCup(t),
      );

  Widget _tablesTile(OnlineStrings t) => MenuTile(
        icon: Icons.table_restaurant_rounded,
        title: t.openTables,
        colors: TileColors.teal,
        onTap: _busy ? null : _openTables,
      );

  Widget _boardTile(OnlineStrings t) => MenuTile(
        icon: Icons.leaderboard_rounded,
        title: t.leaderboard,
        colors: TileColors.purple,
        onTap: _busy ? null : _openLeaderboard,
      );

  /// Public (listed in the open tables) or private (code only): a switch in
  /// the title row of "Create a room".
  Widget _visibilityPill(OnlineStrings t) {
    return Tooltip(
      message: t.showInTables,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : () => setState(() => _public = !_public),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_public ? Icons.public : Icons.lock_outline, size: 18, color: _public ? PastraColors.gold : Colors.white60),
              const SizedBox(width: 6),
              Text(
                _public ? t.publicRoom : t.privateRoom,
                style: TextStyle(
                  color: _public ? PastraColors.gold : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                height: 30,
                child: FittedBox(
                  child: Switch(
                    value: _public,
                    onChanged: _busy ? null : (v) => setState(() => _public = v),
                    activeThumbColor: PastraColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createPanel(OnlineStrings t, Strings s) => MenuPanel(
        title: t.createRoom,
        trailing: _visibilityPill(t),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: BigButton(icon: Icons.person, label: s.mode1v1, onPressed: _busy ? null : () => _create(2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BigButton(icon: Icons.groups, label: s.mode2v2, onPressed: _busy ? null : () => _create(4)),
            ),
          ],
        ),
      );

  Widget _joinPanel(OnlineStrings t) => MenuPanel(
        title: t.joinRoom,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
                // A plain hint (not a label): it must not take the big spaced-out
                // style of the code itself.
                decoration: InputDecoration(
                  hintText: t.codeHint,
                  hintMaxLines: 1,
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.w500),
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: PastraColors.gold, width: 2),
                  ),
                ),
                onSubmitted: (_) => _busy ? null : _join(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 120, child: BigButton(label: t.join, icon: Icons.login_rounded, onPressed: _busy ? null : _join)),
          ],
        ),
      );

  Widget? _errorText() => _error == null
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _error!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 15, fontWeight: FontWeight.w600),
          ),
        );

  /// Landscape (phones held sideways, tablets, desktop): three columns.
  Widget _wide(OnlineStrings t, Strings s) {
    final error = _errorText();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _wideRow(t, s)),
              if (error != null) error,
            ],
          ),
        ),
      ),
    );
  }

  /// Three columns, each split into two equal rows: a tidy 3 × 2 grid.
  Widget _wideRow(OnlineStrings t, Strings s) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _quickTile(t)),
                    const SizedBox(height: 14),
                    Expanded(child: _cupTile(t)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _tablesTile(t)),
                    const SizedBox(height: 14),
                    Expanded(child: _boardTile(t)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                // Same rows as the middle column: the edges line up.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _createPanel(t, s)),
                    const SizedBox(height: 14),
                    Expanded(child: _joinPanel(t)),
                  ],
                ),
              ),
            ],
          );

  /// Portrait: everything in one column.
  Widget _narrow(OnlineStrings t, Strings s, Widget nameField) {
    final error = _errorText();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              nameField,
              const SizedBox(height: 4),
              SizedBox(height: 150, child: _quickTile(t)),
              const SizedBox(height: 12),
              SizedBox(height: 110, child: _cupTile(t)),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _tablesTile(t)),
                    const SizedBox(width: 12),
                    Expanded(child: _boardTile(t)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _createPanel(t, s),
              const SizedBox(height: 12),
              _joinPanel(t),
              if (error != null) error,
            ],
          ),
        ),
      ),
    );
  }

  Widget _notConfigured(OnlineStrings t) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 48, color: PastraColors.gold),
          const SizedBox(height: 12),
          Text(
            t.notConfigured,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            t.notConfiguredHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PastraColors.gold),
        ),
      );
}

/// Waiting room: shows the code and who has joined.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, this.host, this.guest, this.cupOpponent})
      : assert((host == null) != (guest == null));

  final HostRoom? host;
  final GuestRoom? guest;

  /// A tournament match against this player: no "play against the computer"
  /// (a match with a bot would count as a win).
  final String? cupOpponent;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _handedOver = false;
  bool _starting = false;

  RoomWatcher get _watcher => widget.host?.watcher ?? widget.guest!.watcher;

  String get _code => widget.host?.code ?? widget.guest!.code;

  @override
  void initState() {
    super.initState();
    widget.guest?.controller.addListener(_guestGameReady);
    widget.guest?.closed.addListener(_guestClosed);
    if (widget.host?.autoStart == true) widget.host!.watcher.addListener(_autoStart);
    // A tournament match starts at the latest at this time, with bots for
    // whoever did not come.
    final by = widget.host?.startBy;
    if (by != null) {
      final wait = by.difference(DateTime.now());
      _startTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
        if (mounted && !_starting) _start();
      });
    }
  }

  Timer? _startTimer;

  /// Quick match: the game starts by itself once every seat is taken.
  void _autoStart() {
    final host = widget.host;
    if (host == null || _starting || !mounted) return;
    final info = host.watcher.info;
    if (info.exists && info.joined >= (host.expectedPeople ?? info.players)) _start();
  }

  void _guestGameReady() {
    final c = widget.guest?.controller.value;
    if (c == null || _handedOver || !mounted) return;
    _handedOver = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)),
    );
  }

  void _guestClosed() {
    if (_handedOver || !mounted || widget.guest?.closed.value != true) return;
    final t = OnlineStrings(SettingsScope.read(context).language);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.hostLeft)));
    Navigator.of(context).pop();
  }

  Future<void> _start() async {
    final host = widget.host;
    if (host == null || _starting) return;
    setState(() => _starting = true);
    try {
      final c = await host.start();
      if (!mounted) return;
      _handedOver = true;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)),
      );
    } catch (_) {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    widget.guest?.controller.removeListener(_guestGameReady);
    widget.guest?.closed.removeListener(_guestClosed);
    widget.host?.watcher.removeListener(_autoStart);
    _startTimer?.cancel();
    if (!_handedOver) {
      widget.host?.close();
      widget.guest?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final isHost = widget.host != null;
    final quick = widget.host?.autoStart == true;
    final cup = widget.cupOpponent != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(cup ? t.cup : (quick ? t.quickMatch : t.online), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: _watcher,
            builder: (context, _) {
              final info = _watcher.info;
              final codeCard = cup
                  ? MenuPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.emoji_events_rounded, color: PastraColors.gold, size: 48),
                          const SizedBox(height: 6),
                          Text(
                            Strings.of(context).vsName(widget.cupOpponent!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    )
                  : MenuPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(t.roomCode, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: _code)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _code,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 12,
                            color: PastraColors.gold,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      t.shareCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              );
              final actions = <Widget>[
                if (isHost && quick) ...<Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: PastraColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          cup ? t.cupOpponentWait(widget.cupOpponent!) : t.searching,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (!cup) ...<Widget>[
                    const SizedBox(height: 12),
                    BigOutlineButton(
                      icon: Icons.smart_toy_outlined,
                      label: t.playVsBot,
                      onPressed: _starting ? null : _start,
                    ),
                  ],
                ] else if (isHost) ...<Widget>[
                  Text(
                    t.botFills,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  BigButton(icon: Icons.play_arrow_rounded, label: t.start, onPressed: _starting ? null : _start),
                ] else
                  Text(
                    t.waitForHost,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
              ];
              final seats = <Widget>[for (var i = 0; i < info.players; i++) _seatRow(t, info, i)];
              return LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 640) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: <Widget>[
                              Expanded(flex: 4, child: Center(child: codeCard)),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: <Widget>[...seats, const SizedBox(height: 8), ...actions],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            codeCard,
                            const SizedBox(height: 16),
                            ...seats,
                            const SizedBox(height: 8),
                            ...actions,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _seatRow(OnlineStrings t, RoomInfo info, int i) {
    final seat = info.seats.length > i ? info.seats[i] : const RoomSeat();
    final mine = widget.guest?.mySeat == i || (widget.host != null && i == 0);
    final label = seat.uid != null ? seat.name : t.waiting;
    final tags = <String>[
      if (i == 0) t.host,
      if (mine) t.you,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PastraColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mine ? PastraColors.gold : Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            seat.uid == null ? Icons.hourglass_empty : Icons.person,
            color: seat.uid == null ? Colors.white38 : (seat.online ? Colors.greenAccent : Colors.orangeAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tags.isEmpty ? label : '$label  (${tags.join(', ')})',
              style: TextStyle(
                color: seat.uid == null ? Colors.white54 : Colors.white,
                fontSize: 17,
                fontWeight: seat.uid == null ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          if (info.players == 4)
            Text(
              t.team(i % 2 + 1),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
