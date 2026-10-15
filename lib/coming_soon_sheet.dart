import 'package:flutter/material.dart';

import 'theme.dart';
import 'tools.dart';
import 'strings.dart';

/// Lists the next Paperwise updates and what each one adds.
Future<void> showComingSoonSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            "What's coming".tr,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Paperwise grows one small update at a time. Every tool will stay free and offline.',
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < plannedUpdates.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _UpdateRow(
                update: plannedUpdates[i],
                palette: TilePalette.cycle[i % TilePalette.cycle.length],
              ),
            ),
        ],
      ),
    ),
  );
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.update, required this.palette});

  final PlannedUpdate update;
  final TilePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(10)),
          child: Text(
            update.version,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: palette.color),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                update.title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                update.details,
                style: TextStyle(fontSize: 14, height: 1.35, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
