import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import 'pressable.dart';

enum TicketTab { today, history }

const ticketBottomBarHeight = 112.0;

class TicketBottomBar extends StatelessWidget {
  const TicketBottomBar({
    required this.selectedTab,
    required this.onToday,
    required this.onRecord,
    required this.onHistory,
    this.recordEnabled = true,
    super.key,
  });

  final TicketTab selectedTab;
  final VoidCallback onToday;
  final VoidCallback onRecord;
  final VoidCallback onHistory;
  final bool recordEnabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: ticketBottomBarHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            const Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Divider(height: 1, thickness: 1, color: AppColors.rule),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 76,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: _NavItem(
                      label: '今天',
                      icon: 'assets/icons/ic_ticket_calendar.svg',
                      selected: selectedTab == TicketTab.today,
                      onPressed: onToday,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Expanded(
                    child: _NavItem(
                      label: '历史',
                      icon: 'assets/icons/ic_ticket_history.svg',
                      selected: selectedTab == TicketTab.history,
                      onPressed: onHistory,
                    ),
                  ),
                ],
              ),
            ),
            _RecordAction(onPressed: onRecord, enabled: recordEnabled),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.mossInk : AppColors.inkMuted;
    return Pressable(
      semanticLabel: label,
      selected: selected,
      onPressed: onPressed,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset(
              icon,
              width: 27,
              height: 27,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 16 / 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordAction extends StatefulWidget {
  const _RecordAction({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_RecordAction> createState() => _RecordActionState();
}

class _RecordActionState extends State<_RecordAction> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 80);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '记录一次',
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
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed();
                }
              : null,
          onTapCancel: widget.enabled
              ? () => setState(() => _pressed = false)
              : null,
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1 : 0.55,
            duration: duration,
            child: SizedBox(
              width: 92,
              height: 108,
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        Positioned(
                          left: 7,
                          top: 5,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              color: AppColors.shadow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: AnimatedSlide(
                            duration: duration,
                            curve: Curves.easeOut,
                            offset: Offset(0, _pressed ? 3 / 76 : 0),
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: _pressed
                                    ? AppColors.mustardPressed
                                    : AppColors.mustard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _focused
                                      ? AppColors.moss
                                      : AppColors.ink,
                                  width: _focused ? 4 : 3,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/toilet.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '记录',
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
