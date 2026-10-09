enum KnowledgeCategory {
  all('全部'),
  food('吃什么'),
  shape('形态'),
  habit('习惯'),
  color('颜色'),
  alert('要留意');

  const KnowledgeCategory(this.label);
  final String label;
}

class KnowledgeSource {
  const KnowledgeSource({
    required this.id,
    required this.organization,
    required this.title,
    required this.url,
    required this.checkedOn,
  });
  final String id;
  final String organization;
  final String title;
  final String url;

  /// Editorial link/content check, not clinical certification or source revision.
  final String checkedOn;
}

class KnowledgeTip {
  const KnowledgeTip({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.details,
    required this.sources,
    this.tags = const <String>[],
  });
  final String id;
  final KnowledgeCategory category;
  final String title;
  final String summary;
  final List<String> details;
  final List<KnowledgeSource> sources;
  final List<String> tags;
}
