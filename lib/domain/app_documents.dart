class DocumentSection {
  const DocumentSection({
    required this.id,
    required this.title,
    required this.paragraphs,
  });
  final String id;
  final String title;
  final List<String> paragraphs;

  factory DocumentSection.fromJson(Map<String, dynamic> value) {
    final raw = value['paragraphs'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.any((item) => item is! String || item.trim().isEmpty)) {
      throw const FormatException('Missing document paragraphs');
    }
    return DocumentSection(
      id: _text(value, 'id'),
      title: _text(value, 'title'),
      paragraphs: List<String>.unmodifiable(raw),
    );
  }
}

class AppDocument {
  const AppDocument({required this.title, required this.sections});
  final String title;
  final List<DocumentSection> sections;
  factory AppDocument.fromJson(Map<String, dynamic> value) {
    final raw = value['sections'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('Missing document sections');
    }
    final sections = raw
        .map((item) => DocumentSection.fromJson(_object(item)))
        .toList();
    if (sections.map((item) => item.id).toSet().length != sections.length) {
      throw const FormatException('Duplicate section');
    }
    return AppDocument(
      title: _text(value, 'title'),
      sections: List.unmodifiable(sections),
    );
  }
}

class AppDocuments {
  const AppDocuments({
    required this.updatedOn,
    required this.privacy,
    required this.help,
    required this.changes,
  });
  final String updatedOn;
  final AppDocument privacy;
  final AppDocument help;
  final AppDocument changes;
  factory AppDocuments.fromJson(Map<String, dynamic> value) {
    if (value['schemaVersion'] != 1) {
      throw const FormatException('Unsupported document schema');
    }
    final updated = _text(value, 'updatedOn');
    final date = DateTime.tryParse(updated);
    if (date == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(updated) ||
        date.toIso8601String().substring(0, 10) != updated) {
      throw const FormatException('Invalid document date');
    }
    return AppDocuments(
      updatedOn: updated,
      privacy: AppDocument.fromJson(_object(value['privacy'])),
      help: AppDocument.fromJson(_object(value['help'])),
      changes: AppDocument.fromJson(_object(value['changes'])),
    );
  }
}

class PublishingInfo {
  const PublishingInfo({
    this.publisherName,
    this.supportUrl,
    this.privacyPolicyUrl,
  });
  final String? publisherName;
  final Uri? supportUrl;
  final Uri? privacyPolicyUrl;
  bool get hasPublisherContact => publisherName != null && supportUrl != null;
  bool get hasPublicPolicyUrl => privacyPolicyUrl != null;

  factory PublishingInfo.fromJson(Map<String, dynamic> value) {
    if (value['schemaVersion'] != 1) {
      throw const FormatException('Unsupported publisher schema');
    }
    final name = _optionalText(value, 'publisherName');
    final support = _optionalUri(value, 'supportUrl');
    final policy = _optionalUri(value, 'privacyPolicyUrl');
    if ((support != null && !canOpenAppLink(support)) ||
        (policy != null &&
            (policy.scheme != 'https' || !canOpenAppLink(policy)))) {
      throw const FormatException('Invalid publisher link');
    }
    return PublishingInfo(
      publisherName: name,
      supportUrl: support,
      privacyPolicyUrl: policy,
    );
  }
}

bool canOpenAppLink(Uri uri) {
  if (uri.userInfo.isNotEmpty) return false;
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  final addressParts = uri.path.split('@');
  return uri.scheme == 'mailto' &&
      !uri.hasAuthority &&
      addressParts.length == 2 &&
      addressParts.every(
        (part) => part.isNotEmpty && !RegExp(r'\s').hasMatch(part),
      ) &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid document object');
  }
  return value;
}

String _text(Map<String, dynamic> value, String key) =>
    _optionalText(value, key) ?? (throw FormatException('Missing $key'));
String? _optionalText(Map<String, dynamic> value, String key) {
  final text = value[key];
  if (text == null) return null;
  if (text is! String || text.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return text.trim();
}

Uri? _optionalUri(Map<String, dynamic> value, String key) {
  final text = _optionalText(value, key);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) throw FormatException('Invalid $key');
  return uri;
}
