import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/widgets/privacy_gate.dart';
import 'package:lalema/widgets/privacy_surface.dart';

import 'support/memory_repository.dart';
import 'support/privacy_fakes.dart';

class DelayedScreen extends FakePrivacyScreen {
  final epoch = Completer<int?>();
  @override
  Future<int?> foregroundEpoch() => epoch.future;
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  late MemoryLockStore store;
  late FakeAuthenticator auth;
  late FakePrivacyScreen screen;
  late PrivacyController privacy;
  setUp(() {
    store = MemoryLockStore();
    auth = FakeAuthenticator();
    screen = FakePrivacyScreen();
    privacy = PrivacyController(store: store, auth: auth, screen: screen);
  });
  tearDown(() {
    privacy.dispose();
  });

  testWidgets(
    'cold lock hides record text and semantics until verification succeeds',
    (tester) async {
      final semantics = tester.ensureSemantics();
      store.enabled = true;
      await privacy.initialize();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              PrivacyGate(controller: privacy, child: child!),
          home: const Scaffold(body: Text('secret-record-note')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录已锁定'), findsOneWidget);
      expect(find.text('secret-record-note'), findsNothing);
      expect(find.bySemanticsLabel('secret-record-note'), findsNothing);
      auth.success = false;
      await tester.tap(find.byKey(const Key('privacy-unlock')));
      await tester.pumpAndSettle();
      expect(find.text('secret-record-note'), findsNothing);
      auth.success = true;
      await tester.tap(find.byKey(const Key('privacy-unlock')));
      await tester.pumpAndSettle();
      expect(find.text('secret-record-note'), findsOneWidget);
      expect(find.bySemanticsLabel('secret-record-note'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'locking preserves a pushed form but removes its focus and accessibility',
    (tester) async {
      store.enabled = true;
      await privacy.initialize();
      await privacy.unlock();
      final text = TextEditingController(text: 'private draft');
      addTearDown(text.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) =>
              PrivacyGate(controller: privacy, child: child!),
          home: const Scaffold(body: Text('home')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: TextField(
              key: const Key('private-form'),
              controller: text,
              focusNode: focus,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('private-form')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      privacy.lock();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(find.byKey(const Key('private-form')), findsNothing);
      expect(text.text, 'private draft');
      await tester.tap(find.byKey(const Key('privacy-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('private-form')), findsOneWidget);
      expect(text.text, 'private draft');
    },
  );

  testWidgets(
    'lifecycle covers content then requires reauthentication after background',
    (tester) async {
      store.enabled = true;
      await privacy.initialize();
      await privacy.unlock();
      await tester.pumpWidget(
        PrivacySurface(
          screen: screen,
          child: MaterialApp(
            builder: (context, child) =>
                PrivacyGate(controller: privacy, child: child!),
            home: const Scaffold(body: Text('private content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('private content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('private content'), findsNothing);
      expect(find.text('记录已锁定'), findsOneWidget);
      expect(screen.frames, greaterThan(0));
      await tester.tap(find.byKey(const Key('privacy-unlock')));
      await tester.pumpAndSettle();
      expect(find.text('private content'), findsOneWidget);
    },
  );

  testWidgets(
    'late foreground acknowledgements are dropped after another pause',
    (tester) async {
      final native = DelayedScreen();
      await tester.pumpWidget(
        PrivacySurface(
          screen: native,
          child: const MaterialApp(home: Text('private content')),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      native.epoch.complete(1);
      await tester.pump();
      expect(native.frames, 0);
      expect(find.text('private content'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(native.frames, 1);
    },
  );

  testWidgets(
    'settings enable, manual lock and verified disable work at large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await privacy.initialize();
      final controller = BowelLogController(
        MemoryRepository(DateTime(2026, 10, 9)),
      );
      await controller.initialize();
      await tester.pumpWidget(
        LaLeMaApp(controller: controller, privacy: privacy),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('today-settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-app-lock')),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-app-lock')));
      await tester.pumpAndSettle();
      expect(store.enabled, isTrue);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-lock-now')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-lock-now')));
      await tester.pumpAndSettle();
      expect(find.text('记录已锁定'), findsOneWidget);
      await tester.tap(find.byKey(const Key('privacy-unlock')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-app-lock')),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-app-lock')));
      await tester.pumpAndSettle();
      expect(store.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
