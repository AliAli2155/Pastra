import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../fullscreen_stub.dart' if (dart.library.js_interop) '../fullscreen_web.dart' as fs;

/// The full screen button (like YouTube's), for the web version on phones and
/// computers. Hidden where it cannot work; on iPhone Safari it explains that
/// "Add to Home Screen" opens the game full screen.
class FullscreenButton extends StatefulWidget {
  const FullscreenButton({super.key, this.size = 26});

  final double size;

  @override
  State<FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<FullscreenButton> {
  Timer? _poll;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _on = fs.fullscreenOn();
    // Esc or the browser can leave full screen too: keep the icon right.
    if (fs.fullscreenSupported()) {
      _poll = Timer.periodic(const Duration(milliseconds: 700), (_) {
        final on = fs.fullscreenOn();
        if (on != _on && mounted) setState(() => _on = on);
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    if (fs.fullscreenSupported()) {
      return IconButton(
        tooltip: _on ? s.exitFullscreen : s.fullscreen,
        iconSize: widget.size,
        icon: Icon(_on ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
        onPressed: () {
          fs.fullscreenToggle();
          Future<void>.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _on = fs.fullscreenOn());
          });
        },
      );
    }
    if (fs.fullscreenNeedsHomeScreen()) {
      return IconButton(
        tooltip: s.fullscreen,
        iconSize: widget.size,
        icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
        onPressed: () => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.fullscreenIos), duration: const Duration(seconds: 6))),
      );
    }
    return const SizedBox.shrink();
  }
}
