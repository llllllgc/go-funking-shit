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
    const captureKey = Key('capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: LaLeMaApp(controller: controller),
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
