import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/data/app_information.dart';
import 'package:lalema/domain/app_documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled documents load offline independently of package metadata',
    () async {
      final result = await const DeviceAppInformation().readDocumentation();
      expect(result.documents.privacy.sections, isNotEmpty);
      expect(
        result.documents.help.sections.map((item) => item.id),
        containsAll(['backup', 'undo', 'lock', 'reminders']),
      );
      expect(result.documents.changes.sections, isNotEmpty);
    },
  );

  test('missing publication identity stays absent, rather than fabricated', () {
    final value = PublishingInfo.fromJson({'schemaVersion': 1});
    expect(value.publisherName, isNull);
    expect(value.supportUrl, isNull);
    expect(value.hasPublisherContact, isFalse);
    expect(value.hasPublicPolicyUrl, isFalse);
  });

  test(
    'malformed documents are rejected rather than showing partial privacy text',
    () {
      final source =
          jsonDecode(
                File('assets/content/app_documents.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        () => AppDocuments.fromJson({...source, 'schemaVersion': 5}),
        throwsFormatException,
      );
      expect(
        () => AppDocuments.fromJson({...source, 'updatedOn': '2026-02-30'}),
        throwsFormatException,
      );
      final privacy = source['privacy'] as Map<String, dynamic>;
      final first = (privacy['sections'] as List).first;
      expect(
        () => AppDocuments.fromJson({
          ...source,
          'privacy': {
            ...privacy,
            'sections': [first, first],
          },
        }),
        throwsFormatException,
      );
      expect(
        () => AppDocuments.fromJson({
          ...source,
          'privacy': {'title': '隐私', 'sections': []},
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'support accepts web and plain email but rejects credential or local links',
    () {
      for (final address in [
        'https://support.example.test/help',
        'mailto:help@example.test',
      ]) {
        final value = PublishingInfo.fromJson({
          'schemaVersion': 1,
          'publisherName': '测试发布者',
          'supportUrl': address,
        });
        expect(value.hasPublisherContact, isTrue);
      }
      for (final address in [
        'file:///private/records.db',
        'http://example.test',
        'javascript:alert(1)',
        'https://user:pass@example.test',
        'mailto:help@example.test?body=anything',
        'mailto:@',
        'mailto:help@',
        'mailto://host/help@example.test',
      ]) {
        expect(
          () => PublishingInfo.fromJson({
            'schemaVersion': 1,
            'supportUrl': address,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => PublishingInfo.fromJson({
          'schemaVersion': 1,
          'privacyPolicyUrl': 'mailto:help@example.test',
        }),
        throwsFormatException,
      );
    },
  );

  test('copied version data consists only of app and platform metadata', () {
    const info = InstalledAppVersion(
      name: '拉了么？',
      version: '9.8.7',
      build: '42',
      platform: 'iOS',
    );
    expect(info.copyText, '拉了么？\n版本：9.8.7（42）\n平台：iOS');
  });
}
