import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/privacy_services.dart';

/// Also wraps startup/error UI, so a native cover can be released after a safe
/// Flutter frame even if preferences or the database failed to open.
class PrivacySurface extends StatefulWidget {
  const PrivacySurface({required this.screen, required this.child, super.key});
  final PrivacyScreenBridge screen;
  final Widget child;
  @override
  State<PrivacySurface> createState() => _PrivacySurfaceState();
}

class _PrivacySurfaceState extends State<PrivacySurface>
    with WidgetsBindingObserver {
  bool _obscured = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _obscured =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) !=
        AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_obscured) _revealAfterSafeFrame();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _obscured = state != AppLifecycleState.resumed;
      _generation++;
    });
    if (!_obscured) _revealAfterSafeFrame();
  }

  Future<void> _revealAfterSafeFrame() async {
    final generation = _generation;
    try {
      final epoch = await widget.screen.foregroundEpoch();
      if (!mounted || _obscured || generation != _generation || epoch == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_obscured && generation == _generation) {
          unawaited(widget.screen.frameReady(epoch).catchError((Object _) {}));
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    } catch (_) {
      /* A failed native acknowledgement leaves its cover in place. */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _obscured,
            child: ExcludeFocus(excluding: _obscured, child: widget.child),
          ),
          if (_obscured) const ColoredBox(color: AppColors.paper),
        ],
      ),
    );
  }
}
