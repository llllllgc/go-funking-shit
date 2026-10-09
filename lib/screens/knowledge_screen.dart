import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/knowledge_base.dart';
import '../data/source_links.dart';
import '../domain/knowledge_tip.dart';
import '../widgets/knowledge_sources.dart';
import '../widgets/pressable.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({
    required this.controller,
    this.links = const ExternalSourceLinks(),
    super.key,
  });
  final BowelLogController controller;
  final SourceLinks links;
  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  KnowledgeCategory _category = KnowledgeCategory.all;
  String? _expandedId;
  final _cardKeys = {for (final tip in KnowledgeBase.tips) tip.id: GlobalKey()};

  void _openTip(KnowledgeTip tip) {
    setState(() {
      _category = tip.category;
      _expandedId = tip.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _cardKeys[tip.id]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .04,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final latest = widget.controller.records.isEmpty
        ? null
        : widget.controller.records.first;
    final featured = KnowledgeBase.featuredFor(latest?.bristolType);
    final tips = KnowledgeBase.forCategory(_category);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              key: const PageStorageKey('knowledge-scroll'),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              // The bundled catalog is deliberately small. Building all cards lets
              // shortcuts reveal an exact article without off-screen key races.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pressable(
                        key: const Key('knowledge-back'),
                        semanticLabel: '返回',
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 14, 18, 14),
                          child: SvgPicture.asset(
                            'assets/icons/ic_ticket_back.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              AppColors.ink,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '小纸条',
                          style: pixelStyle(size: 28, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '一般成年人科普 · 离线可读\n用于整理观察，不能替代诊断或就医。',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('knowledge-help'),
                    onPressed: () =>
                        _openTip(KnowledgeBase.byId('urgent-help')!),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('何时需要就医'),
                  ),
                  const SizedBox(height: 20),
                  _FeaturedNote(
                    tip: featured,
                    basedOnRecord: latest != null,
                    onOpen: () => _openTip(featured),
                  ),
                  const SizedBox(height: 24),
                  Text('按主题看', style: pixelStyle(size: 18, height: 1.4)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in KnowledgeCategory.values)
                        _CategoryButton(
                          category: category,
                          selected: category == _category,
                          onPressed: () => setState(() {
                            _category = category;
                            _expandedId = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final tip in tips)
                    Padding(
                      key: _cardKeys[tip.id],
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _KnowledgeCard(
                        tip: tip,
                        expanded: tip.id == _expandedId,
                        links: widget.links,
                        onPressed: () => setState(() {
                          _expandedId = tip.id == _expandedId ? null : tip.id;
                        }),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '内容核对表示已对照所列来源整理，不代表为你做过医疗评估。身体不适或对变化有疑问时，请联系专业人员。',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedNote extends StatelessWidget {
  const _FeaturedNote({
    required this.tip,
    required this.basedOnRecord,
    required this.onOpen,
  });
  final KnowledgeTip tip;
  final bool basedOnRecord;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.mossPale,
      border: Border.all(color: AppColors.mossInk, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              basedOnRecord ? '形态相关纸条' : '入门纸条',
              style: pixelStyle(
                size: 16,
                height: 1.4,
                color: AppColors.mossInk,
              ),
            ),
            const Text(
              '只关联主题，不作判断',
              style: TextStyle(color: AppColors.mossInk, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tip.title,
          style: const TextStyle(
            fontSize: 17,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(tip.summary, style: const TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('knowledge-featured-open'),
          onPressed: onOpen,
          child: const Text('阅读这张 · 查看来源'),
        ),
      ],
    ),
  );
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.selected,
    required this.onPressed,
  });
  final KnowledgeCategory category;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Pressable(
    key: ValueKey('knowledge-category-${category.name}'),
    semanticLabel: category.label,
    selected: selected,
    onPressed: onPressed,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.paperRaised,
        border: Border.all(color: AppColors.ink, width: selected ? 2 : 1),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: selected ? AppColors.paperRaised : AppColors.ink,
          fontSize: 13,
          height: 1.4,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({
    required this.tip,
    required this.expanded,
    required this.onPressed,
    required this.links,
  });
  final KnowledgeTip tip;
  final bool expanded;
  final VoidCallback onPressed;
  final SourceLinks links;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.paperRaised,
      border: Border.all(color: AppColors.rule),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only the toggle is a button. Expanded content and source actions must
        // remain individually readable/reachable by assistive technologies.
        Pressable(
          key: ValueKey('knowledge-card-${tip.id}'),
          semanticLabel:
              '${tip.title}。${tip.summary}。${expanded ? '收起' : '展开'}',
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      expanded ? '收起' : '展开',
                      style: const TextStyle(
                        color: AppColors.mossInk,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tip.summary,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: AppColors.rule),
                const SizedBox(height: 10),
                for (final detail in tip.details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '· $detail',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                const SizedBox(height: 4),
                KnowledgeSources(sources: tip.sources, links: links),
              ],
            ),
          ),
      ],
    ),
  );
}
