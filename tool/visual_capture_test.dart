import 'package:lalema/screens/settings_screen.dart';
import 'package:lalema/application/reminder_controller.dart';
import 'package:lalema/data/reminder_service.dart';
import '../test/support/reminder_fakes.dart';
import '../test/support/privacy_fakes.dart';
import '../test/support/memory_repository.dart';
import 'package:lalema/screens/data_screen.dart';
import 'package:lalema/data/backup_files.dart';
import 'package:lalema/data/record_archive.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/domain/record_transfer.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/data/bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';

void main() {
  setUpAll(() async {
    // Widget tests use placeholder glyphs unless fonts are loaded explicitly.
    final pixelFont = FontLoader('Zpix')
      ..addFont(rootBundle.load('assets/fonts/zpix.ttf'));
    final bodyFont = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/zpix.ttf'));
    final materialFont = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([pixelFont.load(), bodyFont.load(), materialFont.load()]);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('capture recovery failure at text scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scale > 1
          ? const Size(320, 640)
          : const Size(375, 812);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final now = DateTime(2026, 10, 9, 12);
      final repository = MemoryRepository(now);
      final controller = BowelLogController(repository, now: () => now);
      await controller.initialize();
      await controller.saveType(4);
      const captureKey = Key('recovery-capture');
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: LaLeMaApp(
            reminders: await quietReminders(),
            controller: controller,
            privacy: await unlockedPrivacy(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      repository.failWrites = true;
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(captureKey),
        matchesGoldenFile('captures/recovery_failure_$scale.png'),
      );
    });
  }

  testWidgets('capture reminder permission and enabled settings', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final service = FakeReminderService()
      ..permission = ReminderPermission.allowed;
    final controller = ReminderController(service);
    await controller.refresh();
    await controller.setEnabled(true);
    const captureKey = Key('reminder-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: SettingsScreen(
            privacy: await unlockedPrivacy(),
            reminders: controller,
            onData: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('按自己的节奏记录'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/reminder_enabled_375.png'),
    );
    service.permission = ReminderPermission.denied;
    await controller.refresh();
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/reminder_denied_375.png'),
    );
  });

  testWidgets('capture backup import preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final now = DateTime(2026, 9, 19, 14, 32);
    final controller = BowelLogController(
      _CaptureRepository(now),
      now: () => now,
    );
    await controller.initialize();
    const captureKey = Key('data-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: DataScreen(
            controller: controller,
            privacy: await unlockedPrivacy(),
            files: _PreviewFiles(now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('backup-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-pick')));
    await tester.pump();
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('backup-import')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/data_import_preview_375.png'),
    );
  });

  testWidgets('capture active screens at 375x812', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime(2026, 9, 19, 14, 32);
    final controller = BowelLogController(
      _CaptureRepository(now),
      now: () => now,
    );
    await controller.initialize();
    final privacy = await unlockedPrivacy();
    const captureKey = Key('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: LaLeMaApp(
          reminders: await quietReminders(),
          controller: controller,
          privacy: privacy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final context = tester.element(find.byKey(captureKey));
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/toilet_paper_spirit_happy.png'),
          context,
        ),
        precacheImage(const AssetImage('assets/images/toilet.png'), context),
      ]);
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/home_375.png'),
    );

    await tester.tap(find.byKey(const Key('today-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-app-lock')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/privacy_settings_375.png'),
    );
    await tester.ensureVisible(find.byKey(const Key('settings-lock-now')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-lock-now')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/privacy_locked_375.png'),
    );
    await tester.tap(find.byKey(const Key('privacy-unlock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('knowledge-preview')));
    await tester.tap(find.byKey(const Key('knowledge-preview')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/knowledge_375.png'),
    );
    Navigator.of(tester.element(find.byKey(const Key('knowledge-back')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/record_375.png'),
    );

    await tester.tap(find.text('添加细节（可选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discomfort-bloating')));
    await tester.enterText(
      find.byKey(const PageStorageKey('record-note')),
      '演示记录：早餐后感觉腹胀。',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/record_details_375.png'),
    );
    await tester.tap(find.bySemanticsLabel('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/history_375.png'),
    );

    await tester.enterText(find.byKey(const Key('history-search')), '松散');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/history_filtered_375.png'),
    );
    await tester.ensureVisible(find.byKey(const Key('history-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-reset')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-data')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/data_management_375.png'),
    );
    await tester.ensureVisible(find.byKey(const Key('backup-pick')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/data_restore_375.png'),
    );
    await tester.tap(find.byKey(const Key('data-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('查看月历'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey('calendar-day-${DateTime(2026, 9, 18).toIso8601String()}'),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/calendar_375.png'),
    );
    await tester.tap(find.byKey(const Key('calendar-month-title')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/calendar_month_picker_375.png'),
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('calendar-backfill')));
    await tester.tap(find.byKey(const Key('calendar-backfill')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('captures/backfill_375.png'),
    );
  });
}

class _CaptureRepository implements BowelRecordRepository {
  _CaptureRepository(DateTime now)
    : _records = <BowelRecord>[
        _record('record-1', 4, now),
        _record('record-2', 3, now.subtract(const Duration(days: 1))),
        _record('record-3', 6, now.subtract(const Duration(days: 3))),
      ];

  final List<BowelRecord> _records;

  @override
  Future<BowelRecord> create(
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails details = const RecordDetails(),
  }) => throw UnimplementedError();

  @override
  Future<ImportPlan> importRecords(List<BowelRecord> records) =>
      throw UnimplementedError();

  @override
  Future<int> deleteAll() => throw UnimplementedError();

  @override
  Future<void> delete(String recordId) => throw UnimplementedError();

  @override
  Future<void> restore(BowelRecord record) => throw UnimplementedError();

  @override
  Future<List<BowelRecord>> loadAll() async => List<BowelRecord>.of(_records);

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails? details,
  }) => throw UnimplementedError();
}

BowelRecord _record(String id, int type, DateTime time) => BowelRecord(
  recordId: id,
  bristolType: type,
  recordedAt: time,
  updatedAt: time,
);

class _PreviewFiles implements BackupFiles {
  _PreviewFiles(this.now);
  final DateTime now;
  @override
  Future<Uint8List?> pickBackup() async => RecordArchiveCodec.encode(
    RecordArchive(
      exportedAt: now,
      records: [
        _record('record-1', 4, now),
        _record('record-2', 7, now.subtract(const Duration(days: 1))),
        _record('backup-new', 3, now.subtract(const Duration(days: 5))),
      ],
    ),
  );
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async => false;
}
