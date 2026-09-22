// Hallmark · genre: playful · macrostructure: single-task-list · design-system: locked LaLeMa
// Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../domain/bristol_type.dart';
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

  bool get _explicitSave =>
      widget.initialDate != null || widget.editRecordId != null;

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
  }

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
      () => _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      ),
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

  Future<void> _save(int type) async {
    if (widget.controller.isWorking) return;
    final saved = await widget.controller.saveType(
      type,
      editRecordId: widget.editRecordId,
      recordedAt: _explicitSave ? _recordedAt : null,
    );
    if (saved && mounted) {
      Navigator.of(
        context,
      ).pop(_explicitSave ? _recordedAt : widget.controller.now);
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
        canPop: !controller.isWorking,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _RecordHeader(
                  title: widget.editRecordId != null
                      ? '修改记录'
                      : _explicitSave
                      ? '补记'
                      : '记录一次',
                  enabled: !controller.isWorking,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    key: const PageStorageKey('record-form'),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      if (_explicitSave) _dateControls(!controller.isWorking),
                      Text('更接近哪一种？', style: pixelStyle(size: 28, height: 1.3)),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          _explicitSave ? '选好形态后，确认保存到这一天' : '点选后立即记下，可随时修改',
                          style: const TextStyle(
                            color: AppColors.inkMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      for (final type in bristolTypes) ...[
                        _BristolChoice(
                          type: type,
                          selected: _selectedType == type.number,
                          enabled:
                              !controller.isWorking && !controller.isLoading,
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
                      semanticLabel: widget.editRecordId == null
                          ? '确认补记'
                          : '保存修改',
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
                              : '补记到 ${_recordedAt.month}月${_recordedAt.day}日',
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
