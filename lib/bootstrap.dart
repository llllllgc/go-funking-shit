import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'application/app_session.dart';
import 'data/privacy_services.dart';
import 'widgets/privacy_surface.dart';
import 'core/theme/app_theme.dart';

/// Paint immediately, even when opening storage fails. Retrying never deletes
/// or recreates an existing database.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.load,
    this.screen = const NativePrivacyScreen(),
    super.key,
  });
  final Future<AppSession> Function() load;
  final PrivacyScreenBridge screen;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  AppSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = await widget.load();
      if (!mounted) {
        session.dispose();
        return;
      }
      setState(() => _session = session);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrivacySurface(
      screen: widget.screen,
      child: _session != null
          ? LaLeMaApp(controller: _session!.log, privacy: _session!.privacy)
          : _startup(),
    );
  }

  Widget _startup() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('拉了么？', style: pixelStyle(size: 30)),
                  const SizedBox(height: 24),
                  if (_loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('正在打开本机记录…'),
                  ] else ...[
                    const Text('暂时无法打开应用', style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 12),
                    const Text(
                      '未能读取本机记录或确认隐私设置。请重试；不会清空已有记录。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
