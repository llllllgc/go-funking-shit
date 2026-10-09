import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'record_archive.dart';

abstract interface class BackupFiles {
  Future<Uint8List?> pickBackup();
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  });
}

class DeviceBackupFiles implements BackupFiles {
  const DeviceBackupFiles();

  @override
  Future<Uint8List?> pickBackup() async {
    String? temporaryPath;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: '选择拉了么备份',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return null;
      temporaryPath = file.path;
      if ((file.lengthSync() ?? 0) > RecordArchiveCodec.maxBytes) {
        throw const ArchiveException('文件超过 32 MB，请选择较小的备份。');
      }
      return await readBoundedBytes(file.readAsByteStream());
    } finally {
      await _clearCache(temporaryPath);
    }
  }

  @override
  Future<bool> save({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (path.basename(name) != name || !name.startsWith('lalema-')) {
      throw ArgumentError('Invalid export name');
    }
    try {
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: '保存文件',
      );
      return uri != null;
    } finally {
      await _clearCache(path.join(Directory.systemTemp.path, name));
    }
  }

  Future<void> _clearCache(String? temporaryPath) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android implementation only removes its own file_picker cache.
        await FilePicker.clearTemporaryFiles();
      } else if (defaultTargetPlatform == TargetPlatform.iOS &&
          temporaryPath != null) {
        // The plugin's iOS "clear" deletes the entire app temp directory.
        // Delete only this operation's file inside that directory instead.
        final file = File(temporaryPath);
        if (!await file.exists()) return;
        final directory = await Directory.systemTemp.resolveSymbolicLinks();
        final resolved = await file.resolveSymbolicLinks();
        if (path.isWithin(directory, resolved)) await file.delete();
      }
    } catch (_) {
      /* Cleanup must not misreport a successful save. */
    }
  }
}

Future<Uint8List> readBoundedBytes(Stream<Uint8List> stream) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > RecordArchiveCodec.maxBytes) {
      throw const ArchiveException('文件超过 32 MB，请选择较小的备份。');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
