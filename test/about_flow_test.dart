import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'support/memory_repository.dart';
import 'support/privacy_fakes.dart';
import 'support/reminder_fakes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/data/app_information.dart';
import 'package:lalema/domain/app_documents.dart';
import 'package:lalema/screens/about_screen.dart';

class _Information implements AppInformation {
  _Information(this.documentation);
  AppDocumentation documentation;
  bool failVersion = false;
  bool failDocs = false;
  bool openResult = false;
  int versionReads = 0;
  int docReads = 0;
  Completer<InstalledAppVersion>? pendingVersion;
  final links = <Uri>[];
  static const installed = InstalledAppVersion(
    name: '拉了么？',
    version: '9.8.7',
    build: '42',
    platform: 'iOS',
  );
  @override
  Future<InstalledAppVersion> readVersion() async {
    versionReads++;
    if (failVersion) throw StateError('Metadata unavailable');
    return pendingVersion?.future ?? installed;
  }

  @override
  Future<AppDocumentation> readDocumentation() async {
    docReads++;
    if (failDocs) throw StateError('Missing assets');
    return documentation;
  }

  @override
  Future<bool> open(Uri uri) async {
    links.add(uri);
    return openResult;
  }
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  late AppDocumentation bundled;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    bundled = await const DeviceAppInformation().readDocumentation();
  });
  Future<_Information> info() async => _Information(bundled);
  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> launch(
    WidgetTester tester,
    _Information data, {
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AboutScreen(information: data),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('help, privacy and version copy are usable at 320px / $scale', (
      tester,
    ) async {
      final data = await info();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await launch(tester, data, scale: scale);
      expect(find.text('版本 9.8.7（42）'), findsOneWidget);
      await tap(tester, find.byKey(const Key('about-copy-version')));
      expect(copied, _Information.installed.copyText);
      expect(find.text('版本信息已复制，不含记录内容'), findsOneWidget);
      await tap(tester, find.byKey(const Key('about-help')));
      await tap(tester, find.byKey(const PageStorageKey('help-backup')));
      expect(find.textContaining('相同记录会跳过'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('about-privacy')));
      expect(find.text('隐私与数据说明'), findsOneWidget);
      expect(find.textContaining('记录由你掌握'), findsOneWidget);
      expect(
        data.links,
        isEmpty,
      ); // Neither document loading nor version copying opens a network resource.
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('about-licenses')));
      expect(find.byType(LicensePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('package metadata failure can be retried without blocking help', (
    tester,
  ) async {
    final data = await info()
      ..failVersion = true;
    await launch(tester, data);
    expect(find.text('暂时无法读取版本'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('about-copy-version')))
          .onPressed,
      isNull,
    );
    await tap(tester, find.byKey(const Key('about-help')));
    expect(find.text('使用帮助'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    data.failVersion = false;
    await tester.scrollUntilVisible(
      find.byKey(const Key('about-version-retry')),
      -160,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, find.byKey(const Key('about-version-retry')));
    expect(find.text('版本 9.8.7（42）'), findsOneWidget);
    expect(data.versionReads, 2);
  });

  testWidgets(
    'late version read does not delay privacy access or update a disposed route',
    (tester) async {
      final data = await info();
      data.pendingVersion = Completer<InstalledAppVersion>();
      await launch(tester, data);
      await tap(tester, find.byKey(const Key('about-privacy')));
      expect(find.text('隐私与数据说明'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      data.pendingVersion!.complete(_Information.installed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('document errors retry instead of silently replacing policy', (
    tester,
  ) async {
    final data = await info()
      ..failDocs = true;
    await launch(tester, data);
    expect(find.text('使用说明暂时无法读取，其他功能仍可使用。'), findsOneWidget);
    expect(find.text('版本 9.8.7（42）'), findsOneWidget);
    data.failDocs = false;
    await tap(tester, find.byKey(const Key('about-docs-retry')));
    await tap(tester, find.byKey(const Key('about-privacy')));
    expect(find.text('隐私与数据说明'), findsOneWidget);
    expect(data.docReads, 2);
  });

  testWidgets(
    'configured support opens only its address and preserves a fallback',
    (tester) async {
      final data = await info();
      final support = Uri.parse('https://support.example.test/help');
      data.documentation = AppDocumentation(
        documents: data.documentation.documents,
        publishing: PublishingInfo(publisherName: '测试发布者', supportUrl: support),
      );
      await launch(tester, data);
      await tap(tester, find.byKey(const Key('about-support')));
      expect(data.links, [support]);
      expect(find.text(support.toString()), findsOneWidget);
      expect(find.text('未能打开，可选择下方地址复制后自行访问。'), findsOneWidget);
    },
  );

  testWidgets(
    'settings opens about and public documents stay inside the privacy gate',
    (tester) async {
      final now = DateTime(2026, 10, 9, 12);
      final log = BowelLogController(MemoryRepository(now), now: () => now);
      await log.initialize();
      final privacy = await unlockedPrivacy();
      final reminders = await quietReminders();
      await tester.pumpWidget(
        LaLeMaApp(controller: log, privacy: privacy, reminders: reminders),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const Key('today-settings')));
      await tester.tap(find.byKey(const Key('settings-about')));
      await tester.pump();
      // The production asset loader crosses the engine boundary. Let real I/O
      // finish instead of waiting only on the widget test's simulated clock.
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(find.text('帮助与关于'), findsOneWidget);
      await tap(tester, find.byKey(const Key('about-privacy')));
      expect(find.text('隐私与数据说明'), findsOneWidget);
      await privacy.setEnabled(true);
      privacy.lock();
      await tester.pumpAndSettle();
      expect(find.text('记录已锁定'), findsOneWidget);
      expect(find.text('隐私与数据说明'), findsNothing);
      expect(log.records, isEmpty);
      await tester.pumpWidget(const SizedBox());
      log.dispose();
      privacy.dispose();
      reminders.dispose();
    },
  );
}
