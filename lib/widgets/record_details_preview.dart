import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../domain/record_details.dart';

class RecordDetailsPreview extends StatelessWidget {
  const RecordDetailsPreview({required this.details, super.key});
  final RecordDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.discomfortMask != 0)
            Text(
              details.discomforts.map((item) => item.label).join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.mossInk),
            ),
          if (details.note.isNotEmpty)
            Text(
              details.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}
