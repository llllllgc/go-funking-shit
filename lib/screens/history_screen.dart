// Hallmark · genre: playful · macrostructure: chronological-ticket · design-system: locked LaLeMa
// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../domain/bowel_record.dart';
import '../domain/bristol_type.dart';
import '../widgets/pressable.dart';
import '../widgets/calendar_button.dart';
import '../widgets/ticket_bottom_bar.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    required this.controller,
    required this.onToday,
    required this.onRecord,
    required this.onEdit,
    required this.onCalendar,
    required this.onBackfill,
    super.key,
  });

  final BowelLogController controller;
  final VoidCallback onToday;
  final VoidCallback onRecord;
  final ValueChanged<String> onEdit;
  final VoidCallback onCalendar;
  final VoidCallback onBackfill;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  bottom: ticketBottomBarHeight,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    children: <Widget>[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '历史',
                              style: pixelStyle(size: 30, height: 38 / 30),
                            ),
                          ),
                          CalendarButton(onPressed: onCalendar),
                          Pressable(
                            key: const Key('history-backfill'),
                            semanticLabel: '补记过去的记录',
                            enabled:
                                !controller.isWorking && !controller.isLoading,
                            onPressed: onBackfill,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                              child: Text(
                                '＋补记',
                                style: TextStyle(
                                  color: AppColors.mossInk,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom:
                              controller.feedbackMessage == null &&
                                  controller.errorMessage == null
                              ? 28
                              : 8,
                        ),
                        child: Text(
                          controller.isLoading
                              ? '正在读取'
                              : '共 ${controller.records.length} 笔记录',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (controller.errorMessage != null ||
                          controller.feedbackMessage != null)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              controller.errorMessage ??
                                  controller.feedbackMessage!,
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
                      if (!controller.isLoading && controller.records.isEmpty)
                        const _EmptyHistory(),
                      for (final group in _groupRecords(
                        controller.records,
                      )) ...[
                        _HistoryDayHeader(group: group),
                        for (final record in group.records)
                          _HistoryRecordRow(
                            record: record,
                            enabled: !controller.isWorking,
                            onEdit: () => onEdit(record.recordId),
                            onDelete: () => _confirmDelete(context, record),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TicketBottomBar(
                    selectedTab: TicketTab.history,
                    onToday: onToday,
                    onRecord: onRecord,
                    onHistory: () {},
                    recordEnabled: !controller.isWorking,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, BowelRecord record) async {
    controller.clearFeedback();
    final type = bristolTypeFor(record.bristolType);
    if (type == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.34),
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          title: Text('删除这条记录？', style: pixelStyle(size: 20, height: 26 / 20)),
          content: Text(
            '${formatDeleteDate(record.recordedAt)} · ${type.code} ${type.label}\n删除后无法恢复。',
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _DialogAction(
                    label: '取消',
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogAction(
                    label: '删除',
                    danger: true,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (confirmed == true) await controller.deleteRecord(record.recordId);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Column(
        children: <Widget>[
          SvgPicture.asset(
            'assets/icons/ic_ticket_history.svg',
            width: 58,
            height: 58,
            colorFilter: const ColorFilter.mode(AppColors.ink, BlendMode.srcIn),
          ),
          const SizedBox(height: 20),
          Text('还没有记录', style: pixelStyle(size: 16, height: 22 / 16)),
          const SizedBox(height: 8),
          const Text(
            '点中间的马桶，记下第一次',
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryGroup {
  const _HistoryGroup(this.date, this.records);

  final DateTime date;
  final List<BowelRecord> records;
}

List<_HistoryGroup> _groupRecords(List<BowelRecord> records) {
  final groups = <DateTime, List<BowelRecord>>{};
  for (final record in records) {
    groups
        .putIfAbsent(dateOnly(record.recordedAt), () => <BowelRecord>[])
        .add(record);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return entries
      .map((entry) => _HistoryGroup(entry.key, entry.value))
      .toList(growable: false);
}

class _HistoryDayHeader extends StatelessWidget {
  const _HistoryDayHeader({required this.group});

  final _HistoryGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              formatHistoryDate(group.date),
              style: pixelStyle(size: 18, height: 24 / 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${group.records.length} 次',
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRecordRow extends StatelessWidget {
  const _HistoryRecordRow({
    required this.record,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final BowelRecord record;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = bristolTypeFor(record.bristolType);
    if (type == null) return const SizedBox.shrink();
    return Column(
      children: <Widget>[
        SizedBox(
          height: 76,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Pressable(
                  semanticLabel:
                      '${formatTime(record.recordedAt)}，${type.code}，${type.label}，修改',
                  enabled: enabled,
                  onPressed: onEdit,
                  child: SizedBox(
                    height: 76,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 48,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatTime(record.recordedAt),
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SvgPicture.asset(type.assetPath, width: 48, height: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                type.code,
                                maxLines: 1,
                                style: pixelStyle(
                                  size: 16,
                                  height: 20 / 16,
                                  color: AppColors.mossInk,
                                ),
                              ),
                              Text(
                                type.label,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 14,
                                  height: 20 / 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/icons/ic_ticket_edit.svg',
                          width: 21,
                          height: 21,
                          colorFilter: const ColorFilter.mode(
                            AppColors.inkMuted,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
              Pressable(
                semanticLabel: '删除这条记录',
                enabled: enabled,
                onPressed: onDelete,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/ic_ticket_delete.svg',
                      width: 21,
                      height: 21,
                      colorFilter: const ColorFilter.mode(
                        AppColors.danger,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.rule.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onPressed: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: danger ? AppColors.danger : AppColors.paper,
          border: Border.all(color: AppColors.ink),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: danger ? AppColors.paperRaised : AppColors.ink,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
