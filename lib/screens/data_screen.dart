import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/bowel_log_controller.dart';
import '../application/privacy_controller.dart';
import '../core/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/backup_files.dart';
import '../data/record_archive.dart';
import '../domain/bowel_record.dart';
import '../domain/record_transfer.dart';

// Isolate messages contain only immutable snapshots, never a controller or a
// platform handle. Large JSON/CSV conversion does not block the UI thread.
RecordArchive _decodeArchive((Uint8List, DateTime) message) =>
    RecordArchiveCodec.decode(message.$1, now: message.$2);
Uint8List _encodeArchive(RecordArchive archive) =>
    RecordArchiveCodec.encode(archive);
Uint8List _encodeCsv((List<BowelRecord>, bool) message) =>
    RecordArchiveCodec.csv(message.$1, includeDetails: message.$2);

class DataScreen extends StatefulWidget {
  const DataScreen({
    required this.controller,
    required this.privacy,
    this.files = const DeviceBackupFiles(),
    this.backupEncoder,
    super.key,
  });
  final BowelLogController controller;
  final PrivacyController privacy;
  final BackupFiles files;
  final Future<Uint8List> Function(RecordArchive)? backupEncoder;

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _busy = false;
  String? _message;
  bool _error = false;
  int _days = 30; // zero means all history
  bool _includeDetails = false;
  RecordArchive? _pending;

  List<BowelRecord> _inRange(List<BowelRecord> records) {
    if (_days == 0) return records;
    final today = dateOnly(widget.controller.now);
    final start = DateTime(today.year, today.month, today.day - _days + 1);
    final end = DateTime(today.year, today.month, today.day + 1);
    return records
        .where(
          (record) =>
              !record.recordedAt.isBefore(start) &&
              record.recordedAt.isBefore(end),
        )
        .toList();
  }

  String _rangeLabel(List<BowelRecord> records) {
    if (records.isEmpty) return '没有记录';
    final times = records.map((record) => record.recordedAt).toList()..sort();
    String date(DateTime time) => '${time.year}/${time.month}/${time.day}';
    return '${date(times.first)} — ${date(times.last)}';
  }

  void _feedback(String message, {bool error = false}) {
    if (mounted) {
      setState(() {
        _message = message;
        _error = error;
      });
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy ||
        widget.controller.isWorking ||
        !widget.controller.hasLoaded ||
        widget.privacy.concealed) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } on ArchiveException catch (error) {
      _feedback(error.message, error: true);
    } catch (_) {
      _feedback('操作没有完成，请检查文件或保存位置后重试。', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export({required bool backup}) => _run(() async {
    final snapshot = backup
        ? widget.controller.records
        : _inRange(widget.controller.records);
    final now = widget.controller.now;
    final accessEpoch = widget.privacy.accessEpoch;
    final bytes = backup
        ? await (widget.backupEncoder?.call(
                RecordArchive(records: snapshot, exportedAt: now),
              ) ??
              compute(
                _encodeArchive,
                RecordArchive(records: snapshot, exportedAt: now),
              ))
        : await compute(_encodeCsv, (snapshot, _includeDetails));
    if (!mounted || !widget.privacy.allowsInteraction(accessEpoch)) {
      throw const ArchiveException('应用已离开或锁定，请解锁后重新导出。');
    }
    final suffix = backup ? 'json' : 'csv';
    final stamp = now
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final saved = await widget.files.save(
      name: 'lalema-${backup ? 'backup' : 'records'}-$stamp.$suffix',
      bytes: bytes,
      mimeType: backup ? 'application/json' : 'text/csv',
    );
    _feedback(
      saved
          ? '${backup ? '备份' : 'CSV'}已保存，共 ${snapshot.length} 条记录。'
          : '已取消保存，记录未更改。',
    );
  });

  Future<void> _pick() => _run(() async {
    setState(() => _pending = null);
    final bytes = await widget.files.pickBackup();
    if (bytes == null) {
      _feedback('已取消选择，记录未更改。');
      return;
    }
    final archive = await compute(_decodeArchive, (
      bytes,
      widget.controller.now,
    ));
    if (mounted) setState(() => _pending = archive);
    _feedback('备份已读取，请核对预览后确认导入。');
  });

  Future<void> _import() => _run(() async {
    final archive = _pending;
    if (archive == null) return;
    final result = await widget.controller.importRecords(archive.records);
    if (result == null) {
      _feedback(widget.controller.errorMessage ?? '导入未完成，请重试。', error: true);
      return;
    }
    if (mounted) setState(() => _pending = null);
    _feedback(
      '已新增 ${result.additions.length} 条，跳过 ${result.duplicates} 条重复记录，保留 ${result.conflicts} 条本机冲突记录。',
    );
  });

  Future<void> _confirmClear() async {
    if (_busy || widget.controller.isWorking) return;
    final count = widget.controller.records.length;
    var text = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('清空本机全部记录？'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '将删除 $count 条记录及备注、不适信息。此操作无法撤销，建议先保存 JSON 备份。导出的文件和系统备份不会被删除。',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('clear-confirmation'),
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '输入“清空”以确认'),
                  onChanged: (value) => update(() => text = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留记录'),
            ),
            TextButton(
              key: const Key('clear-confirm'),
              onPressed: text == '清空'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text(
                '确认清空',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      if (await widget.controller.clearAllRecords()) {
        if (mounted) setState(() => _pending = null);
        _feedback('本机记录已清空。导出的文件和系统备份仍由你保管。');
      } else {
        _feedback(widget.controller.errorMessage ?? '清空未完成。', error: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final records = widget.controller.records;
      final csvRecords = _inRange(records);
      final enabled =
          !_busy && !widget.controller.isWorking && widget.controller.hasLoaded;
      final plan = _pending == null
          ? null
          : ImportPlan.compare(records, _pending!.records);
      return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text('数据管理', style: pixelStyle(size: 20)),
            leading: IconButton(
              key: const Key('data-back'),
              tooltip: '返回',
              icon: const BackButtonIcon(),
              onPressed: _busy ? null : () => Navigator.maybePop(context),
            ),
          ),
          bottomNavigationBar: !_busy && _message == null
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .3,
                    ),
                    padding: const EdgeInsets.all(16),
                    color: AppColors.mossPale,
                    child: SingleChildScrollView(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_busy) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              const Text('正在处理文件…'),
                            ],
                            if (_message != null)
                              Text(
                                _message!,
                                key: const Key('data-feedback'),
                                style: TextStyle(
                                  color: _error
                                      ? AppColors.danger
                                      : AppColors.mossInk,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('你的记录，由你保管', style: pixelStyle(size: 24, height: 1.4)),
                    const SizedBox(height: 8),
                    Text(
                      '本机共 ${records.length} 条 · ${_rangeLabel(records)}',
                      style: const TextStyle(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '备份可恢复到其他设备；CSV 便于查看或自行分享，不能用于恢复。应用不会自动上传。选择云盘保存时，文件由该云盘服务管理。',
                    ),
                    _section('完整备份', [
                      Text(
                        '包含全部 ${records.length} 条记录、时间、备注和不适信息。JSON 文件未加密，请保存到可信位置。',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('backup-save'),
                        onPressed: enabled ? () => _export(backup: true) : null,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('保存 JSON 备份'),
                      ),
                    ]),
                    _section('导出记录表', [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final days in [7, 30, 0])
                            ChoiceChip(
                              label: Text(days == 0 ? '全部' : '近 $days 天'),
                              selected: _days == days,
                              onSelected: enabled
                                  ? (_) => setState(() => _days = days)
                                  : null,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '将导出 ${csvRecords.length} 条 · ${_rangeLabel(csvRecords)}',
                        key: const Key('csv-preview'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('包含备注和不适信息'),
                        subtitle: const Text('默认仅导出时间和形态'),
                        value: _includeDetails,
                        onChanged: enabled
                            ? (value) => setState(
                                () => _includeDetails = value ?? false,
                              )
                            : null,
                      ),
                      OutlinedButton(
                        key: const Key('csv-save'),
                        onPressed: enabled && csvRecords.isNotEmpty
                            ? () => _export(backup: false)
                            : null,
                        child: const Text('保存 CSV 文件'),
                      ),
                    ]),
                    _section('从备份恢复', [
                      const Text(
                        '选择本应用导出的 JSON 文件。仅添加缺失记录；重复或内容冲突时保留本机版本。支持最多 32 MB、100000 条记录。',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const Key('backup-pick'),
                        onPressed: enabled ? _pick : null,
                        child: const Text('选择 JSON 备份'),
                      ),
                      if (plan != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          '备份共 ${plan.total} 条 · ${_rangeLabel(_pending!.records)}',
                          key: const Key('import-preview'),
                        ),
                        Text(
                          '新增 ${plan.additions.length} 条 · 重复 ${plan.duplicates} 条 · 冲突 ${plan.conflicts} 条',
                        ),
                        if (plan.conflicts > 0)
                          const Text('内容不同的同编号记录不会覆盖本机内容。请保留原备份以便核对。'),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('backup-import'),
                          onPressed: enabled && plan.additions.isNotEmpty
                              ? _import
                              : null,
                          child: Text(
                            plan.additions.isEmpty
                                ? '没有需要新增的记录'
                                : '确认导入 ${plan.additions.length} 条',
                          ),
                        ),
                        TextButton(
                          onPressed: enabled
                              ? () => setState(() => _pending = null)
                              : null,
                          child: const Text('取消导入'),
                        ),
                      ],
                    ]),
                    _section('清空本机记录', [
                      const Text('会删除本机全部记录和细节，无法撤销。请先备份需要保留的内容。'),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('data-clear'),
                        onPressed: enabled && records.isNotEmpty
                            ? _confirmClear
                            : null,
                        child: const Text(
                          '清空全部记录…',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Material(
      color: AppColors.paperRaised,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.rule),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: pixelStyle(size: 18, height: 1.4)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}
