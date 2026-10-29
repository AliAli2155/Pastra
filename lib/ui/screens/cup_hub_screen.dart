import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/rules.dart';
import '../../game/app_settings.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/strings.dart';
import '../../online/cup_logic.dart';
import '../../online/cup_service.dart';
import '../../online/online_service.dart';
import '../theme.dart';
import '../widgets/menu_tiles.dart';
import 'cup_screen.dart';

/// The online cups: three scheduled kinds and the friends cup.
class CupHubScreen extends StatefulWidget {
  const CupHubScreen({super.key, required this.name});

  final String name;

  @override
  State<CupHubScreen> createState() => _CupHubScreenState();
}

class _CupHubScreenState extends State<CupHubScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // The "next at …" times move on.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _open(CupType type, {String? code}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CupScreen(type: type, name: widget.name, friendsCode: code)),
    );
  }

  Widget _tile(OnlineStrings t, CupType type, String hint, List<Color> colors, IconData icon, {bool dark = false}) {
    final next = type.nextStart(OnlineService.serverNow);
    return MenuTile(
      icon: icon,
      title: cupTitle(t, type),
      subtitle: '$hint\n${t.cupAt(_time(next))}',
      colors: colors,
      darkText: dark,
      onTap: () => _open(type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    final quick = _tile(t, CupType.quick, t.cupQuickHint, TileColors.gold, Icons.bolt_rounded, dark: true);
    final classic = _tile(t, CupType.classic, t.cupClassicHint, TileColors.blue, Icons.emoji_events_rounded);
    final team = _tile(t, CupType.team, t.cupTeamHint, TileColors.green, Icons.groups_rounded);
    final friends = MenuTile(
      icon: Icons.vpn_key_rounded,
      title: t.cupFriends,
      subtitle: t.cupFriendsHint,
      colors: TileColors.purple,
      onTap: _friendsDialog,
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.cup, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Felt(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth >= 640) {
                // A 2 × 2 grid.
                Widget column(Widget a, Widget b) => Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[Expanded(child: a), const SizedBox(height: 14), Expanded(child: b)],
                      ),
                    );
                return ScaleUp(
                  child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 460),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[column(quick, classic), const SizedBox(width: 14), column(team, friends)],
                      ),
                    ),
                  ),
                ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  for (final tile in <Widget>[quick, classic, team, friends])
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: SizedBox(height: 120, child: tile)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Create a friends cup, or join one with its code.
  Future<void> _friendsDialog() async {
    final t = OnlineStrings(SettingsScope.read(context).language);
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => _FriendsDialog(t: t, name: widget.name),
    );
    if (code != null && mounted) _open(CupType.friends, code: code);
  }
}

class _FriendsDialog extends StatefulWidget {
  const _FriendsDialog({required this.t, required this.name});

  final OnlineStrings t;
  final String name;

  @override
  State<_FriendsDialog> createState() => _FriendsDialogState();
}

class _FriendsDialogState extends State<_FriendsDialog> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;

  /// The new cup: 1 = 1v1, 2 = 2v2, and the points to play to.
  int _teams = 1;
  int _target = 51;
  String? _error;

  OnlineStrings get t => widget.t;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await CupService.createFriendsCup(widget.name, teamSize: _teams, targetScore: _target);
      if (mounted) Navigator.of(context).pop(code);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = t.error('network');
        });
      }
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    String? problem;
    try {
      final key = '${CupType.friends.id}$code';
      final data = await CupService.read(key);
      final mine = data.hasSignup(OnlineService.uid);
      if (data.host == null) {
        problem = t.cupNoSuchCode;
      } else if (data.start != null && !mine) {
        problem = t.cupAlreadyStarted;
      } else if (!mine && data.signups.length >= CupRules.size) {
        problem = t.cupFriendsFull;
      } else if (!mine) {
        await CupService.register(key, widget.name);
      }
    } catch (_) {
      problem = t.error('network');
    }
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(code);
    } else {
      setState(() {
        _busy = false;
        _error = problem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    const label = TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700);
    final create = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(t.cupCreate, style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(s.gameType, style: label),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: ChoiceCard(
                icon: Icons.person,
                label: s.mode1v1,
                selected: _teams == 1,
                onTap: () => setState(() => _teams = 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceCard(
                icon: Icons.groups,
                label: s.mode2v2,
                selected: _teams == 2,
                onTap: () => setState(() => _teams = 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(s.targetScore, style: label),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final p in PastraRules.targetOptions) ...<Widget>[
              if (p != PastraRules.targetOptions.first) const SizedBox(width: 8),
              Expanded(
                child: ChoiceCard(label: '$p', selected: _target == p, onTap: () => setState(() => _target = p)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        BigButton(icon: Icons.add_rounded, label: t.cupCreate, onPressed: _busy ? null : _create),
      ],
    );
    final join = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(t.cupJoinCode, style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 5,
          textAlign: TextAlign.center,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '12345',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 26, letterSpacing: 8),
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
        const SizedBox(height: 12),
        BigButton(label: t.join, icon: Icons.login_rounded, onPressed: _busy ? null : _join),
      ],
    );
    final status = <Widget>[
      if (_error != null) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFB4A9), fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
      if (_busy) ...<Widget>[
        const SizedBox(height: 12),
        const Center(child: CircularProgressIndicator()),
      ],
    ];
    return Dialog(
      backgroundColor: PastraColors.panel,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: LayoutBuilder(
          builder: (context, box) {
            // Side by side when there is room (phones held sideways), else
            // one under the other.
            final side = box.maxWidth >= 600;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    t.cupFriends,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (side)
                    Row(
                      children: <Widget>[
                        Expanded(flex: 3, child: create),
                        const SizedBox(
                          width: 29,
                          child: Center(child: SizedBox(width: 1, height: 200, child: ColoredBox(color: Colors.white24))),
                        ),
                        Expanded(flex: 2, child: join),
                      ],
                    )
                  else ...<Widget>[
                    create,
                    const Divider(color: Colors.white24, height: 28),
                    join,
                  ],
                  ...status,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
