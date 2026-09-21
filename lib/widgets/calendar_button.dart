import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'pressable.dart';

class CalendarButton extends StatelessWidget {
  const CalendarButton({
    required this.onPressed,
    this.returnToToday = false,
    this.active = true,
    super.key,
  });

  final VoidCallback onPressed;
  final bool returnToToday;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final label = returnToToday ? '回到今天' : '查看月历';
    final color = active ? AppColors.mossInk : AppColors.rule;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Pressable(
        semanticLabel: label,
        onPressed: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: ExcludeSemantics(
              child: SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  children: [
                    SvgPicture.asset(
                      returnToToday
                          ? 'assets/icons/ic_ticket_today.svg'
                          : 'assets/icons/ic_ticket_calendar.svg',
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                    if (returnToToday)
                      Positioned(
                        top: 11,
                        left: 0,
                        right: 0,
                        child: Text(
                          '今',
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                          style: pixelStyle(size: 13, height: 1, color: color),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
