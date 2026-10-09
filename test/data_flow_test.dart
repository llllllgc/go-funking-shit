import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/data/backup_files.dart';
import 'package:lalema/data/record_archive.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:lalema/screens/data_screen.dart';

import 'support/memory_repository.dart';

class FakeBackupFiles implements BackupFiles {
  Uint8List? selection;
  Uint8List? savedBytes;
  String? savedName;
  bool cancelled = false;
  bool failSave = false;
  @override
  Future<Uint8List?> pickBackup() async => selection;
  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (failSave) throw StateError('denied');
    if (cancelled) return false;
    savedBytes = bytes;
    savedName = name;
    return true;
  }
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final now = DateTime(2026, 10, 9, 12);
  late MemoryRepository repository;
  late BowelLogController controller;
  late FakeBackupFiles files;
  BowelRecord record(String id, DateTime time, {String note = '私密备注'}) =>
      BowelRecord(
        recordId: id,
        bristolType: 4,
        recordedAt: time,
        updatedAt: now,
        details: RecordDetails(note: note, discomfortMask: 1),
      );

  Future<void> launch(WidgetTester tester, {double scale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository = MemoryRepository(now)
      ..records.addAll([
        record('today', now),
        record('old', DateTime(2026, 7, 1)),
      ]);
    controller = BowelLogController(repository, now: () => now);
    await controller.initialize();
    files = FakeBackupFiles();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DataScreen(controller: controller, files: files),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> idle(WidgetTester tester) async {
    // Codec work runs in a real isolate. Let it complete outside fake time,
    // then flush the widget tree; do not advance a spinner to a fake timeout.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('Data operation did not finish');
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await idle(tester);
  }

  testWidgets('full JSON backup and limited CSV export have different scopes', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, find.byKey(const Key('backup-save')));
    expect(
      RecordArchiveCodec.decode(files.savedBytes!, now: now).records,
      hasLength(2),
    );
    expect(files.savedName, endsWith('.json'));
    expect(find.text('备份已保存，共 2 条记录。'), findsOneWidget);
    await tap(tester, find.byKey(const Key('csv-save')));
    final csv = utf8.decode(files.savedBytes!);
    expect(csv, contains('2026-10-09'));
    expect(csv, isNot(contains('2026-07-01')));
    expect(csv, isNot(contains('私密备注')));
    await tap(tester, find.text('包含备注和不适信息'));
    await tap(tester, find.text('全部'));
    await tap(tester, find.byKey(const Key('csv-save')));
    expect(utf8.decode(files.savedBytes!), contains('2026-07-01'));
    expect(utf8.decode(files.savedBytes!), contains('私密备注'));
    expect(controller.records, hasLength(2));
  });

  testWidgets('cancel and failed export never claim saved or modify records', (
    tester,
  ) async {
    await launch(tester);
    files.cancelled = true;
    await tap(tester, find.byKey(const Key('backup-save')));
    expect(find.text('已取消保存，记录未更改。'), findsOneWidget);
    files.failSave = true;
    await tap(tester, find.byKey(const Key('backup-save')));
    expect(find.text('操作没有完成，请检查文件或保存位置后重试。'), findsOneWidget);
    expect(files.savedBytes, isNull);
    expect(controller.records, hasLength(2));
  });

  testWidgets(
    'restore preview is nonmutating, keeps conflicts and permits retry',
    (tester) async {
      await launch(tester);
      files.selection = RecordArchiveCodec.encode(
        RecordArchive(
          exportedAt: now,
          records: [
            repository.records.first,
            record('old', DateTime(2026, 7, 1), note: '不同内容'),
            record('new', DateTime(2025, 2, 1)),
          ],
        ),
      );
      await tap(tester, find.byKey(const Key('backup-pick')));
      expect(find.text('新增 1 条 · 重复 1 条 · 冲突 1 条'), findsOneWidget);
      expect(controller.records, hasLength(2));
      repository.failWrites = true;
      await tap(tester, find.byKey(const Key('backup-import')));
      expect(controller.records, hasLength(2));
      expect(find.text('没有导入成功，已有记录未更改，请再试一次'), findsOneWidget);
      repository.failWrites = false;
      await tap(tester, find.byKey(const Key('backup-import')));
      expect(controller.records, hasLength(3));
      expect(controller.record('old')!.details.note, '私密备注');
      await tap(tester, find.byKey(const Key('backup-pick')));
      expect(find.text('新增 0 条 · 重复 2 条 · 冲突 1 条'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('backup-import')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('bad backup and cancelled preview leave local data intact', (
    tester,
  ) async {
    await launch(tester);
    files.selection = Uint8List.fromList(utf8.encode('{broken'));
    await tap(tester, find.byKey(const Key('backup-pick')));
    expect(find.text('备份文件损坏或格式不正确，未导入任何记录。'), findsOneWidget);
    expect(controller.records, hasLength(2));
    files.selection = RecordArchiveCodec.encode(
      RecordArchive(exportedAt: now, records: [record('new', now)]),
    );
    await tap(tester, find.byKey(const Key('backup-pick')));
    await tap(tester, find.text('取消导入'));
    expect(find.byKey(const Key('import-preview')), findsNothing);
    expect(controller.records, hasLength(2));
  });

  testWidgets(
    'clear needs exact confirmation and empties durable controller state',
    (tester) async {
      await launch(tester);
      await tap(tester, find.byKey(const Key('data-clear')));
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('clear-confirm')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('clear-confirmation')), '清空');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear-confirm')));
      await tester.pump();
      await idle(tester);
      expect(controller.records, isEmpty);
      expect(repository.records, isEmpty);
    },
  );

  testWidgets('management screen and confirmation fit double text size', (
    tester,
  ) async {
    await launch(tester, scale: 2);
    await tap(tester, find.byKey(const Key('backup-save')));
    await tap(tester, find.byKey(const Key('backup-pick')));
    await tap(tester, find.byKey(const Key('data-clear')));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('保留记录'));
    await tester.pumpAndSettle();
    expect(controller.records, hasLength(2));
  });

  testWidgets('history exposes data management and returns to history', (
    tester,
  ) async {
    await launch(tester);
    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-data')));
    await tester.pumpAndSettle();
    expect(find.byType(DataScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('data-back')));
    await tester.pumpAndSettle();
    expect(find.byType(DataScreen), findsNothing);
    expect(find.byKey(const Key('history-data')), findsOneWidget);
  });
}
