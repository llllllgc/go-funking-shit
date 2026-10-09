import '../data/knowledge_base.dart';
import '../widgets/knowledge_sources.dart';
// Hallmark · genre: playful · macrostructure: single-task-list · design-system: locked LaLeMa
// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../domain/bristol_type.dart';
import '../domain/record_details.dart';
import '../widgets/pressable.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({
    required this.controller,
    this.editRecordId,
    this.initialDate,
    super.key,
  });

  final BowelLogController controller;
  final String? editRecordId;
  final DateTime? initialDate;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late DateTime _recordedAt;
  int? _selectedType;
  late final TextEditingController _note;
  int _discomfortMask = 0;
  bool _detailsMode = false;
  bool _allowPop = false;
  bool _saving = false;

  bool get _hasDateControls =>
      widget.initialDate != null || widget.editRecordId != null;
  bool get _hasUnsavedDetails {
    final old =
        widget.controller.record(widget.editRecordId)?.details ??
        const RecordDetails();
    return _note.text != old.note || _discomfortMask != old.discomfortMask;
  }

  bool get _explicitSave => _hasDateControls || _detailsMode;

  @override
  void initState() {
    super.initState();
    final record = widget.controller.record(widget.editRecordId);
    final now = widget.controller.now;
    final date = widget.initialDate ?? now;
    _recordedAt =
        record?.recordedAt ??
        DateTime(date.year, date.month, date.day, now.hour, now.minute);
    _selectedType = record?.bristolType;
    _note = TextEditingController(text: record?.details.note ?? '')
      ..addListener(_detailsChanged);
    _discomfortMask = record?.details.discomfortMask ?? 0;
    _detailsMode = record != null && !record.details.isEmpty;
  }

  void _detailsChanged() => setState(() {});

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _requestBack() async {
    if (_saving || widget.controller.isWorking) return;
    if (_hasUnsavedDetails) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的细节？'),
          content: const Text('填写的备注和不适尚未保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续填写'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Widget _optionalDetails(bool enabled) => ExpansionTile(
    key: const PageStorageKey('record-details'),
    maintainState: true,
    initiallyExpanded: _detailsMode,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    title: const Text('添加细节（可选）', style: TextStyle(fontSize: 14)),
    subtitle: const Text(
      '备注、腹痛、腹胀等',
      style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
    ),
    onExpansionChanged: (expanded) {
      if (expanded) setState(() => _detailsMode = true);
    },
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final symptom in Discomfort.values)
              FilterChip(
                key: ValueKey('discomfort-${symptom.name}'),
                label: Text(symptom.label),
                selected: _discomfortMask & symptom.bit != 0,
                onSelected: !enabled
                    ? null
                    : (selected) => setState(() {
                        _discomfortMask = selected
                            ? _discomfortMask | symptom.bit
                            : _discomfortMask & ~symptom.bit;
                      }),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        key: const PageStorageKey('record-note'),
        enableIMEPersonalizedLearning: false,
        controller: _note,
        enabled: enabled,
        minLines: 2,
        maxLines: 4,
        maxLength: RecordDetails.maxNoteLength,
        decoration: const InputDecoration(
          labelText: '备注（可选）',
          hintText: '例如：今天的饮食、用药或其他感受',
          border: OutlineInputBorder(),
        ),
      ),
      const Text(
        '细节只保存在本机。未勾选表示未记录，不代表没有不适。',
        style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
      ),
    ],
  );

  void _setDate(DateTime date) {
    widget.controller.clearFeedback();
    final now = widget.controller.now;
    var hour = _recordedAt.hour;
    var minute = _recordedAt.minute;
    // A date picker changes only the calendar date. If the previous time is
    // later than the current time and the new date is today, clamp it now so
    // the form never displays an impossible future occurrence.
    if (isSameDate(date, now) &&
        DateTime(date.year, date.month, date.day, hour, minute).isAfter(now)) {
      hour = now.hour;
      minute = now.minute;
    }
    setState(
      () =>
          _recordedAt = DateTime(date.year, date.month, date.day, hour, minute),
    );
  }

  Future<void> _pickDate() async {
    final today = dateOnly(widget.controller.now);
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOnly(_recordedAt).isAfter(today)
          ? today
          : dateOnly(_recordedAt),
      currentDate: today,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: '选择记录日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) _setDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
      helpText: '选择实际发生时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      widget.controller.clearFeedback();
      var hour = picked.hour;
      var minute = picked.minute;
      final now = widget.controller.now;
      if (isSameDate(_recordedAt, now) &&
          DateTime(
            _recordedAt.year,
            _recordedAt.month,
            _recordedAt.day,
            hour,
            minute,
          ).isAfter(now)) {
        hour = now.hour;
        minute = now.minute;
      }
      setState(
        () => _recordedAt = DateTime(
          _recordedAt.year,
          _recordedAt.month,
          _recordedAt.day,
          hour,
          minute,
        ),
      );
    }
  }

  Future<void> _showBristolGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * .78),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Bristol 形态说明',
                    style: pixelStyle(size: 22, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '只按外观选最接近的一项即可。这里是自我记录工具，不用于诊断。',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final type in bristolTypes) ...<Widget>[
                    _GuideRow(type: type),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 16),
                  const KnowledgeSources(sources: [KnowledgeBase.bristol]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save(int type) async {
    if (_saving || widget.controller.isWorking) return;
    setState(() => _saving = true);
    final saved = await widget.controller.saveType(
      type,
      editRecordId: widget.editRecordId,
      recordedAt: _hasDateControls ? _recordedAt : null,
      details: RecordDetails(note: _note.text, discomfortMask: _discomfortMask),
    );
    if (saved && mounted) {
      final savedAt = widget.controller.lastSavedAt!;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(savedAt);
    } else if (mounted) {
      setState(() => _saving = false);
    }
  }

  Widget _dateControls(bool enabled) {
    final now = widget.controller.now;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.rule),
          bottom: BorderSide(color: AppColors.rule),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DateShortcut(
                label: '今天',
                selected: isSameDate(_recordedAt, now),
                enabled: enabled,
                onPressed: () => _setDate(now),
              ),
              _DateShortcut(
                label: '昨天',
                selected: isSameDate(_recordedAt, yesterday),
                enabled: enabled,
                onPressed: () => _setDate(yesterday),
              ),
              _DateShortcut(
                label: '其他日期',
                selected:
                    !isSameDate(_recordedAt, now) &&
                    !isSameDate(_recordedAt, yesterday),
                enabled: enabled,
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _DateField(
                  label: '记录日期',
                  value:
                      '${_recordedAt.year}年${_recordedAt.month}月${_recordedAt.day}日',
                  fieldKey: const Key('record-date'),
                  enabled: enabled,
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _DateField(
                  label: '具体时间',
                  value: formatTime(_recordedAt),
                  fieldKey: const Key('record-time'),
                  enabled: enabled,
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '请核对实际发生的日期和时间',
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => PopScope(
        canPop: !controller.isWorking && (_allowPop || !_hasUnsavedDetails),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !controller.isWorking) _requestBack();
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _RecordHeader(
                  title: widget.editRecordId != null
                      ? '修改记录'
                      : _hasDateControls
                      ? '补记'
                      : '记录一次',
                  enabled: !controller.isWorking && !_saving,
                  onBack: _requestBack,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        width: double.infinity,
                        child: ListView(
                          key: const PageStorageKey('record-form'),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          children: [
                            if (_hasDateControls)
                              _dateControls(!controller.isWorking),
                            Text(
                              '更接近哪一种？',
                              style: pixelStyle(size: 28, height: 1.3),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _explicitSave
                                          ? '选好形态后，点击下方保存'
                                          : '点选后立即记下，可随时修改',
                                      style: const TextStyle(
                                        color: AppColors.inkMuted,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Pressable(
                                    key: const Key('bristol-guide'),
                                    semanticLabel: '查看 Bristol 形态说明',
                                    enabled: !controller.isWorking,
                                    onPressed: _showBristolGuide,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                        minWidth: 64,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      child: const Text(
                                        '怎么看？',
                                        style: TextStyle(
                                          color: AppColors.mossInk,
                                          fontSize: 12,
                                          height: 1.5,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _optionalDetails(!controller.isWorking),
                            for (final type in bristolTypes) ...[
                              _BristolChoice(
                                type: type,
                                selected: _selectedType == type.number,
                                enabled:
                                    !controller.isWorking &&
                                    !controller.isLoading,
                                onPressed: () {
                                  if (_explicitSave) {
                                    setState(() => _selectedType = type.number);
                                  } else {
                                    _save(type.number);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (controller.errorMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Text(
                        controller.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (_explicitSave)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Pressable(
                      key: const Key('record-save'),
                      semanticLabel: widget.editRecordId != null
                          ? '保存修改'
                          : _hasDateControls
                          ? '确认补记'
                          : '保存记录',
                      enabled:
                          _selectedType != null &&
                          !controller.isWorking &&
                          !controller.isLoading,
                      onPressed: () => _save(_selectedType!),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        alignment: Alignment.center,
                        color: AppColors.moss,
                        child: Text(
                          controller.isWorking
                              ? '正在保存…'
                              : widget.editRecordId != null
                              ? '保存修改'
                              : _hasDateControls
                              ? '补记到 ${_recordedAt.month}月${_recordedAt.day}日'
                              : '保存记录',
                          style: const TextStyle(
                            color: AppColors.paperRaised,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (controller.isWorking)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '正在记下…',
                      style: TextStyle(color: AppColors.mossInk),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateShortcut extends StatelessWidget {
  const _DateShortcut({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: label,
    selected: selected,
    enabled: enabled,
    onPressed: onPressed,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.mossPale : AppColors.paper,
        border: Border.all(color: selected ? AppColors.moss : AppColors.rule),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.mossInk),
      ),
    ),
  );
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.type});

  final BristolType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.paperRaised,
        border: Border.fromBorderSide(BorderSide(color: AppColors.rule)),
      ),
      child: Row(
        children: <Widget>[
          Text(type.code, style: pixelStyle(size: 16, height: 1.3)),
          const SizedBox(width: 10),
          SvgPicture.asset(type.assetPath, width: 34, height: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              type.label,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.fieldKey,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final String value;
  final Key fieldKey;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
      ),
      const SizedBox(height: 4),
      Pressable(
        key: fieldKey,
        semanticLabel: '$label，$value，修改',
        enabled: enabled,
        onPressed: onPressed,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.paperRaised,
            border: Border.all(color: AppColors.rule),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 4),
              const Text('›', style: TextStyle(color: AppColors.inkMuted)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({
    required this.title,
    required this.enabled,
    required this.onBack,
  });

  final String title;
  final bool enabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            Pressable(
              semanticLabel: '返回',
              enabled: enabled,
              onPressed: onBack,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/ic_ticket_back.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      AppColors.ink,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: pixelStyle(size: 16, height: 22 / 16)),
          ],
        ),
      ),
    );
  }
}

class _BristolChoice extends StatefulWidget {
  const _BristolChoice({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final BristolType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_BristolChoice> createState() => _BristolChoiceState();
}

class _BristolChoiceState extends State<_BristolChoice> {
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 80);
    final borderColor = _focused || widget.selected
        ? AppColors.moss
        : AppColors.rule;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: '${widget.type.code}，${widget.type.label}',
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
          child: AnimatedSlide(
            offset: Offset(0, _pressed ? 2 / 78 : 0),
            duration: duration,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: widget.enabled ? 1 : 0.58,
              duration: duration,
              child: Container(
                constraints: const BoxConstraints(minHeight: 78),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.selected ? AppColors.mossPale : AppColors.paper,
                  border: Border.all(
                    color: borderColor,
                    width: widget.selected || _focused ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      widget.type.code,
                      style: pixelStyle(size: 21, height: 26 / 21),
                    ),
                    const SizedBox(width: 12),
                    SvgPicture.asset(
                      widget.type.assetPath,
                      width: 54,
                      height: 54,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.type.label,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (widget.selected) ...<Widget>[
                      const SizedBox(width: 8),
                      const Text(
                        '已选',
                        maxLines: 1,
                        style: TextStyle(
                          color: AppColors.mossInk,
                          fontSize: 12,
                          height: 16 / 12,
                        ),
                      ),
                    ],
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
