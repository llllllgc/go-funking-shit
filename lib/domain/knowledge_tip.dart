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

class KnowledgeTip {
  const KnowledgeTip({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.details,
    required this.source,
    this.tags = const <String>[],
    this.featured = false,
  });

  final String id;
  final KnowledgeCategory category;
  final String title;
  final String summary;
  final List<String> details;
  final String source;
  final List<String> tags;
  final bool featured;
}
