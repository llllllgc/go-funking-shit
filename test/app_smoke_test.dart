import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/data/bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';

void main() {
  testWidgets('shows the active three-screen product surface', (tester) async {
    final controller = BowelLogController(
      _EmptyRepository(),
      now: () => DateTime(2026, 9, 16, 12),
    );
    await controller.initialize();

    await tester.pumpWidget(LaLeMaApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsWidgets);
    expect(find.text('点一下，记一笔'), findsOneWidget);
    expect(find.text('有记录的天数'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(find.text('还没有记录'), findsOneWidget);
  });
}

class _EmptyRepository implements BowelRecordRepository {
  @override
  Future<BowelRecord> create(int bristolType, {DateTime? recordedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String recordId) => throw UnimplementedError();

  @override
  Future<void> restore(BowelRecord record) => throw UnimplementedError();

  @override
  Future<List<BowelRecord>> loadAll() async => const <BowelRecord>[];

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
  }) => throw UnimplementedError();
}
