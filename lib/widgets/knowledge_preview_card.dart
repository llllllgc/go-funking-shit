// Hallmark · component: knowledge preview · theme: locked LaLeMa
// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V4
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../domain/knowledge_tip.dart';
import 'pressable.dart';

class KnowledgePreviewCard extends StatelessWidget {
  const KnowledgePreviewCard({
    required this.tip,
    required this.onPressed,
    super.key,
  });

  final KnowledgeTip tip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: const Key('knowledge-preview'),
      semanticLabel: '打开小纸条：${tip.title}',
      onPressed: onPressed,
      pressOffset: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              SvgPicture.asset(
                'assets/icons/ic_ticket_note.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  AppColors.inkMuted,
                  BlendMode.srcIn,
                ),
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '小纸条',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                        height: 20 / 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RotatedBox(
                quarterTurns: 2,
                child: SvgPicture.asset(
                  'assets/icons/ic_ticket_back.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    AppColors.inkMuted,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
