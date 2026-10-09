import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/data/backup_files.dart';

final class LocalPickedFile extends PlatformFile {
  LocalPickedFile(this.file);
  final File file;
  @override
  Uri get uri => file.uri;
  @override
  String get name => file.uri.pathSegments.last;
  @override
  int? lengthSync() => file.lengthSync();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PickerSpy extends FilePickerPlatform {
  PlatformFile? selected;
  bool cancelled = false;
  int broadClears = 0;
  bool failCleanup = false;
  FileType? requestedType;
  List<String>? extensions;
  String? mime;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requestedType = type;
    extensions = allowedExtensions;
    return selected;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    mime = mimeType;
    await File('${Directory.systemTemp.path}/$fileName').writeAsBytes(bytes);
    return cancelled ? null : Uri.parse('content://documents/selected-output');
  }

  @override
  Future<void> clearTemporaryFiles() async {
    broadClears++;
    if (failCleanup) throw StateError('cleanup failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FilePickerPlatform previous;
  late PickerSpy picker;
  late Directory temporary;
  setUp(() async {
    previous = FilePickerPlatform.instance;
    picker = PickerSpy();
    FilePickerPlatform.instance = picker;
    temporary = await Directory.systemTemp.createTemp('lalema-picker-');
  });
  tearDown(() async {
    FilePickerPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
    await temporary.delete(recursive: true);
  });

  test(
    'iOS import reads bytes and only removes its selected temporary copy',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final input = await File(
        '${temporary.path}/selected.json',
      ).writeAsBytes([1, 2, 3]);
      final neighbor = await File(
        '${temporary.path}/unrelated',
      ).writeAsString('keep');
      picker.selected = LocalPickedFile(input);
      expect(await const DeviceBackupFiles().pickBackup(), [1, 2, 3]);
      expect(picker.requestedType, FileType.custom);
      expect(picker.extensions, ['json']);
      expect(await input.exists(), isFalse);
      expect(await neighbor.readAsString(), 'keep');
      expect(picker.broadClears, 0);
    },
  );

  test(
    'iOS import never deletes an original file outside the temp boundary',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final outside = await Directory('build').createTemp('backup-source-');
      try {
        final input = await File(
          '${outside.path}/original.json',
        ).writeAsBytes([4, 5, 6]);
        picker.selected = LocalPickedFile(input);
        expect(await const DeviceBackupFiles().pickBackup(), [4, 5, 6]);
        expect(await input.readAsBytes(), [4, 5, 6]);
      } finally {
        await outside.delete(recursive: true);
      }
    },
  );

  test(
    'native save keeps cancellation distinct and cleans only its staging file',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final name = 'lalema-test-${DateTime.now().microsecondsSinceEpoch}.json';
      final staging = File('${Directory.systemTemp.path}/$name');
      final files = const DeviceBackupFiles();
      expect(
        await files.save(
          name: name,
          bytes: Uint8List.fromList([1]),
          mimeType: 'application/json',
        ),
        isTrue,
      );
      expect(picker.mime, 'application/json');
      expect(await staging.exists(), isFalse);
      picker.cancelled = true;
      expect(
        await files.save(
          name: name,
          bytes: Uint8List.fromList([1]),
          mimeType: 'application/json',
        ),
        isFalse,
      );
      expect(await staging.exists(), isFalse);
      expect(picker.broadClears, 0);
      await expectLater(
        files.save(
          name: '../unsafe',
          bytes: Uint8List(0),
          mimeType: 'application/json',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'Android cache cleanup error does not turn a completed save into failure',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      picker.failCleanup = true;
      final name = 'lalema-test-${DateTime.now().microsecondsSinceEpoch}.json';
      try {
        expect(
          await const DeviceBackupFiles().save(
            name: name,
            bytes: Uint8List(0),
            mimeType: 'application/json',
          ),
          isTrue,
        );
        expect(picker.broadClears, 1);
      } finally {
        await File('${Directory.systemTemp.path}/$name').delete();
      }
    },
  );
}
