import 'package:lalema/widgets/privacy_surface.dart';
import 'package:lalema/data/privacy_services.dart';
// Debug-only entry point for an isolated simulator. It never loads the app's
// database and only offers an empty, synthetic archive to the document picker.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lalema/data/backup_files.dart';
import 'package:lalema/data/record_archive.dart';

void main() {
  if (kReleaseMode) throw StateError('File dialog probe is debug-only');
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
  String _status = 'Isolated file dialog QA — no user data';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  Future<void> _probe() async {
    const files = DeviceBackupFiles();
    try {
      // Let the native root view finish presentation before requesting a sheet.
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      const mode = String.fromEnvironment(
        'FILE_DIALOG_PROBE',
        defaultValue: 'save',
      );
      if (mode == 'pick') {
        final bytes = await files.pickBackup();
        if (mounted) {
          setState(
            () => _status = bytes == null
                ? 'Picker cancelled'
                : 'Read ${bytes.length} bytes',
          );
        }
      } else {
        final saved = await files.save(
          name: 'lalema-qa-empty-backup.json',
          bytes: RecordArchiveCodec.encode(
            RecordArchive(records: [], exportedAt: DateTime.now()),
          ),
          mimeType: 'application/json',
        );
        if (mounted) {
          setState(() => _status = saved ? 'File saved' : 'Save cancelled');
        }
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Probe failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(_status)));
}
