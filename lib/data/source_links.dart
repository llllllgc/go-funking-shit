import 'package:url_launcher/url_launcher.dart';

import '../domain/knowledge_tip.dart';

abstract interface class SourceLinks {
  Future<bool> open(KnowledgeSource source);
}

typedef SourceUrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

class ExternalSourceLinks implements SourceLinks {
  const ExternalSourceLinks({this.launcher = _launch});
  final SourceUrlLauncher launcher;
  static Future<bool> _launch(Uri uri, LaunchMode mode) =>
      launchUrl(uri, mode: mode);

  @override
  Future<bool> open(KnowledgeSource source) async {
    final uri = Uri.tryParse(source.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    // Only the bundled public source URL is passed. No log or symptom data.
    return launcher(uri, LaunchMode.externalApplication);
  }
}
