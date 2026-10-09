import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/application/reminder_controller.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/data/reminder_service.dart';
import 'package:lalema/widgets/reminder_settings.dart';
import 'support/reminder_fakes.dart';

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'reminder permission, retry and time controls fit text scale $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final service = FakeReminderService()
          ..requestedPermission = ReminderPermission.denied;
        final controller = ReminderController(service);
        await controller.refresh();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [ReminderSettings(controller: controller)],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(service.requests, 0);
        await tester.tap(find.byKey(const Key('reminder-enabled')));
        await tester.pumpAndSettle();
        expect(find.text('已关闭'), findsOneWidget);
        expect(service.configurations, 0);
        await tester.ensureVisible(
          find.byKey(const Key('reminder-system-settings')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reminder-system-settings')));
        await tester.pumpAndSettle();
        expect(service.settingsOpened, 1);
        service.permission = ReminderPermission.allowed;
        await controller.refresh();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('reminder-enabled')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reminder-enabled')));
        await tester.pumpAndSettle();
        expect(service.enabled, isTrue);
        await tester.ensureVisible(find.byKey(const Key('reminder-time')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reminder-time')));
        await tester.pumpAndSettle();
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(service.hour, 20);
        service.failConfigure = true;
        await tester.ensureVisible(find.byKey(const Key('reminder-enabled')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reminder-enabled')));
        await tester.pumpAndSettle();
        expect(controller.uncertain, isTrue);
        expect(find.text('状态待确认'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('reminder-retry')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('reminder-retry')));
        await tester.pumpAndSettle();
        expect(controller.uncertain, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  testWidgets(
    'restored enabled preference offers explicit permission request',
    (tester) async {
      final service = FakeReminderService()..enabled = true;
      final controller = ReminderController(service);
      await controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReminderSettings(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      expect(find.text('系统通知未允许，暂时不会提醒'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('reminder-allow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder-allow')));
      await tester.pumpAndSettle();
      expect(service.requests, 1);
      expect(controller.state!.scheduled, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
