import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'application/bowel_log_controller.dart';
import 'core/theme/app_theme.dart';

/// Paint immediately, even when opening storage fails. Retrying never deletes
/// or recreates an existing database.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({required this.load, super.key});
  final Future<BowelLogController> Function() load;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  BowelLogController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final controller = await widget.load();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return LaLeMaApp(controller: _controller!);
    return MaterialApp(
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
                      const Text('暂时无法读取记录', style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 12),
                      const Text(
                        '请检查设备剩余空间，然后重试。重试不会清空已有记录。',
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
}
