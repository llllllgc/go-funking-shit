import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.enabled = true,
    this.selected,
    this.pressOffset = 2,
    this.focusBorderRadius = BorderRadius.zero,
    super.key,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool enabled;
  final bool? selected;
  final double pressOffset;
  final BorderRadius focusBorderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 80);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
          onTapUp: widget.enabled
              ? (_) {
                  _setPressed(false);
                  widget.onPressed();
                }
              : null,
          onTapCancel: widget.enabled ? () => _setPressed(false) : null,
          child: AnimatedSlide(
            offset: Offset(0, _pressed ? widget.pressOffset / 48 : 0),
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: widget.enabled ? 1 : 0.55,
              duration: duration,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.focusBorderRadius,
                  border: _focused
                      ? Border.all(color: AppColors.moss, width: 2)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
