import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../theme.dart';
import 'game_screen.dart';

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
      final room = await HostRoom.create(settings, players: players, level: settings.level, name: name);
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
    final settings = SettingsScope.read(context);
    final t = OnlineStrings(settings.language);
    final code = _code.text.trim();
    if (code.length != 4) {
      setState(() => _error = t.error('notFound'));
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = OnlineStrings(settings.language);
    final s = Strings.of(context);
    return Scaffold(
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _checking
                        ? Text(t.connecting, style: const TextStyle(color: Colors.white70, fontSize: 16))
                        : !_configured
                            ? _notConfigured(t)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    t.online,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  TextField(
                                    controller: _name,
                                    maxLength: 16,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _decoration(t.yourName),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t.createRoom,
                                    style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _busy ? null : () => _create(2),
                                          child: Text(s.mode1v1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _busy ? null : () => _create(4),
                                          child: Text(s.mode2v2),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  Text(
                                    t.joinRoom,
                                    style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: TextField(
                                          controller: _code,
                                          keyboardType: TextInputType.number,
                                          maxLength: 4,
                                          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                                          style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 6),
                                          decoration: _decoration(t.codeHint),
                                          onSubmitted: (_) => _busy ? null : _join(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton(
                                        onPressed: _busy ? null : _join,
                                        child: Text(t.join),
                                      ),
                                    ],
                                  ),
                                  if (_error != null) ...<Widget>[
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 15),
                                    ),
                                  ],
                                  if (_busy) ...<Widget>[
                                    const SizedBox(height: 16),
                                    const Center(child: CircularProgressIndicator()),
                                  ],
                                ],
                              ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
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
  const LobbyScreen({super.key, this.host, this.guest}) : assert((host == null) != (guest == null));

  final HostRoom? host;
  final GuestRoom? guest;

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
    return Scaffold(
      body: Container(
        decoration: feltDecoration,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _watcher,
                      builder: (context, _) {
                        final info = _watcher.info;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              t.roomCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            GestureDetector(
                              onTap: () => Clipboard.setData(ClipboardData(text: _code)),
                              child: Text(
                                _code,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                  color: PastraColors.gold,
                                ),
                              ),
                            ),
                            Text(
                              t.shareCode,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 18),
                            for (var i = 0; i < info.players; i++) _seatRow(t, info, i),
                            const SizedBox(height: 14),
                            if (isHost) ...<Widget>[
                              Text(
                                t.botFills,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _starting ? null : _start,
                                child: Text(t.start),
                              ),
                            ] else
                              Text(
                                t.waitForHost,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              style: TextStyle(color: seat.uid == null ? Colors.white54 : Colors.white, fontSize: 16),
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
