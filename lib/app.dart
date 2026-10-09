import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/bowel_log_controller.dart';
import 'core/formatters.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/history_screen.dart';
import 'screens/data_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/knowledge_screen.dart';
import 'screens/record_screen.dart';
import 'screens/today_screen.dart';
import 'domain/history_filter.dart';
import 'application/privacy_controller.dart';
import 'widgets/privacy_gate.dart';
import 'screens/settings_screen.dart';

class LaLeMaApp extends StatelessWidget {
  const LaLeMaApp({required this.controller, required this.privacy, super.key});

  final BowelLogController controller;
  final PrivacyController privacy;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '拉了么？',
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          PrivacyGate(controller: privacy, child: child!),
      home: LaLeMaShell(controller: controller, privacy: privacy),
    );
  }
}

class LaLeMaShell extends StatefulWidget {
  const LaLeMaShell({
    required this.controller,
    required this.privacy,
    super.key,
  });

  final BowelLogController controller;
  final PrivacyController privacy;

  @override
  State<LaLeMaShell> createState() => _LaLeMaShellState();
}

class _LaLeMaShellState extends State<LaLeMaShell> with WidgetsBindingObserver {
  int _page = 0;
  HistoryFilter _historyFilter = const HistoryFilter();
  Timer? _dateTimer;
  Timer? _clockCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDateRefresh();
    // Keep detecting foreground clock/time-zone changes; the midnight timer
    // avoids waiting for this fallback when a normal day boundary is crossed.
    _clockCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      widget.controller.refreshDate();
      _scheduleDateRefresh();
    });
  }

  void _scheduleDateRefresh() {
    _dateTimer?.cancel();
    final now = widget.controller.now;
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _dateTimer = Timer(
      midnight.difference(now) + const Duration(milliseconds: 1),
      () {
        if (!mounted) return;
        widget.controller.refreshDate();
        _scheduleDateRefresh();
      },
    );
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    _clockCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshDate();
      _scheduleDateRefresh();
    }
  }

  Future<DateTime?> _openRecord({
    String? recordId,
    DateTime? initialDate,
  }) async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    widget.controller.clearFeedback();
    final savedAt = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(
        builder: (_) => RecordScreen(
          controller: widget.controller,
          editRecordId: recordId,
          initialDate: initialDate,
        ),
      ),
    );
    if (savedAt != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已保存 ${formatTime(savedAt)}')));
    }
    return savedAt;
  }

  Future<void> _openCalendar(DateTime date) async {
    widget.controller.refreshDate();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    widget.controller.clearFeedback();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalendarScreen(
          controller: widget.controller,
          initialDate: date,
          onBackfill: (date) => _openRecord(initialDate: date),
          onEdit: (id) => _openRecord(recordId: id),
        ),
      ),
    );
  }

  Future<void> _openKnowledge() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    widget.controller.clearFeedback();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openData() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    widget.controller.clearFeedback();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DataScreen(controller: widget.controller, privacy: widget.privacy),
      ),
    );
  }

  Future<void> _openSettings() async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SettingsScreen(privacy: widget.privacy, onData: _openData),
      ),
    );
  }

  Future<void> _backfillYesterday() async {
    final now = widget.controller.now;
    await _openRecord(initialDate: DateTime(now.year, now.month, now.day - 1));
  }

  void _selectPage(int page) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    widget.controller.clearFeedback();
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.paper,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.paper,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    if (_page == 0) {
      return TodayScreen(
        controller: widget.controller,
        onRecord: () => _openRecord(),
        onHistory: () => _selectPage(1),
        onEdit: (id) => _openRecord(recordId: id),
        onCalendar: _openCalendar,
        onKnowledge: _openKnowledge,
        onSettings: _openSettings,
      );
    }
    return HistoryScreen(
      controller: widget.controller,
      onToday: () => _selectPage(0),
      onRecord: () => _openRecord(),
      onEdit: (id) => _openRecord(recordId: id),
      onCalendar: () => _openCalendar(widget.controller.currentDate),
      onBackfill: _backfillYesterday,
      onData: _openData,
      initialFilter: _historyFilter,
      onFilterChanged: (value) => _historyFilter = value,
    );
  }
}
