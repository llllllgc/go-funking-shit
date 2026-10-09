// Isolated iOS simulator probe. No database or health data is loaded. Launch a
// different simulator app and then resume this app to exercise a native cover.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const channel = MethodChannel('lalema/privacy_screen');
void main() {
  if (kReleaseMode) throw StateError('Privacy probe is debug-only');
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with WidgetsBindingObserver {
  int? _oldEpoch;
  bool _interrupted = false;
  bool _running = false;
  final _events = <Map<String, Object?>>[];
  Future<void> _logging = Future.value();
  void _event(String name, [Object? value]) {
    _events.add({'event': name, 'value': value});
    _logging = _logging
        .then(
          (_) => File(
            '${Directory.systemTemp.path}/lalema-privacy-events.json',
          ).writeAsString(jsonEncode(_events)),
        )
        .then((_) {});
  }

  String _status = 'Synthetic privacy probe — no health records';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initial());
  }

  Future<void> _initial() async {
    _event('initial-start');
    _oldEpoch = await channel.invokeMethod<int>('foregroundEpoch');
    _event('initial-epoch', _oldEpoch);
    if (_oldEpoch != null) {
      await channel.invokeMethod<void>('frameReady', _oldEpoch);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _event('lifecycle', state.name);
    if (_oldEpoch != null &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _interrupted = true;
    }
    if (state == AppLifecycleState.resumed &&
        !_interrupted &&
        _oldEpoch == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initial());
      WidgetsBinding.instance.scheduleFrame();
    }
    if (state == AppLifecycleState.resumed && _interrupted && !_running) {
      _running = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  Future<void> _verify() async {
    try {
      _event('verify-start');
      final epoch = await channel.invokeMethod<int>('foregroundEpoch');
      _event('verify-epoch', epoch);
      if (epoch == null) throw StateError('foreground not ready');
      final before = await channel.invokeMapMethod<String, dynamic>(
        'debugStatus',
      );
      await channel.invokeMethod<void>('frameReady', _oldEpoch ?? -1);
      final stale = await channel.invokeMapMethod<String, dynamic>(
        'debugStatus',
      );
      await channel.invokeMethod<void>('frameReady', epoch);
      final after = await channel.invokeMapMethod<String, dynamic>(
        'debugStatus',
      );
      final passed =
          before?['covered'] == true &&
          stale?['covered'] == true &&
          after?['covered'] == false &&
          _oldEpoch != null &&
          epoch > _oldEpoch!;
      final result = {
        'passed': passed,
        'previousEpoch': _oldEpoch,
        'currentEpoch': epoch,
        'before': before,
        'afterStale': stale,
        'afterFresh': after,
      };
      // Only synthetic diagnostics in this probe's application sandbox.
      await File(
        '${Directory.systemTemp.path}/lalema-privacy-probe.json',
      ).writeAsString(jsonEncode(result));
      if (mounted) {
        setState(
          () => _status = passed
              ? 'Native privacy cover PASS'
              : 'Native privacy cover FAILED',
        );
      }
    } catch (error) {
      _event('error', error.toString());
      await File(
        '${Directory.systemTemp.path}/lalema-privacy-probe.json',
      ).writeAsString(jsonEncode({'passed': false, 'error': error.toString()}));
      if (mounted) setState(() => _status = 'Probe failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(_status)));
}
