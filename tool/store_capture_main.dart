// Debug-only display fixture for isolated simulators. Uses production widgets
// with in-memory synthetic records; never opens the application's SQLite log.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lalema/app.dart';
import 'package:lalema/application/bowel_log_controller.dart';
import 'package:lalema/application/privacy_controller.dart';
import 'package:lalema/application/reminder_controller.dart';
import 'package:lalema/core/theme/app_colors.dart';
import 'package:lalema/core/theme/app_theme.dart';
import 'package:lalema/data/app_information.dart';
import 'package:lalema/data/privacy_services.dart';
import 'package:lalema/data/reminder_service.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:lalema/screens/about_screen.dart';
import 'package:lalema/screens/data_screen.dart';
import 'package:lalema/screens/history_screen.dart';
import 'package:lalema/screens/knowledge_screen.dart';
import 'package:lalema/screens/record_screen.dart';
import 'package:lalema/screens/settings_screen.dart';
import 'package:lalema/widgets/privacy_gate.dart';
import 'package:lalema/widgets/privacy_surface.dart';
import '../test/support/memory_repository.dart';

String? _captureRenderError;

Future<void> main() async {
  if (kReleaseMode) throw StateError('Store capture fixture is debug-only');
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    _captureRenderError = details.exceptionAsString();
    previousErrorHandler?.call(details);
  };
  runApp(
    const PrivacySurface(screen: NativePrivacyScreen(), child: _Capture()),
  );
}

class _CaptureLock implements AppLockStore {
  bool enabled = false;
  @override
  Future<bool> readLockEnabled() async => enabled;
  @override
  Future<void> writeLockEnabled(bool value) async {
    enabled = value;
  }
}

class _Capture extends StatefulWidget {
  const _Capture();
  @override
  State<_Capture> createState() => _CaptureState();
}

class _CaptureState extends State<_Capture> {
  BowelLogController? log;
  PrivacyController? privacy;
  ReminderController? reminders;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime(2026, 10, 9, 9, 41);
      final repository = MemoryRepository(now);
      for (var day = 0; day < 6; day++) {
        final occurred = DateTime(now.year, now.month, now.day - day, 9, 10);
        repository.records.add(
          BowelRecord(
            recordId: 'demo-$day',
            bristolType: [4, 3, 4, 5, 4, 3][day],
            recordedAt: occurred,
            updatedAt: occurred,
            details: RecordDetails(
              note: day == 0 ? '示例：早餐后' : '',
              discomfortMask: day == 3 ? 2 : 0,
            ),
          ),
        );
      }
      final nextPrivacy = PrivacyController(
        store: _CaptureLock(),
        auth: SystemDeviceAuthenticator(),
        screen: const NativePrivacyScreen(),
      );
      await nextPrivacy.initialize();
      final nextLog = BowelLogController(repository, now: () => now);
      await nextLog.initialize();
      final nextReminders = ReminderController(const NativeReminderService());
      await nextReminders.refresh();
      if (!mounted) {
        nextPrivacy.dispose();
        nextLog.dispose();
        nextReminders.dispose();
        return;
      }
      setState(() {
        privacy = nextPrivacy;
        log = nextLog;
        reminders = nextReminders;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _writeMetadata());
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _writeMetadata() async {
    const service = DeviceAppInformation();
    final version = await service.readVersion();
    final documentation = await service.readDocumentation();
    await File(
      '${Directory.systemTemp.path}/lalema-capture-version.json',
    ).writeAsString(
      jsonEncode({
        'version': version.version,
        'build': version.build,
        'name': version.name,
        'platform': version.platform,
        'documentsUpdatedOn': documentation.documents.updatedOn,
        'publisherContactProvided':
            documentation.publishing.hasPublisherContact,
        'syntheticRecords': true,
        'renderError': _captureRenderError,
        'viewPaddingTop':
            WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .viewPadding
                .top /
            WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .devicePixelRatio,
        'screen': const String.fromEnvironment(
          'CAPTURE_SCREEN',
          defaultValue: 'today',
        ),
      }),
      flush: true,
    );
  }

  void _noop() {}
  @override
  void dispose() {
    log?.dispose();
    privacy?.dispose();
    reminders?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (log == null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(error ?? 'Preparing synthetic screenshots…'),
          ),
        ),
      );
    }
    const screen = String.fromEnvironment(
      'CAPTURE_SCREEN',
      defaultValue: 'today',
    );
    if (screen == 'today') {
      return LaLeMaApp(
        controller: log!,
        privacy: privacy!,
        reminders: reminders!,
      );
    }
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.paper,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    final Widget home = switch (screen) {
      'record' => RecordScreen(controller: log!),
      'history' => HistoryScreen(
        controller: log!,
        onToday: _noop,
        onRecord: _noop,
        onEdit: (_) {},
        onCalendar: _noop,
        onBackfill: _noop,
        onData: _noop,
      ),
      'data' => DataScreen(controller: log!, privacy: privacy!),
      'settings' => SettingsScreen(
        privacy: privacy!,
        reminders: reminders!,
        onData: _noop,
      ),
      'knowledge' => KnowledgeScreen(controller: log!),
      'about' => const AboutScreen(),
      _ => throw ArgumentError('Unknown capture screen'),
    };
    return MaterialApp(
      key: ValueKey('capture-$screen'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          PrivacyGate(controller: privacy!, child: child!),
      initialRoute: '/capture',
      routes: {'/': (_) => const Scaffold(), '/capture': (_) => home},
    );
  }
}
