// Hallmark · playful · locked LaLeMa · monthly calendar with daily records
// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../domain/bowel_record.dart';
import '../domain/bristol_type.dart';
import '../widgets/calendar_button.dart';
import '../widgets/pressable.dart';
import '../widgets/record_details_preview.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.controller,
    required this.initialDate,
    required this.onBackfill,
    required this.onEdit,
    super.key,
  });

  final BowelLogController controller;
  final DateTime initialDate;
  final Future<DateTime?> Function(DateTime) onBackfill;
  final Future<DateTime?> Function(String) onEdit;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;
  late DateTime _month;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final today = dateOnly(widget.controller.now);
    _selected = dateOnly(widget.initialDate);
    if (_selected.isAfter(today)) _selected = today;
    if (_selected.isBefore(DateTime(1900))) _selected = DateTime(1900);
    _month = DateTime(_selected.year, _selected.month);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(DateTime date, {bool scrollToTop = false}) {
    final today = dateOnly(widget.controller.now);
    final next = dateOnly(date);
    if (next.isAfter(today) || next.isBefore(DateTime(1900))) return;
    widget.controller.clearFeedback();
    setState(() {
      _selected = next;
      _month = DateTime(next.year, next.month);
    });
    if (scrollToTop && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setMonth(DateTime month) {
    final today = dateOnly(widget.controller.now);
    final last = DateTime(month.year, month.month + 1, 0).day;
    var day = math.min(_selected.day, last);
    if (month.year == today.year && month.month == today.month) {
      day = math.min(day, today.day);
    }
    _select(DateTime(month.year, month.month, day));
  }

  Future<void> _pickMonth() async {
    final today = dateOnly(widget.controller.now);
    var year = _month.year;
    var month = _month.month;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('选择月份', style: pixelStyle(size: 22)),
          content: SizedBox(
            width: 280,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    key: const Key('calendar-year-picker'),
                    value: year,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    items: [
                      for (var y = today.year; y >= 1900; y--)
                        DropdownMenuItem(value: y, child: Text('$y年')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      update(() {
                        year = value;
                        if (year == today.year) {
                          month = math.min(month, today.month);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    key: const Key('calendar-month-picker'),
                    value: month,
                    isExpanded: true,
                    menuMaxHeight: 320,
                    items: [
                      for (
                        var m = 1;
                        m <= (year == today.year ? today.month : 12);
                        m++
                      )
                        DropdownMenuItem(value: m, child: Text('$m月')),
                    ],
                    onChanged: (value) {
                      if (value != null) update(() => month = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, DateTime(year, month)),
              child: const Text('查看'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _setMonth(picked);
  }

  Future<void> _backfill() async {
    final savedDate = await widget.onBackfill(_selected);
    if (savedDate != null && mounted) {
      // Preserve the save feedback while selecting the saved day.
      setState(() {
        _selected = dateOnly(savedDate);
        _month = DateTime(savedDate.year, savedDate.month);
      });
    }
  }

  Future<void> _edit(String id) async {
    final savedDate = await widget.onEdit(id);
    if (savedDate != null && mounted) {
      setState(() {
        _selected = dateOnly(savedDate);
        _month = DateTime(savedDate.year, savedDate.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final controller = widget.controller;
                final today = dateOnly(controller.now);
                final records = controller.recordsForDate(_selected);
                final counts = <DateTime, int>{};
                for (final record in controller.records) {
                  final date = dateOnly(record.recordedAt);
                  counts.update(date, (count) => count + 1, ifAbsent: () => 1);
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: '返回',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: SvgPicture.asset(
                              'assets/icons/ic_ticket_back.svg',
                              width: 26,
                              height: 26,
                            ),
                          ),
                          Expanded(
                            child: Text('排便日历', style: pixelStyle(size: 26)),
                          ),
                          CalendarButton(
                            key: const Key('calendar-today'),
                            returnToToday: true,
                            active: !isSameDate(_selected, today),
                            onPressed: () => _select(today, scrollToTop: true),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 28),
                        children:
                            <Widget>[
                                  Row(
                                    children: [
                                      _MonthArrow(
                                        key: const Key('calendar-prev'),
                                        label: '上个月',
                                        enabled: _month.isAfter(DateTime(1900)),
                                        onPressed: () => _setMonth(
                                          DateTime(
                                            _month.year,
                                            _month.month - 1,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Pressable(
                                          key: const Key(
                                            'calendar-month-title',
                                          ),
                                          semanticLabel:
                                              '${_month.year}年${_month.month}月，选择年月',
                                          onPressed: _pickMonth,
                                          child: SizedBox(
                                            height: 56,
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${_month.year}年${_month.month}月',
                                                      style: pixelStyle(
                                                        size: 23,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ExcludeSemantics(
                                                      child: RotatedBox(
                                                        quarterTurns: 3,
                                                        child: SvgPicture.asset(
                                                          'assets/icons/ic_ticket_back.svg',
                                                          width: 12,
                                                          height: 12,
                                                          colorFilter:
                                                              const ColorFilter.mode(
                                                                AppColors
                                                                    .mossInk,
                                                                BlendMode.srcIn,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _MonthArrow(
                                        key: const Key('calendar-next'),
                                        label: '下个月',
                                        next: true,
                                        enabled: _month.isBefore(
                                          DateTime(today.year, today.month),
                                        ),
                                        onPressed: () => _setMonth(
                                          DateTime(
                                            _month.year,
                                            _month.month + 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // The grid keeps full touch targets within the scroll view.
                                  _MonthGrid(
                                    month: _month,
                                    selected: _selected,
                                    today: today,
                                    counts: counts,
                                    onSelect: _select,
                                  ),
                                  const SizedBox(height: 16),
                                  const Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      Text(
                                        '▪ 有记录',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mossInk,
                                        ),
                                      ),
                                      Text(
                                        '— 今天',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.mossInk,
                                        ),
                                      ),
                                      Text(
                                        '空白表示未记录',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  const Divider(
                                    height: 1,
                                    color: AppColors.rule,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          formatHistoryDate(_selected),
                                          key: const Key(
                                            'calendar-selected-date',
                                          ),
                                          style: pixelStyle(
                                            size: 18,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      Pressable(
                                        key: const Key('calendar-backfill'),
                                        semanticLabel:
                                            '补记${formatHistoryDate(_selected)}',
                                        enabled:
                                            !controller.isWorking &&
                                            !controller.isLoading,
                                        onPressed: _backfill,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 16,
                                          ),
                                          child: Text(
                                            '＋补记',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.mossInk,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (controller.errorMessage != null ||
                                      controller.feedbackMessage != null)
                                    Semantics(
                                      liveRegion: true,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          controller.errorMessage ??
                                              controller.feedbackMessage!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                controller.errorMessage == null
                                                ? AppColors.mossInk
                                                : AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (controller.isLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('正在读取记录…'),
                                    )
                                  else if (records.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 28,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '这一天还没有记录',
                                            style: pixelStyle(size: 16),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            '忘记记下？可以在这里补一笔。',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.inkMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          OutlinedButton(
                                            onPressed: controller.isWorking
                                                ? null
                                                : _backfill,
                                            child: const Text('补记这一天'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    for (final record in records)
                                      _CalendarRecord(
                                        record: record,
                                        enabled: !controller.isWorking,
                                        onEdit: () => _edit(record.recordId),
                                      ),
                                ]
                                .map(
                                  (child) => child is _MonthGrid
                                      ? child
                                      : Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: child,
                                        ),
                                )
                                .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.next = false,
    super.key,
  });
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool next;

  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: label,
    enabled: enabled,
    onPressed: onPressed,
    child: SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Text(
          next ? '›' : '‹',
          style: const TextStyle(fontSize: 28, color: AppColors.mossInk),
        ),
      ),
    ),
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight = math.max(52.0, scaler.scale(16) + scaler.scale(11) + 16);
    return Column(
      children: [
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: rowHeight,
          ),
          itemBuilder: (context, index) {
            final day = index - offset + 1;
            if (day < 1 || day > lastDay) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final count = counts[date] ?? 0;
            final isToday = isSameDate(date, today);
            final isSelected = isSameDate(date, selected);
            final future = date.isAfter(today);
            return Pressable(
              key: ValueKey('calendar-day-${date.toIso8601String()}'),
              semanticLabel:
                  '${formatHistoryDate(date)}${isToday ? '，今天' : ''}，${future
                      ? '未来日期'
                      : count == 0
                      ? '未记录'
                      : '$count 次记录'}',
              selected: isSelected,
              enabled: !future,
              onPressed: () => onSelect(date),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.mossPale : null,
                      border: Border.all(
                        color: isSelected ? AppColors.moss : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                color: future ? AppColors.rule : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                          width: 12,
                          child: ColoredBox(
                            color: isToday
                                ? AppColors.moss
                                : Colors.transparent,
                          ),
                        ),
                        SizedBox(
                          height: scaler.scale(11) + 2,
                          child: count > 1
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$count次',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: AppColors.mossInk,
                                    ),
                                  ),
                                )
                              : count == 1
                              ? const Center(
                                  child: SizedBox(
                                    width: 4,
                                    height: 4,
                                    child: ColoredBox(color: AppColors.moss),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CalendarRecord extends StatelessWidget {
  const _CalendarRecord({
    required this.record,
    required this.onEdit,
    required this.enabled,
  });
  final BowelRecord record;
  final VoidCallback onEdit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final type = bristolTypeFor(record.bristolType)!;
    return Column(
      children: [
        Pressable(
          semanticLabel: '${formatTime(record.recordedAt)}，${type.label}，修改记录',
          enabled: enabled,
          onPressed: onEdit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    formatTime(record.recordedAt),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  SvgPicture.asset(type.assetPath, width: 36, height: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.code,
                          style: pixelStyle(size: 16, color: AppColors.mossInk),
                        ),
                        Text(type.label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '修改',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!record.details.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              semanticLabel: '查看和修改记录细节',
              enabled: enabled,
              onPressed: onEdit,
              child: RecordDetailsPreview(details: record.details),
            ),
          ),
        const Divider(height: 1, color: AppColors.rule),
      ],
    );
  }
}
