// Hallmark · genre: playful · macrostructure: chronological-ticket · design-system: locked LaLeMa
// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
import 'dart:math' as math;
import 'dart:async';

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
import '../widgets/record_details_preview.dart';
import '../widgets/calendar_button.dart';
import '../widgets/ticket_bottom_bar.dart';
import '../widgets/undo_snackbar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.controller,
    required this.onToday,
    required this.onRecord,
    required this.onEdit,
    required this.onCalendar,
    required this.onBackfill,
    required this.onData,
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
  final VoidCallback onData;

  final HistoryFilter initialFilter;
  final ValueChanged<HistoryFilter>? onFilterChanged;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late HistoryFilter _filter;
  late final TextEditingController _search;
  final _scroll = ScrollController();
  Timer? _debounce;
  List<BowelRecord>? _source;
  HistoryFilter? _lastFilter;
  DateTime? _lastDate;
  List<BowelRecord> _matches = const [];
  List<Object> _entries = const [];

  BowelLogController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _search = TextEditingController(text: _filter.search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _setFilter(HistoryFilter value, {bool scrollToTop = false}) {
    _debounce?.cancel();
    final next = value.copyWith(search: _search.text);
    setState(() => _filter = next);
    widget.onFilterChanged?.call(next);
    if (scrollToTop && _scroll.hasClients) _scroll.jumpTo(0);
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    // Retain the latest draft even if the user switches tabs before debounce.
    widget.onFilterChanged?.call(_filter.copyWith(search: value));
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _setFilter(_filter.copyWith(search: value));
    });
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    _setFilter(const HistoryFilter(), scrollToTop: true);
  }

  void _updateResults() {
    final records = controller.records;
    if (identical(records, _source) &&
        _lastFilter == _filter &&
        _lastDate == controller.currentDate) {
      return;
    }
    _source = records;
    _lastFilter = _filter;
    _lastDate = controller.currentDate;
    _matches = _filter.apply(records, today: controller.currentDate);
    _entries = [
      for (final group in _groupRecords(_matches)) ...[group, ...group.records],
    ];
  }

  Future<void> _pickRange() async {
    FocusScope.of(context).unfocus();
    final today = dateOnly(controller.now);
    final start =
        _filter.from ??
        DateTime(
          today.year,
          today.month,
          today.day - (_filter.days > 0 ? _filter.days : 30) + 1,
        );
    final end = _filter.through ?? today;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: today,
      currentDate: today,
      initialDateRange: DateTimeRange(
        start: start.isAfter(today) ? today : start,
        end: end.isAfter(today) ? today : end,
      ),
      helpText: '筛选记录日期',
      switchToInputEntryModeIcon: const Icon(
        Icons.edit_calendar,
        key: Key('history-range-input'),
      ),
      saveText: '应用',
      confirmText: '应用',
      cancelText: '取消',
    );
    if (picked != null && mounted) {
      _setFilter(
        _filter.copyWith(days: 0, from: picked.start, through: picked.end),
      );
    }
  }

  Widget _filters() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('history-search'),
        controller: _search,
        onChanged: _searchChanged,
        enableIMEPersonalizedLearning: false,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _debounce?.cancel();
          _setFilter(_filter.copyWith(search: _search.text));
          FocusScope.of(context).unfocus();
        },
        decoration: InputDecoration(
          labelText: '搜索记录',
          hintText: '备注、形态或不适',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索文字',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _debounce?.cancel();
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
              onSelected: (_) {
                FocusScope.of(context).unfocus();
                _setFilter(_filter.copyWith(days: days, clearDates: true));
              },
            ),
          ChoiceChip(
            key: const Key('history-date-range'),
            avatar: const Icon(Icons.date_range, size: 18),
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
            '${_filter.from!.year}/${_filter.from!.month}/${_filter.from!.day} — ${_filter.through!.year}/${_filter.through!.month}/${_filter.through!.day}',
            key: const Key('history-custom-range'),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
        ),
      ExpansionTile(
        key: const PageStorageKey('history-extra-filters'),
        initiallyExpanded: _filter.extraCount > 0,
        tilePadding: EdgeInsets.zero,
        title: Text(
          '形态与不适${_filter.extraCount == 0 ? '' : '（${_filter.extraCount}项）'}',
          style: const TextStyle(fontSize: 14),
        ),
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
                    label: Text('${type.number}型'),
                    tooltip: type.label,
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
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              key: const Key('history-discomfort'),
              label: const Text('仅看记录了不适的条目'),
              selected: _filter.onlyWithDiscomfort,
              onSelected: (value) =>
                  _setFilter(_filter.copyWith(onlyWithDiscomfort: value)),
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
            _search.text != _filter.search
                ? '正在筛选…'
                : _filter.isActive
                ? '找到 ${_matches.length} 条 / 全部 ${controller.records.length} 条'
                : '共 ${controller.records.length} 笔记录',
            key: const Key('history-result-count'),
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
          ),
          if (_filter.isActive || _search.text.isNotEmpty)
            TextButton(
              key: const Key('history-reset'),
              onPressed: _reset,
              child: const Text('清除筛选'),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) widget.onToday();
    },
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        _updateResults();
        return Scaffold(
          backgroundColor: AppColors.paper,
          bottomNavigationBar: TicketBottomBar(
            selectedTab: TicketTab.history,
            onToday: () {
              FocusScope.of(context).unfocus();
              widget.onToday();
            },
            onRecord: widget.onRecord,
            onHistory: () {},
            recordEnabled: !controller.isWorking && !controller.isLoading,
          ),
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: math.min(560.0, constraints.maxWidth),
                  child: CustomScrollView(
                    key: const PageStorageKey('history-list'),
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '历史',
                                      style: pixelStyle(
                                        size: 30,
                                        height: 38 / 30,
                                      ),
                                    ),
                                  ),
                                  CalendarButton(onPressed: widget.onCalendar),
                                  Pressable(
                                    key: const Key('history-backfill'),
                                    semanticLabel: '补记过去的记录',
                                    enabled:
                                        !controller.isWorking &&
                                        !controller.isLoading,
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
                              TextButton.icon(
                                key: const Key('history-data'),
                                onPressed: controller.isWorking
                                    ? null
                                    : widget.onData,
                                icon: const Icon(
                                  Icons.folder_open_outlined,
                                  size: 20,
                                ),
                                label: const Text('备份、导出与恢复'),
                              ),
                              const SizedBox(height: 12),
                              _filters(),
                              if (controller.errorMessage != null ||
                                  controller.feedbackMessage != null)
                                Semantics(
                                  liveRegion: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
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
                              if (controller.isLoading)
                                const Text('正在读取记录…')
                              else if (controller.records.isEmpty)
                                const _EmptyHistory()
                              else if (_matches.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '没有符合条件的记录',
                                        style: pixelStyle(size: 18),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('试试其他关键词，或放宽日期、形态和不适条件。'),
                                      TextButton(
                                        onPressed: _reset,
                                        child: const Text('查看全部记录'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            if (entry is _HistoryGroup) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? 0 : 24,
                                ),
                                child: _HistoryDayHeader(
                                  group: entry,
                                  referenceDate: controller.currentDate,
                                ),
                              );
                            }
                            final record = entry as BowelRecord;
                            return _HistoryRecordRow(
                              key: ValueKey(
                                'history-record-${record.recordId}',
                              ),
                              record: record,
                              enabled: !controller.isWorking,
                              onEdit: () => widget.onEdit(record.recordId),
                              onDelete: () => _confirmDelete(context, record),
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

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
            '${formatDeleteDate(record.recordedAt)} · ${type.code} ${type.label}\n删除后可在提示条中恢复记录。',
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
    if (confirmed == true) {
      final deleted = await controller.deleteRecord(record.recordId);
      if (deleted != null && context.mounted) {
        showRecordUndoSnackBar(context, controller, deleted);
      }
    }
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
  const _HistoryDayHeader({required this.group, required this.referenceDate});

  final DateTime referenceDate;

  final _HistoryGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              formatHistoryDate(group.date, referenceDate: referenceDate),
              style: pixelStyle(size: 18, height: 24 / 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${group.records.length} 条',
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
    super.key,
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
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Pressable(
                  semanticLabel:
                      '${formatTime(record.recordedAt)}，${type.code}，${type.label}，修改',
                  enabled: enabled,
                  onPressed: onEdit,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 76),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 4),
                        if (MediaQuery.textScalerOf(context).scale(14) >
                            18) ...[
                          SvgPicture.asset(
                            type.assetPath,
                            width: 40,
                            height: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${formatTime(record.recordedAt)} · ${type.code}型',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.mossInk,
                                    ),
                                  ),
                                  Text(
                                    type.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
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
                          SvgPicture.asset(
                            type.assetPath,
                            width: 48,
                            height: 48,
                          ),
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
                        ],
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
