import 'package:flutter/material.dart';

import '../application/privacy_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Above Navigator: record forms, dialogs and data previews are all covered.
/// Offstage preserves drafts but removes painting, pointer input and semantics.
class PrivacyGate extends StatefulWidget {
  const PrivacyGate({required this.controller, required this.child, super.key});
  final PrivacyController controller;
  final Widget child;
  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_privacyChanged);
    widget.controller.lifecycleChanged(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  void _privacyChanged() {
    if (widget.controller.concealed) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void didUpdateWidget(PrivacyGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_privacyChanged);
      widget.controller.addListener(_privacyChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_privacyChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    widget.controller.lifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final privacy = widget.controller;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: privacy.concealed,
            child: ExcludeFocus(
              excluding: privacy.concealed,
              child: TickerMode(
                enabled: !privacy.concealed,
                child: widget.child,
              ),
            ),
          ),
          if (privacy.concealed)
            Material(
              color: AppColors.paper,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 40,
                            color: AppColors.mossInk,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            privacy.fault ? '隐私设置暂不可用' : '记录已锁定',
                            style: pixelStyle(size: 26),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text('通过设备验证后继续。', textAlign: TextAlign.center),
                          if (privacy.message != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  privacy.message!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (privacy.busy)
                            const CircularProgressIndicator()
                          else
                            FilledButton(
                              key: const Key('privacy-unlock'),
                              onPressed: privacy.fault
                                  ? privacy.retrySettings
                                  : privacy.unlock,
                              child: Text(privacy.fault ? '重试隐私设置' : '解锁记录'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
