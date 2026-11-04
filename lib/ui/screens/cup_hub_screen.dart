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
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
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

  /// A cup as a row: tinted icon, name, its line and the next start.
  Widget _row(OnlineStrings t, CupType type, String hint, Color accent, IconData icon, {required double height}) {
    final next = type.nextStart(OnlineService.serverNow);
    return ModeRow(
      icon: icon,
      accent: accent,
      title: cupTitle(t, type),
      subtitle: '${t.cupAt(_time(next))} · $hint',
      height: height,
      onTap: () => _open(type),
    );
  }

  /// The quick cup, the one that starts soonest: a big emerald card.
  Widget _hero(OnlineStrings t, {required bool fill}) {
    final next = CupType.quick.nextStart(OnlineService.serverNow);
    final children = <Widget>[
      Text(t.cup, style: PremiumText.eyebrow),
      const SizedBox(height: 6),
      Text(cupTitle(t, CupType.quick), style: PremiumText.title.copyWith(fontSize: 30)),
      const SizedBox(height: 6),
      Text(
        t.cupQuickHint,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFBFE3D6), fontSize: 14, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.schedule_rounded, size: 16, color: PastraColors.goldLight),
              const SizedBox(width: 6),
              Text(
                t.cupAt(_time(next)),
                style: const TextStyle(color: PastraColors.goldLight, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      if (fill) const Spacer() else const SizedBox(height: 18),
      GoldButton(label: t.join, icon: Icons.bolt_rounded, onPressed: () => _open(CupType.quick)),
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F6A51), Color(0xFF0A4637), Color(0xFF072C23)],
          stops: <double>[0.0, 0.6, 1.0],
        ),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = OnlineStrings(SettingsScope.of(context).language);
    return Scaffold(
      appBar: GameAppBar(icon: Icons.emoji_events_rounded, title: Text(t.cup)),
      body: Felt(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 640;
              final h = wide && box.maxHeight < 420 ? 64.0 : 80.0;
              final rows = <Widget>[
                _row(t, CupType.classic, t.cupClassicHint, PastraColors.gold, Icons.emoji_events_rounded, height: h),
                _row(t, CupType.team, t.cupTeamHint, PastraColors.teal, Icons.groups_rounded, height: h),
                ModeRow(
                  icon: Icons.vpn_key_rounded,
                  accent: PastraColors.coral,
                  title: t.cupFriends,
                  subtitle: t.cupFriendsHint,
                  height: h,
                  onTap: _friendsDialog,
                ),
              ];
              if (wide) {
                // The quick cup on the left, the others as rows on the right.
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(flex: 9, child: _hero(t, fill: true)),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 11,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  for (var i = 0; i < rows.length; i++) ...<Widget>[
                                    if (i > 0) const SizedBox(height: 12),
                                    rows[i],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _hero(t, fill: false),
                  for (final r in rows) ...<Widget>[const SizedBox(height: 12), r],
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
