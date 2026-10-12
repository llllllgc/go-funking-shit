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
import '../domain/history_filter.dart';
import '../widgets/pressable.dart';
import '../widgets/calendar_button.dart';
import '../widgets/ticket_bottom_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.controller,
    required this.onToday,
    required this.onRecord,
    required this.onEdit,
    required this.onCalendar,
    required this.onBackfill,
    this.initialFilter = const HistoryFilter(),
    this.onFilterChanged,
    super.key,
  });

  final BowelLogController controller;
  final VoidCallback onToday;
  final VoidCallback onRecord;
  final ValueChanged<String> onEdit;
  final VoidCallback onCalendar;
  final VoidCallback onBackfill;
  final HistoryFilter initialFilter;
  final ValueChanged<HistoryFilter>? onFilterChanged;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late HistoryFilter _filter;
  late final TextEditingController _search;

  BowelLogController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _search = TextEditingController(text: _filter.search);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(HistoryFilter value) {
    setState(() => _filter = value);
    widget.onFilterChanged?.call(value);
  }

  void _clearFilter() {
    _search.clear();
    _setFilter(const HistoryFilter());
  }

  Future<void> _pickRange() async {
    FocusScope.of(context).unfocus();
    final today = dateOnly(controller.now);
    final start =
        _filter.from ?? DateTime(today.year, today.month, today.day - 29);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      currentDate: today,
      initialDateRange: DateTimeRange(
        start: start.isAfter(today) ? today : start,
        end: _filter.through ?? today,
      ),
      helpText: '筛选记录日期',
      saveText: '应用',
    );
    if (!mounted || picked == null) return;
    _setFilter(
      _filter.copyWith(days: 0, from: picked.start, through: picked.end),
    );
  }

  Widget _filters(int total, int matches) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('history-search'),
        controller: _search,
        enableIMEPersonalizedLearning: false,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onChanged: (value) => _setFilter(_filter.copyWith(search: value)),
        decoration: InputDecoration(
          labelText: '搜索形态',
          hintText: '例如：光滑柔软或 01',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索文字',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    _setFilter(_filter.copyWith(search: ''));
                  },
                ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final days in [0, 7, 30])
            ChoiceChip(
              label: Text(days == 0 ? '全部' : '近 $days 天'),
              selected: _filter.days == days && _filter.from == null,
              onSelected: (_) =>
                  _setFilter(_filter.copyWith(days: days, clearDates: true)),
            ),
          ChoiceChip(
            key: const Key('history-date-range'),
            label: const Text('自选日期'),
            selected: _filter.from != null,
            onSelected: (_) => _pickRange(),
          ),
        ],
      ),
      if (_filter.from != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${formatHistoryDate(_filter.from!)} — ${formatHistoryDate(_filter.through!)}',
            key: const Key('history-custom-range'),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
      ExpansionTile(
        key: const PageStorageKey('history-type-filters'),
        tilePadding: EdgeInsets.zero,
        title: const Text('按形态筛选', style: TextStyle(fontSize: 14)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('全部形态'),
                  selected: _filter.bristolType == null,
                  onSelected: (_) =>
                      _setFilter(_filter.copyWith(clearType: true)),
                ),
                for (final type in bristolTypes)
                  ChoiceChip(
                    key: ValueKey('history-type-${type.number}'),
                    label: Text('${type.code} ${type.label}'),
                    selected: _filter.bristolType == type.number,
                    onSelected: (selected) => _setFilter(
                      _filter.copyWith(
                        bristolType: type.number,
                        clearType: !selected,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _filter.isActive ? '找到 $matches 条 / 全部 $total 条' : '共 $total 笔记录',
            key: const Key('history-result-count'),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
          ),
          if (_filter.isActive)
            TextButton(
              key: const Key('history-reset'),
              onPressed: _clearFilter,
              child: const Text('清除筛选'),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final records = controller.records;
            final matches = _filter.apply(
              records,
              today: controller.currentDate,
            );
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
                          CalendarButton(onPressed: widget.onCalendar),
                          Pressable(
                            key: const Key('history-backfill'),
                            semanticLabel: '补记过去的记录',
                            enabled:
                                !controller.isWorking && !controller.isLoading,
                            onPressed: widget.onBackfill,
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
                      const SizedBox(height: 8),
                      if (controller.isLoading)
                        const Text('正在读取')
                      else
                        _filters(records.length, matches.length),
                      if (controller.errorMessage != null)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              controller.errorMessage!,
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
                      if (!controller.isLoading && records.isEmpty)
                        const _EmptyHistory(),
                      if (!controller.isLoading &&
                          records.isNotEmpty &&
                          matches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(child: Text('没有符合条件的记录')),
                        ),
                      for (final group in _groupRecords(matches)) ...[
                        _HistoryDayHeader(group: group),
                        for (final record in group.records)
                          _HistoryRecordRow(
                            record: record,
                            enabled: !controller.isWorking,
                            onEdit: () => widget.onEdit(record.recordId),
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
                    onToday: widget.onToday,
                    onRecord: widget.onRecord,
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
            '${formatDeleteDate(record.recordedAt)} · ${type.code} ${type.label}\n删除后可在短暂提示中恢复。',
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
