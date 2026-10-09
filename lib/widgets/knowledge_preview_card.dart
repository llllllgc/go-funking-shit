import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
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
      semanticLabel: '打开小纸条：${tip.title}。${tip.summary}',
      onPressed: onPressed,
      child: Stack(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              color: AppColors.paperRaised,
              border: Border.all(color: AppColors.ink, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SvgPicture.asset(
                      'assets/icons/ic_ticket_note.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        AppColors.mossInk,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('小纸条', style: pixelStyle(size: 18, height: 24 / 18)),
                    const Spacer(),
                    Text(
                      tip.category.label,
                      style: const TextStyle(
                        color: AppColors.mossInk,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tip.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                    height: 20 / 13,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  '打开知识库  →',
                  style: TextStyle(
                    color: AppColors.mossInk,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -1,
            right: -1,
            child: CustomPaint(
              size: const Size(22, 22),
              painter: _PaperFoldPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperFoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.paper;
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = false;
    final fold = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(fold, fill);
    canvas.drawPath(fold, line);
    canvas.drawLine(
      Offset(2, 2),
      Offset(size.width - 2, size.height - 2),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
