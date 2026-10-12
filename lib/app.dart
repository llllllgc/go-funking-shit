import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/bowel_log_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'domain/history_filter.dart';
import 'screens/history_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/knowledge_screen.dart';
import 'screens/record_screen.dart';
import 'screens/today_screen.dart';
import 'widgets/ticket_bottom_bar.dart';

class LaLeMaApp extends StatelessWidget {
  const LaLeMaApp({required this.controller, super.key});

  final BowelLogController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '拉了么？',
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LaLeMaShell(controller: controller),
    );
  }
}

class LaLeMaShell extends StatefulWidget {
  const LaLeMaShell({required this.controller, super.key});

  final BowelLogController controller;

  @override
  State<LaLeMaShell> createState() => _LaLeMaShellState();
}

class _LaLeMaShellState extends State<LaLeMaShell> with WidgetsBindingObserver {
  int _page = 0;
  Timer? _dateTimer;
  RecordFeedback? _lastFeedback;
  HistoryFilter _historyFilter = const HistoryFilter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_showRecordFeedback);
    _dateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => widget.controller.refreshDate(),
    );
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_showRecordFeedback);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LaLeMaShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_showRecordFeedback);
      widget.controller.addListener(_showRecordFeedback);
      _lastFeedback = null;
    }
  }

  void _showRecordFeedback() {
    final controller = widget.controller;
    final feedback = controller.feedback;
    if (feedback == null || identical(feedback, _lastFeedback)) return;
    _lastFeedback = feedback;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(controller.feedback, feedback)) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger
          .showSnackBar(
            SnackBar(
              duration: Duration(seconds: feedback.action == null ? 3 : 8),
              persist:
                  feedback.action != null &&
                  MediaQuery.accessibleNavigationOf(context),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                ticketBottomBarHeight + 12,
              ),
              elevation: 0,
              backgroundColor: AppColors.paperRaised,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: AppColors.rule),
              ),
              content: Text(
                feedback.message,
                style: TextStyle(
                  color: controller.errorMessage == null
                      ? AppColors.ink
                      : AppColors.danger,
                  fontSize: 14,
                ),
              ),
              action: feedback.action == null
                  ? null
                  : SnackBarAction(
                      key: const Key('record-feedback-action'),
                      label: feedback.action == RecordFeedbackAction.undo
                          ? '撤销'
                          : '恢复',
                      textColor: AppColors.mossInk,
                      onPressed: () {
                        final id = feedback.recordId!;
                        if (feedback.action == RecordFeedbackAction.undo) {
                          controller.undo(id);
                        } else {
                          controller.restoreDeletedRecord(id);
                        }
                      },
                    ),
            ),
          )
          .closed
          .then((reason) {
            if (mounted && reason != SnackBarClosedReason.action) {
              controller.dismissFeedback(feedback);
            }
          });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refreshDate();
  }

  Future<DateTime?> _openRecord({
    String? recordId,
    DateTime? initialDate,
  }) async {
    widget.controller.clearFeedback();
    return Navigator.of(context).push<DateTime>(
      MaterialPageRoute<DateTime>(
        builder: (_) => RecordScreen(
          controller: widget.controller,
          editRecordId: recordId,
          initialDate: initialDate,
        ),
      ),
    );
  }

  Future<void> _openCalendar(DateTime date) async {
    widget.controller.refreshDate();
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
    widget.controller.clearFeedback();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KnowledgeScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _backfillYesterday() async {
    final now = widget.controller.now;
    await _openRecord(initialDate: DateTime(now.year, now.month, now.day - 1));
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
        onHistory: () => setState(() => _page = 1),
        onEdit: (id) => _openRecord(recordId: id),
        onCalendar: _openCalendar,
        onKnowledge: _openKnowledge,
      );
    }
    return HistoryScreen(
      controller: widget.controller,
      onToday: () => setState(() => _page = 0),
      onRecord: () => _openRecord(),
      onEdit: (id) => _openRecord(recordId: id),
      onCalendar: () => _openCalendar(widget.controller.currentDate),
      onBackfill: _backfillYesterday,
      initialFilter: _historyFilter,
      onFilterChanged: (filter) => _historyFilter = filter,
    );
  }
}
