import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../application/bowel_log_controller.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/knowledge_base.dart';
import '../domain/knowledge_tip.dart';
import '../widgets/pressable.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({required this.controller, super.key});

  final BowelLogController controller;

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  KnowledgeCategory _category = KnowledgeCategory.all;
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final latest = widget.controller.latestTodayRecord;
    final featured = KnowledgeBase.featuredFor(latest?.bristolType);
    final tips = KnowledgeBase.forCategory(_category);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          children: <Widget>[
            Row(
              children: <Widget>[
                Pressable(
                  key: const Key('knowledge-back'),
                  semanticLabel: '返回',
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                    child: SvgPicture.asset(
                      'assets/icons/ic_ticket_back.svg',
                      width: 22,
                      height: 22,
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
                    style: pixelStyle(size: 28, height: 36 / 28),
                  ),
                ),
                SvgPicture.asset(
                  'assets/icons/ic_ticket_note.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    AppColors.mossInk,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 36, top: 2, bottom: 20),
              child: Text(
                '把身体的信号，留给自己看。',
                style: TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            _FeaturedNote(tip: featured, basedOnRecord: latest != null),
            const SizedBox(height: 28),
            Text('按主题看', style: pixelStyle(size: 18, height: 24 / 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: KnowledgeCategory.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = KnowledgeCategory.values[index];
                  return _CategoryButton(
                    category: category,
                    selected: category == _category,
                    onPressed: () => setState(() {
                      _category = category;
                      _expandedId = null;
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KnowledgeCard(
                  tip: tip,
                  expanded: tip.id == _expandedId,
                  onPressed: () => setState(() {
                    _expandedId = tip.id == _expandedId ? null : tip.id;
                  }),
                ),
              ),
            const SizedBox(height: 12),
            const _KnowledgeFooter(),
          ],
        ),
      ),
    );
  }
}

class _FeaturedNote extends StatelessWidget {
  const _FeaturedNote({required this.tip, required this.basedOnRecord});

  final KnowledgeTip tip;
  final bool basedOnRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        color: AppColors.mossPale,
        border: Border.all(color: AppColors.mossInk, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '今天这张',
                style: pixelStyle(
                  size: 16,
                  height: 22 / 16,
                  color: AppColors.mossInk,
                ),
              ),
              const Spacer(),
              Text(
                basedOnRecord ? '根据你的记录' : '从基础知识开始',
                style: const TextStyle(color: AppColors.mossInk, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tip.title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              height: 24 / 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tip.summary,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              height: 21 / 14,
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: category.label,
      selected: selected,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paperRaised,
          border: Border.all(color: AppColors.ink, width: selected ? 2 : 1),
        ),
        child: Text(
          category.label,
          style: TextStyle(
            color: selected ? AppColors.paperRaised : AppColors.ink,
            fontSize: 13,
            height: 18 / 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({
    required this.tip,
    required this.expanded,
    required this.onPressed,
  });

  final KnowledgeTip tip;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: ValueKey('knowledge-card-${tip.id}'),
      semanticLabel: '${tip.title}${expanded ? '，收起' : '，展开'}',
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.paperRaised,
          border: Border.all(color: AppColors.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    tip.title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      height: 22 / 15,
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
                height: 20 / 13,
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.rule),
              const SizedBox(height: 10),
              for (final detail in tip.details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· $detail',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      height: 20 / 13,
                    ),
                  ),
                ),
              Text(
                tip.source,
                style: const TextStyle(
                  color: AppColors.inkMuted,
                  fontSize: 11,
                  height: 17 / 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KnowledgeFooter extends StatelessWidget {
  const _KnowledgeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.danger),
      ),
      child: const Text(
        '这里是生活知识，不是诊断。出现鲜血、黑色柏油样便、明显腹痛、头晕或脱水迹象时，请及时寻求医疗帮助。',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          height: 18 / 12,
        ),
      ),
    );
  }
}
