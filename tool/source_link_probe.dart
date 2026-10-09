// Isolated simulator probe: opens one bundled public source URL through the
// production adapter. It never initializes or reads the log database.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lalema/data/knowledge_base.dart';
import 'package:lalema/data/privacy_services.dart';
import 'package:lalema/data/source_links.dart';
import 'package:lalema/widgets/privacy_surface.dart';

void main() {
  if (kReleaseMode) throw StateError('Source link probe is debug-only');
  runApp(
    const PrivacySurface(
      screen: NativePrivacyScreen(),
      child: MaterialApp(home: _Probe()),
    ),
  );
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String _status = 'Source link QA — no log data';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final result = <String, Object>{
      'url': KnowledgeBase.fiberDiet.url,
      'platform': Platform.operatingSystem,
      'opened': false,
    };
    try {
      result['opened'] = await const ExternalSourceLinks().open(
        KnowledgeBase.fiberDiet,
      );
    } catch (error) {
      result['error'] = error.toString();
    }
    await File(
      '${Directory.systemTemp.path}/lalema-source-link-result.json',
    ).writeAsString(jsonEncode(result), flush: true);
    if (mounted) setState(() => _status = jsonEncode(result));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SelectableText(_status),
      ),
    ),
  );
}
