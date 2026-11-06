import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/app_settings.dart';
import '../../game/economy.dart';
import '../../l10n/online_strings.dart';
import '../../l10n/shop_strings.dart';
import '../../l10n/social_strings.dart';
import '../../l10n/strings.dart';
import '../../online/lobby.dart';
import '../../online/online_service.dart';
import '../../online/room_session.dart';
import '../../online/social_service.dart';
import '../premium/premium.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/game_header.dart';
import '../widgets/invite_share.dart';
import '../widgets/menu_tiles.dart';
import '../widgets/name_prompt.dart';
import '../widgets/rules_editor.dart';
import '../widgets/wallet_bar.dart';
import 'cup_hub_screen.dart';
import 'friends_screen.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'store_screen.dart';
import 'tables_screen.dart';

/// Create a room or join one with its 4-digit code.
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, this.joinCode});

  /// Joins this room right away (an invite link or a friend's invitation).
  final String? joinCode;

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
    // The player's code ("Player #1270") and online status for friends.
    if (problem == null) SocialService.instance.start(SettingsScope.read(context));
    final code = widget.joinCode;
    if (problem == null && code != null) {
      _code.text = code;
      // Somebody new from an invite link: their name first.
      if (SettingsScope.read(context).playerName.isEmpty) {
        final name = await askPlayerName(context);
        if (!mounted) return;
        if (name != null) _name.text = name;
      }
      await _joinCode(code);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  /// The error text for an online problem (chips and level from the store texts).
  String _errText(AppSettings settings, String code) {
    final shop = ShopStrings(settings.language);
    return switch (code) {
      'chips' => shop.notEnough,
      'level' => shop.levelTooLow,
      _ => OnlineStrings(settings.language).error(code),
    };
  }

  /// The chosen salon, or null (and an error) when the player may not sit there.
  Salon? _salonOrError(AppSettings settings) {
    // Until the store versions: every table is free.
    if (!Economy.enabled) return Economy.salons.first;
    final salon = Economy.salonFor(settings.salonStake);
    if (settings.playerLevel < salon.minLevel) {
      setState(() => _error = _errText(settings, 'level'));
      return null;
    }
    if (settings.chips < salon.stake) {
      setState(() => _error = _errText(settings, 'chips'));
      return null;
    }
    return salon;
  }

  void _openStore() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StoreScreen()));

  String _playerName(OnlineStrings t) {
    final name = _name.text.trim();
    return name.isEmpty ? t.defaultName : name;
  }

  Future<void> _create(int players) async {
    final settings = SettingsScope.read(context);
    final t = OnlineStrings(settings.language);
    final name = _playerName(t);
    settings.playerName = _name.text.trim();
    final salon = _salonOrError(settings);
    if (salon == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await HostRoom.create(
        settings,
        players: players,
        level: settings.level,
        name: name,
        public: _public,
        stake: salon.stake,
      );
      if (!mounted) {
        room.close();
        return;
      }
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room)),
      );
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = _errText(settings, e.code));
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
      if (mounted) setState(() => _error = _errText(settings, e.code));
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
    final salon = _salonOrError(settings);
    if (salon == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      GuestRoom? guest;
      final tables = Lobby.forQuickMatch(await Lobby.list(), stake: salon.stake);
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
          stake: salon.stake,
        );
        if (!mounted) {
          room.close();
          return;
        }
        setState(() => _busy = false);
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LobbyScreen(host: room)));
      }
    } on OnlineException catch (e) {
      if (mounted) setState(() => _error = _errText(settings, e.code));
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
          return wide ? _wide(t, s, settings) : _narrow(t, s, settings, nameInput(compact: false));
        },
      );
    }
    final showNameInBar = _configured && !_checking && MediaQuery.sizeOf(context).width >= 640;
    return Scaffold(
      appBar: GameAppBar(
        icon: Icons.public,
        title: Text(t.online, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(
            tooltip: SocialStrings(settings.language).friends,
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FriendsScreen())),
            icon: ValueListenableBuilder<List<PlayerStatus>>(
              valueListenable: SocialService.instance.requests,
              builder: (context, requests, _) => Badge(
                isLabelVisible: requests.isNotEmpty || settings.friends.any((f) => f.favorite),
                label: requests.isEmpty ? null : Text('${requests.length}'),
                smallSize: 8,
                backgroundColor: PastraColors.gold,
                textColor: Colors.black,
                child: const Icon(Icons.people_alt_rounded),
              ),
            ),
          ),
          if (Economy.enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(child: WalletBar(onTap: _openStore, compact: true)),
            ),
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

  void _openCup(OnlineStrings t) {
    final settings = SettingsScope.read(context);
    settings.playerName = _name.text.trim();
    final name = _playerName(t);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CupHubScreen(name: name)));
  }

  /// The big emerald card: quick match against a player of your level (and
  /// the salon to play in, when chips are on).
  Widget _hero(OnlineStrings t, AppSettings settings, {required bool fill}) {
    final r = BorderRadius.circular(22);
    final content = Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(t.online, style: PremiumText.eyebrow),
          const SizedBox(height: 6),
          Text(t.quickMatch, style: PremiumText.title.copyWith(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            t.quickMatchHint,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBFE3D6), fontSize: 14, fontWeight: FontWeight.w500),
          ),
          if (Economy.enabled) ...<Widget>[
            const SizedBox(height: 14),
            _salonBar(settings),
          ],
          if (fill) const Spacer() else const SizedBox(height: 18),
          GoldButton(
            label: t.quickMatch,
            icon: Icons.bolt_rounded,
            onPressed: _busy ? null : _quickMatch,
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F6A51), Color(0xFF0A4637), Color(0xFF072C23)],
          stops: <double>[0.0, 0.6, 1.0],
        ),
        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: <Widget>[
            // Two faint gold rings with a "Π" (a table seen from above).
            Positioned(
              right: -80,
              bottom: fill ? 70 : -40,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: PastraColors.gold.withValues(alpha: 0.16), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: PastraColors.gold.withValues(alpha: 0.12), width: 2),
                      ),
                      child: Text(
                        'Π',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 90,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: PastraColors.gold.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (fill) Positioned.fill(child: content) else content,
          ],
        ),
      ),
    );
  }

  /// Cups, open tables and the leaderboard as small tiles (wide screens).
  List<Widget> _moreTiles(OnlineStrings t, {required double height}) => <Widget>[
        LobbyTile(
          icon: Icons.emoji_events_rounded,
          label: t.cup,
          height: height,
          onTap: _busy ? null : () => _openCup(t),
        ),
        LobbyTile(
          icon: Icons.table_restaurant_rounded,
          label: t.openTables,
          height: height,
          onTap: _busy ? null : _openTables,
        ),
        LobbyTile(
          icon: Icons.leaderboard_rounded,
          label: t.leaderboard,
          height: height,
          onTap: _busy ? null : _openLeaderboard,
        ),
      ];

  /// Cups, open tables and the leaderboard: rows like the lobby's.
  List<Widget> _moreRows(OnlineStrings t, {required bool compact}) {
    final h = compact ? 60.0 : 68.0;
    return <Widget>[
      ModeRow(
        icon: Icons.emoji_events_rounded,
        accent: PastraColors.gold,
        title: t.cup,
        subtitle: t.cupHint,
        height: h,
        onTap: _busy ? null : () => _openCup(t),
      ),
      ModeRow(
        icon: Icons.table_restaurant_rounded,
        accent: PastraColors.teal,
        title: t.openTables,
        height: h,
        onTap: _busy ? null : _openTables,
      ),
      ModeRow(
        icon: Icons.leaderboard_rounded,
        accent: PastraColors.coral,
        title: t.leaderboard,
        height: h,
        onTap: _busy ? null : _openLeaderboard,
      ),
    ];
  }

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
              Icon(_public ? Icons.public : Icons.lock_outline, size: 18, color: _public ? PastraColors.gold : PastraColors.text2),
              const SizedBox(width: 6),
              Text(
                _public ? t.publicRoom : t.privateRoom,
                style: TextStyle(
                  color: _public ? PastraColors.gold : PastraColors.text2,
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

  /// A room of your own: 1 vs 1 or 2 vs 2, public or private, your rules.
  Widget _createPanel(OnlineStrings t, Strings s) => SectionPanel(
        title: t.createRoom,
        icon: Icons.add_rounded,
        trailing: _visibilityPill(t),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: GlassButton(
                    icon: Icons.person_rounded,
                    label: s.mode1v1,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: _busy ? null : () => _create(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    icon: Icons.groups_rounded,
                    label: s.mode2v2,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: _busy ? null : () => _create(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // The rules of the room's game (the host's choice).
            RulesButton(enabled: !_busy),
          ],
        ),
      );

  /// A friend's room: the four-digit code.
  Widget _joinPanel(OnlineStrings t) => SectionPanel(
        title: t.joinRoom,
        icon: Icons.vpn_key_rounded,
        accent: PastraColors.teal,
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: PastraColors.text, fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w800),
                // A plain hint (not a label): it must not take the big spaced-out
                // style of the code itself.
                decoration: InputDecoration(
                  hintText: t.codeHint,
                  hintMaxLines: 1,
                  hintStyle: const TextStyle(color: PastraColors.muted, fontSize: 15, letterSpacing: 0, fontWeight: FontWeight.w500),
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
                onSubmitted: (_) => _busy ? null : _join(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 116,
              child: GoldButton(
                label: t.join,
                icon: Icons.login_rounded,
                height: 50,
                fontSize: 17,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: _busy ? null : _join,
              ),
            ),
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
            style: const TextStyle(color: PastraColors.coral, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        );

  /// Landscape (phones held sideways, tablets, desktop): the quick match
  /// card on the left; rooms, cups, open tables and the leaderboard on the
  /// right.
  Widget _wide(OnlineStrings t, Strings s, AppSettings settings) {
    final error = _errorText();
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 420;
        final gap = compact ? 10.0 : 14.0;
        // Not taller than this on a big window: the content stays compact
        // in the middle instead of stretching from top to bottom.
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 520),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 10 : 16, 16, compact ? 10 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: _hero(t, settings, fill: true)),
                  SizedBox(width: gap),
                  Expanded(
                    // The tiles take what is left, so both columns end on the
                    // same line; a very low window scrolls instead.
                    child: LayoutBuilder(
                      builder: (context, side) {
                        final fill = side.maxHeight >= 380;
                        final tileRow = Row(
                          crossAxisAlignment: fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                          children: <Widget>[
                            for (final (i, tile) in _moreTiles(t, height: fill ? double.infinity : 74).indexed) ...<Widget>[
                              if (i > 0) SizedBox(width: gap),
                              Expanded(child: tile),
                            ],
                          ],
                        );
                        final column = Column(
                          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _createPanel(t, s),
                            SizedBox(height: gap),
                            _joinPanel(t),
                            if (error != null) error,
                            SizedBox(height: gap),
                            if (fill) Expanded(child: tileRow) else tileRow,
                          ],
                        );
                        return fill ? column : SingleChildScrollView(child: column);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Portrait: everything in one column.
  Widget _narrow(OnlineStrings t, Strings s, AppSettings settings, Widget nameField) {
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
              const SizedBox(height: 10),
              _hero(t, settings, fill: false),
              const SizedBox(height: 14),
              _createPanel(t, s),
              const SizedBox(height: 12),
              _joinPanel(t),
              if (error != null) error,
              for (final r in _moreRows(t, compact: false)) ...<Widget>[const SizedBox(height: 10), r],
            ],
          ),
        ),
      ),
    );
  }

  /// The salons (entry fees) for quick match and new tables, and what the
  /// winner gets in the chosen one.
  Widget _salonBar(AppSettings settings) {
    final shop = ShopStrings(settings.language);
    final chosen = Economy.salonFor(settings.salonStake);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 62,
          child: Center(
            child: ListView(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final salon in Economy.salons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SalonChip(
                      salon: salon,
                      shop: shop,
                      selected: salon.stake == chosen.stake,
                      locked: settings.playerLevel < salon.minLevel,
                      short: settings.chips < salon.stake,
                      onTap: _busy
                          ? null
                          : () => setState(() {
                                settings.salonStake = salon.stake;
                                _error = null;
                              }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Tooltip(
          message: shop.salonHint,
          child: Text(
            chosen.free
                ? '${shop.salonName(chosen)} · ${shop.free}'
                : '${shop.entry(Economy.group(chosen.stake))} · ${shop.pot(Economy.group(Economy.payout(chosen.stake)))}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBFE3D6), fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
  const LobbyScreen({super.key, this.host, this.guest, this.cupOpponent, this.rematch = false})
      : assert((host == null) != (guest == null));

  /// The table of a rematch (after an online game).
  final bool rematch;

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

  /// The people at this table go to the recent players (friends list).
  void _rememberPlayers() {
    final me = OnlineService.uid;
    final people = <String, String>{
      for (final seat in _watcher.info.seats)
        if (seat.uid != null && seat.uid != me) seat.uid!: seat.name,
    };
    SettingsScope.read(context).addRecentPlayers(people);
  }

  void _guestGameReady() {
    final c = widget.guest?.controller.value;
    if (c == null || _handedOver || !mounted) return;
    _handedOver = true;
    _rememberPlayers();
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
      _rememberPlayers();
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
      appBar: GameAppBar(
        icon: Icons.public,
        title: Text(
          cup ? t.cup : (widget.rematch ? SocialStrings(SettingsScope.of(context).language).rematch : (quick ? t.quickMatch : t.online)),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Felt(
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: _watcher,
            builder: (context, _) {
              final info = _watcher.info;
              final codeCard = cup
                  ? _WaitHero(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.emoji_events_rounded, color: PastraColors.gold, size: 48),
                          const SizedBox(height: 6),
                          Text(
                            Strings.of(context).vsName(widget.cupOpponent!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: PastraColors.text, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )
                  : _WaitHero(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(t.roomCode, style: PremiumText.eyebrow),
                    GestureDetector(
                      onTap: () => Clipboard.setData(ClipboardData(text: _code)),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _code,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 12,
                            color: PastraColors.goldLight,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      t.shareCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFBFE3D6), fontSize: 14),
                    ),
                    if (!quick || widget.rematch) ...<Widget>[
                      const SizedBox(height: 12),
                      InviteShareRow(code: _code),
                      if (isHost && SettingsScope.of(context).friends.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => showInviteFriendsSheet(context, _code),
                          icon: const Icon(Icons.people_alt_rounded, color: PastraColors.gold),
                          label: Text(
                            SocialStrings(SettingsScope.of(context).language).inviteFriends,
                            style: const TextStyle(color: PastraColors.gold, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
              final stake = widget.host?.stake ?? widget.guest!.stake;
              final actions = <Widget>[
                if (stake > 0) ...<Widget>[
                  _StakeBadge(stake: stake, shop: ShopStrings(SettingsScope.of(context).language)),
                  const SizedBox(height: 12),
                ],
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
                          cup
                              ? t.cupOpponentWait(widget.cupOpponent!)
                              : (widget.rematch ? SocialStrings(SettingsScope.of(context).language).rematchWait : t.searching),
                          style: const TextStyle(color: PastraColors.text, fontSize: 17, fontWeight: FontWeight.w700),
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
                    style: const TextStyle(color: PastraColors.text2, fontSize: 13),
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
                    // The room code (or the cup match) on the left, the table
                    // with its seats and the buttons on the right: two equal
                    // columns of the same height.
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 520),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(child: Center(child: SingleChildScrollView(child: codeCard))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SectionPanel(
                                  expand: true,
                                  child: Center(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          _RoomTable(info: info),
                                          const SizedBox(height: 14),
                                          ...seats,
                                          const SizedBox(height: 8),
                                          ...actions,
                                        ],
                                      ),
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
                            _RoomTable(info: info),
                            const SizedBox(height: 14),
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
    final taken = seat.uid != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: glassDecoration(radius: 14, selected: mine),
      child: Row(
        children: <Widget>[
          if (taken)
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                PlayerAvatar(name: label, size: 40),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: seat.online ? PastraColors.teal : PastraColors.coral,
                      border: Border.all(color: PastraColors.nightMid, width: 2.5),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: const Icon(Icons.hourglass_empty_rounded, color: PastraColors.muted, size: 18),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: taken ? (mine ? PastraColors.goldLight : PastraColors.text) : PastraColors.muted,
                fontSize: 16,
                fontWeight: taken ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          for (final tag in tags)
            Container(
              margin: const EdgeInsetsDirectional.only(start: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PastraColors.gold.withValues(alpha: 0.5)),
              ),
              child: Text(tag, style: const TextStyle(color: PastraColors.goldLight, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          if (info.players == 4) ...<Widget>[
            const SizedBox(width: 8),
            Text(t.team(i % 2 + 1), style: const TextStyle(color: PastraColors.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// The waiting room's emerald card (the room code, or the cup match).
class _WaitHero extends StatelessWidget {
  const _WaitHero({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// The room's table seen from above: a gold dot on every taken seat.
class _RoomTable extends StatelessWidget {
  const _RoomTable({required this.info});

  final RoomInfo info;

  @override
  Widget build(BuildContext context) {
    const w = 170.0;
    const h = 84.0;
    final four = info.players == 4;
    final spots = four
        ? const <Offset>[Offset(w / 2, h), Offset(w, h / 2), Offset(w / 2, 0), Offset(0, h / 2)]
        : const <Offset>[Offset(w / 2, h), Offset(w / 2, 0)];
    bool taken(int i) => info.seats.length > i && info.seats[i].uid != null;
    return Center(
      child: SizedBox(
        width: w + 28,
        height: h + 28,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 14,
              top: 14,
              width: w,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                  gradient: const RadialGradient(
                    colors: <Color>[PastraColors.emeraldLight, PastraColors.emerald, PastraColors.emeraldDark],
                    stops: <double>[0.0, 0.6, 1.0],
                  ),
                  border: Border.all(color: PastraColors.wood, width: 5),
                  boxShadow: <BoxShadow>[BoxShadow(color: PastraColors.gold.withValues(alpha: 0.9), spreadRadius: 1.5)],
                ),
              ),
            ),
            for (var i = 0; i < spots.length; i++)
              Positioned(
                left: spots[i].dx + 14 - 12,
                top: spots[i].dy + 14 - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: taken(i) ? PastraColors.gold : PastraColors.raised,
                    border: Border.all(color: taken(i) ? PastraColors.goldLight : Colors.white24, width: 2),
                  ),
                  child: taken(i) ? const Icon(Icons.person_rounded, size: 14, color: PastraColors.goldInk) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// One salon: its name and entry fee; locked below its level.
class _SalonChip extends StatelessWidget {
  const _SalonChip({
    required this.salon,
    required this.shop,
    required this.selected,
    required this.locked,
    required this.short,
    required this.onTap,
  });

  final Salon salon;
  final ShopStrings shop;
  final bool selected;

  /// The player's level is too low.
  final bool locked;

  /// Not enough chips (still selectable; the store gives more).
  final bool short;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final vip = salon.id == 'vip';
    return Opacity(
      opacity: locked ? 0.5 : (short ? 0.75 : 1),
      child: Material(
        color: selected ? PastraColors.gold.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked ? null : onTap,
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? PastraColors.gold : (vip ? diamondColor.withValues(alpha: 0.7) : Colors.white24),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    shop.salonName(salon),
                    style: TextStyle(
                      color: selected ? PastraColors.gold : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: locked
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(shop.fromLevel(salon.minLevel), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        )
                      : salon.free
                          ? Text(shop.free, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const ChipIcon(size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  Economy.short(salon.stake),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The entry fee and the prize of the table (waiting room).
class _StakeBadge extends StatelessWidget {
  const _StakeBadge({required this.stake, required this.shop});

  final int stake;
  final ShopStrings shop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PastraColors.gold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ChipIcon(size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${shop.salonName(Economy.salonFor(stake))} · ${shop.entry(Economy.group(stake))} · ${shop.pot(Economy.group(Economy.payout(stake)))}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
