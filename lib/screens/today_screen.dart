// Hallmark · genre: playful · macrostructure: status-ticket · design-system: locked LaLeMa
// Hallmark · pre-emit critique: P5 H4 E4 S5 R5 V4
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/knowledge_base.dart';
import '../domain/bowel_record.dart';
import '../domain/bristol_type.dart';
import '../widgets/pressable.dart';
import '../widgets/calendar_button.dart';
import '../widgets/knowledge_preview_card.dart';
import '../widgets/ticket_bottom_bar.dart';
import '../widgets/undo_snackbar.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    required this.controller,
    required this.onRecord,
    required this.onHistory,
    required this.onEdit,
    required this.onCalendar,
    required this.onKnowledge,
    required this.onSettings,
    super.key,
  });

  final BowelLogController controller;
  final VoidCallback onRecord;
  final VoidCallback onHistory;
  final ValueChanged<String> onEdit;
  final ValueChanged<DateTime> onCalendar;
  final VoidCallback onKnowledge;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.paper,
        bottomNavigationBar: TicketBottomBar(
          selectedTab: TicketTab.today,
          onToday: () {},
          onRecord: onRecord,
          onHistory: onHistory,
          recordEnabled: !controller.isWorking && !controller.isLoading,
        ),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 350;
              final compact = constraints.maxHeight < 668 || narrow;
              final padding = narrow ? 20.0 : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 12 : 20,
                  padding,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SizedBox(
                      width: double.infinity,
                      child: _TodayContent(
                        controller: controller,
                        narrow: narrow,
                        compact: compact,
                        onEdit: onEdit,
                        onCalendar: onCalendar,
                        onKnowledge: onKnowledge,
                        onSettings: onSettings,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.controller,
    required this.narrow,
    required this.compact,
    required this.onEdit,
    required this.onCalendar,
    required this.onKnowledge,
    required this.onSettings,
  });

  final BowelLogController controller;
  final bool narrow;
  final bool compact;
  final ValueChanged<String> onEdit;
  final ValueChanged<DateTime> onCalendar;
  final VoidCallback onKnowledge;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestTodayRecord;
    final recent = controller.records.isEmpty ? null : controller.records.first;
    final status = controller.errorMessage ?? controller.feedbackMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: [
            const Expanded(child: _Wordmark()),
            IconButton(
              key: const Key('today-settings'),
              tooltip: '设置与隐私',
              onPressed: onSettings,
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.mossInk,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 28 : 56),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '今天',
            style: pixelStyle(size: compact ? 28 : 34, height: 1.18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    controller.isLoading
                        ? '—'
                        : controller.todayRecordCount.toString(),
                    style: pixelStyle(
                      size: compact ? 88 : 112,
                      height: compact ? 96 / 88 : 120 / 112,
                      color: AppColors.moss,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 12, bottom: compact ? 8 : 12),
                child: Text(
                  '次',
                  style: pixelStyle(size: compact ? 32 : 40, height: 1.25),
                ),
              ),
              SizedBox(width: narrow ? 16 : 32),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final preferredSize = narrow ? 100.0 : 136.0;
                      final size = math.min(
                        preferredSize,
                        math.max(0.0, constraints.maxWidth - 2),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 2, bottom: 2),
                        child: Image.asset(
                          _spiritAsset(controller),
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          excludeFromSemantics: true,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        _LatestRecordLine(record: latest, stacked: narrow),
        if (latest != null || recent != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 20,
              runSpacing: 2,
              children: <Widget>[
                if (latest != null)
                  _InlineAction(
                    label: '修改',
                    icon: 'assets/icons/ic_ticket_edit.svg',
                    enabled: !controller.isWorking,
                    onPressed: () => onEdit(latest.recordId),
                  ),
                if (latest != null)
                  _InlineAction(
                    label: '删除',
                    icon: 'assets/icons/ic_ticket_undo.svg',
                    enabled: !controller.isWorking,
                    onPressed: () async {
                      final deleted = await controller.deleteRecord(
                        latest.recordId,
                      );
                      if (deleted != null && context.mounted) {
                        showRecordUndoSnackBar(context, controller, deleted);
                      }
                    },
                  ),
                if (recent != null)
                  _InlineAction(
                    label: '按上次形态记录 ${recent.bristolType}型',
                    icon: 'assets/icons/ic_ticket_note.svg',
                    enabled: !controller.isWorking,
                    onPressed: () => _repeatLatest(context, recent),
                  ),
              ],
            ),
          ),
        if (status != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                status,
                style: TextStyle(
                  color: controller.errorMessage != null
                      ? AppColors.danger
                      : AppColors.mossInk,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ),
        SizedBox(height: compact ? 20 : 28),
        KnowledgePreviewCard(
          // The knowledge card should stay useful on days without a new
          // entry. Records are kept newest-first by the controller, so use
          // the latest entry across the whole log rather than today's entry.
          tip: KnowledgeBase.featuredFor(
            controller.records.isEmpty
                ? null
                : controller.records.first.bristolType,
          ),
          onPressed: onKnowledge,
        ),
        SizedBox(height: compact ? 24 : 40),
        const Divider(height: 1, thickness: 1, color: AppColors.rule),
        SizedBox(height: compact ? 20 : 32),
        _SevenDayTicket(
          days: controller.lastSevenDays,
          today: controller.currentDate,
          onCalendar: onCalendar,
        ),
        const SizedBox(height: 16),
        _TrendInsight(
          records: controller.records,
          today: controller.currentDate,
        ),
        SizedBox(height: compact ? 24 : 36),
        const SizedBox(
          width: double.infinity,
          child: Text(
            '点一下，记一笔',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  String _spiritAsset(BowelLogController controller) {
    if (controller.isLoading) {
      return 'assets/images/toilet_paper_spirit_normal.png';
    }
    return 'assets/images/toilet_paper_spirit_normal.png';
  }

  Future<void> _repeatLatest(BuildContext context, BowelRecord record) async {
    final type = bristolTypeFor(record.bristolType);
    final saved = await controller.saveType(record.bristolType);
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已按 ${type?.number ?? record.bristolType}型记录当前时间'),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

class _TrendInsight extends StatefulWidget {
  const _TrendInsight({required this.records, required this.today});

  final List<BowelRecord> records;
  final DateTime today;

  @override
  State<_TrendInsight> createState() => _TrendInsightState();
}

class _TrendInsightState extends State<_TrendInsight> {
  int _windowDays = 7;

  @override
  Widget build(BuildContext context) {
    final start = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day - _windowDays + 1,
    );
    final records = widget.records
        .where((record) {
          final date = dateOnly(record.recordedAt);
          return !date.isBefore(start) && !date.isAfter(widget.today);
        })
        .toList(growable: false);
    final activeDates = <DateTime>{
      for (final record in records) dateOnly(record.recordedAt),
    };
    final total = records.length;
    final average = total == 0 ? '—' : (total / _windowDays).toStringAsFixed(1);
    final distribution = List<int>.filled(bristolTypes.length, 0);
    for (final record in records) {
      if (record.bristolType >= 1 &&
          record.bristolType <= bristolTypes.length) {
        distribution[record.bristolType - 1]++;
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        border: Border.all(color: AppColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('记录观察', style: pixelStyle(size: 18, height: 1.3)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _TrendWindowButton(
                    label: '7天',
                    selected: _windowDays == 7,
                    onPressed: () => setState(() => _windowDays = 7),
                  ),
                  const SizedBox(width: 6),
                  _TrendWindowButton(
                    label: '30天',
                    selected: _windowDays == 30,
                    onPressed: () => setState(() => _windowDays = 30),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '近$_windowDays天 · 仅回顾已记录的内容',
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _InsightMetric(
                  label: '有记录的天数',
                  value: '${activeDates.length}/$_windowDays',
                ),
              ),
              Expanded(
                child: _InsightMetric(label: '记录总数', value: '$total'),
              ),
              Expanded(
                child: _InsightMetric(label: '日均记录数', value: average),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Bristol 分布',
            style: pixelStyle(size: 14, height: 1.3, color: AppColors.mossInk),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (var index = 0; index < distribution.length; index++)
                _DistributionChip(
                  code: bristolTypes[index].code,
                  count: distribution[index],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? '还没有记录。未记录不表示没有排便。'
                : total < 3
                ? '记录较少，仅供回顾。未记录不表示没有排便。'
                : '日均记录数＝记录总数 ÷ $_windowDays 天（含今天）。未记录不表示没有排便。',
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendWindowButton extends StatelessWidget {
  const _TrendWindowButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: '查看$label趋势',
      selected: selected,
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mossPale : AppColors.paper,
          border: Border.all(color: selected ? AppColors.moss : AppColors.rule),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.mossInk : AppColors.inkMuted,
            fontSize: 12,
            height: 1.4,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _DistributionChip extends StatelessWidget {
  const _DistributionChip({required this.code, required this.count});

  final String code;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: count > 0 ? AppColors.mossPale : AppColors.paper,
        border: Border.all(color: count > 0 ? AppColors.moss : AppColors.rule),
      ),
      child: Text(
        '$code型 · $count笔',
        style: TextStyle(
          color: count > 0 ? AppColors.mossInk : AppColors.inkMuted,
          fontSize: 11,
          height: 1.4,
          fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: pixelStyle(
            size: 16,
            height: 22 / 16,
            color: AppColors.mossInk,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.inkMuted,
            fontSize: 11,
            height: 16 / 11,
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          const TextSpan(text: '拉了么'),
          TextSpan(
            text: '？',
            style: pixelStyle(size: 40, height: 1.2, color: AppColors.moss),
          ),
        ],
      ),
      style: pixelStyle(size: 40, height: 1.2),
    );
  }
}

class _LatestRecordLine extends StatelessWidget {
  const _LatestRecordLine({required this.record, required this.stacked});

  final BowelRecord? record;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final type = record == null ? null : bristolTypeFor(record!.bristolType);
    final text = record == null || type == null
        ? '最近一次　—'
        : stacked
        ? '最近一次\n${formatTime(record!.recordedAt)} · ${type.code}　${type.label}'
        : '最近一次　${formatTime(record!.recordedAt)} · ${type.code}　${type.label}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.ink, fontSize: 16, height: 1.5),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.inkMuted : AppColors.rule;
    return Pressable(
      semanticLabel: label,
      enabled: enabled,
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: 4),
            SvgPicture.asset(
              icon,
              width: 19,
              height: 19,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _SevenDayTicket extends StatelessWidget {
  const _SevenDayTicket({
    required this.days,
    required this.today,
    required this.onCalendar,
  });

  final List<LogDaySummary> days;
  final DateTime today;
  final ValueChanged<DateTime> onCalendar;

  @override
  Widget build(BuildContext context) {
    final total = days.fold<int>(0, (sum, day) => sum + day.recordCount);
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text('近 7 天', style: pixelStyle(size: 20, height: 1.3)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '共 $total 次',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                CalendarButton(onPressed: () => onCalendar(today)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: days
              .map(
                (day) => Expanded(
                  child: Pressable(
                    key: ValueKey('week-day-${day.date.toIso8601String()}'),
                    semanticLabel: '${formatHistoryDate(day.date)}，查看这一天的记录',
                    onPressed: () => onCalendar(day.date),
                    child: _DayMark(
                      day: day,
                      isToday: isSameDate(day.date, today),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({required this.day, required this.isToday});

  final LogDaySummary day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final label = weekdayLabels[day.date.weekday - 1];
    return Semantics(
      label:
          '${formatHistoryDate(day.date)}${isToday ? '，今天' : ''}，${day.recordCount} 次记录',
      child: ExcludeSemantics(
        child: Column(
          children: <Widget>[
            Text(
              isToday ? '今' : label,
              style: TextStyle(
                color: isToday ? AppColors.mossInk : AppColors.ink,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            CustomPaint(
              size: const Size(28, 44),
              painter: _PaperRollDayPainter(
                hasRecord: day.hasRecord,
                isToday: isToday,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              day.hasRecord ? '${day.recordCount}次' : '—',
              maxLines: 1,
              style: TextStyle(
                color: day.hasRecord ? AppColors.mossInk : AppColors.inkMuted,
                fontSize: 12,
                height: 1.5,
                fontWeight: day.hasRecord ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fine pixel steps preserve the elliptical rim and rounded cylinder silhouette.
class _PaperRollDayPainter extends CustomPainter {
  const _PaperRollDayPainter({required this.hasRecord, required this.isToday});

  final bool hasRecord;
  final bool isToday;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 36, size.height / 44);
    final outline = Paint()
      ..color = hasRecord ? AppColors.moss : AppColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = false;
    final cream = Paint()
      ..color = AppColors.paperRaised
      ..isAntiAlias = false;
    final accent = Paint()
      ..color = AppColors.mossPale
      ..isAntiAlias = false;

    if (hasRecord) {
      final sheet = Path()
        ..moveTo(24, 17)
        ..lineTo(30, 17)
        ..lineTo(30, 19)
        ..lineTo(32, 19)
        ..lineTo(32, 21)
        ..lineTo(34, 21)
        ..lineTo(34, 40)
        ..lineTo(30, 40)
        ..lineTo(30, 41)
        ..lineTo(26, 41)
        ..lineTo(26, 39)
        ..lineTo(22, 39)
        ..lineTo(22, 28)
        ..close();
      canvas.drawPath(sheet, cream);
      canvas.drawPath(sheet, outline);
      canvas.drawRect(const Rect.fromLTWH(31, 24, 2, 12), accent);
    }

    final body = Path()
      ..moveTo(4, 15)
      ..lineTo(4, 31)
      ..lineTo(6, 31)
      ..lineTo(6, 33)
      ..lineTo(10, 33)
      ..lineTo(10, 35)
      ..lineTo(24, 35)
      ..lineTo(24, 33)
      ..lineTo(28, 33)
      ..lineTo(28, 31)
      ..lineTo(30, 31)
      ..lineTo(30, 15)
      ..close();
    canvas.drawPath(body, cream);
    if (hasRecord) {
      final side = Path()
        ..moveTo(26, 18)
        ..lineTo(29, 18)
        ..lineTo(29, 30)
        ..lineTo(27, 30)
        ..lineTo(27, 32)
        ..lineTo(23, 32)
        ..lineTo(23, 34)
        ..lineTo(21, 34)
        ..lineTo(21, 32)
        ..lineTo(24, 32)
        ..lineTo(24, 30)
        ..lineTo(26, 30)
        ..close();
      canvas.drawPath(side, accent);
    }
    canvas.drawPath(body, outline);
    final rim = Path()
      ..moveTo(10, 9)
      ..lineTo(24, 9)
      ..lineTo(24, 11)
      ..lineTo(28, 11)
      ..lineTo(28, 13)
      ..lineTo(30, 13)
      ..lineTo(30, 17)
      ..lineTo(28, 17)
      ..lineTo(28, 19)
      ..lineTo(24, 19)
      ..lineTo(24, 21)
      ..lineTo(10, 21)
      ..lineTo(10, 19)
      ..lineTo(6, 19)
      ..lineTo(6, 17)
      ..lineTo(4, 17)
      ..lineTo(4, 13)
      ..lineTo(6, 13)
      ..lineTo(6, 11)
      ..lineTo(10, 11)
      ..close();
    canvas.drawPath(rim, cream);
    canvas.drawPath(rim, outline);
    final core = Path()
      ..moveTo(14, 13)
      ..lineTo(20, 13)
      ..lineTo(20, 14)
      ..lineTo(22, 14)
      ..lineTo(22, 16)
      ..lineTo(20, 16)
      ..lineTo(20, 17)
      ..lineTo(14, 17)
      ..lineTo(14, 16)
      ..lineTo(12, 16)
      ..lineTo(12, 14)
      ..lineTo(14, 14)
      ..close();
    canvas.drawPath(
      core,
      Paint()
        ..color = hasRecord ? AppColors.mossPale : AppColors.paper
        ..isAntiAlias = false,
    );
    canvas.drawPath(
      core,
      Paint()
        ..color = outline.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.miter
        ..isAntiAlias = false,
    );

    final face = Paint()
      ..color = hasRecord ? AppColors.mossInk : AppColors.inkMuted
      ..isAntiAlias = false;
    canvas.drawRect(const Rect.fromLTWH(11, 25, 2, 3), face);
    canvas.drawRect(const Rect.fromLTWH(21, 25, 2, 3), face);
    canvas.drawRect(const Rect.fromLTWH(14, 29, 1, 1), face);
    canvas.drawRect(const Rect.fromLTWH(15, 30, 4, 1), face);
    canvas.drawRect(const Rect.fromLTWH(19, 29, 1, 1), face);

    if (isToday) {
      final leaf = Paint()
        ..color = AppColors.moss
        ..isAntiAlias = false;
      canvas.drawRect(const Rect.fromLTWH(22, 6, 2, 4), leaf);
      canvas.drawRect(const Rect.fromLTWH(24, 4, 4, 4), leaf);
      canvas.drawRect(const Rect.fromLTWH(26, 2, 4, 4), leaf);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperRollDayPainter oldDelegate) =>
      oldDelegate.hasRecord != hasRecord || oldDelegate.isToday != isToday;
}
