import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/data/knowledge_base.dart';
import 'package:lalema/data/source_links.dart';
import 'package:lalema/domain/knowledge_tip.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test(
    'every educational article has dated, canonical primary-source links',
    () {
      final ids = <String>{};
      final sources = <String, String>{};
      const hosts = {
        'www.niddk.nih.gov',
        'medlineplus.gov',
        'www.nhs.uk',
        'www.plymouthhospitals.nhs.uk',
      };
      for (final tip in KnowledgeBase.tips) {
        expect(
          ids.add(tip.id),
          isTrue,
          reason: 'Article IDs must remain unique',
        );
        expect(tip.sources, isNotEmpty, reason: tip.id);
        for (final source in tip.sources) {
          final uri = Uri.parse(source.url);
          expect(uri.scheme, 'https');
          expect(hosts, contains(uri.host));
          expect(uri.userInfo, isEmpty);
          expect(uri.hasQuery, isFalse);
          expect(DateTime.tryParse(source.checkedOn), isNotNull);
          expect(source.title, isNotEmpty);
          expect(source.organization, isNotEmpty);
          if (sources.containsKey(source.id)) {
            expect(sources[source.id], source.url);
          }
          sources[source.id] = source.url;
        }
      }
    },
  );

  test('featured cards are observational shape topics for all inputs', () {
    for (final type in [null, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8]) {
      expect(KnowledgeBase.featuredFor(type).category, KnowledgeCategory.shape);
    }
    expect(KnowledgeBase.featuredFor(1).id, 'bristol-firm');
    expect(KnowledgeBase.featuredFor(7).id, 'bristol-loose');
    expect(KnowledgeBase.featuredFor(null).id, 'bristol-middle');
  });

  test('launcher uses external browser with the public URL only', () async {
    Uri? received;
    LaunchMode? mode;
    final links = ExternalSourceLinks(
      launcher: (uri, launchMode) async {
        received = uri;
        mode = launchMode;
        return true;
      },
    );
    expect(await links.open(KnowledgeBase.bristol), isTrue);
    expect(received.toString(), KnowledgeBase.bristol.url);
    expect(received!.query, isEmpty);
    expect(mode, LaunchMode.externalApplication);
    for (final url in [
      'file:///private/log.db',
      'javascript:alert(1)',
      'https://user:pass@example.com',
    ]) {
      received = null;
      expect(
        await links.open(
          KnowledgeSource(
            id: 'invalid',
            organization: '',
            title: '',
            url: url,
            checkedOn: '2026-10-09',
          ),
        ),
        isFalse,
      );
      expect(received, isNull);
    }
  });
}
