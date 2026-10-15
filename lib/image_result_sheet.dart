import 'dart:io';

import 'package:flutter/material.dart';

import 'file_actions.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

/// Shows the pictures a tool just made, with Share and Save buttons.
Future<void> showImagesResultSheet(BuildContext context, List<String> paths, {String? note}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _ImagesResultSheet(paths: paths, note: note),
  );
}

class _ImagesResultSheet extends StatelessWidget {
  const _ImagesResultSheet({required this.paths, this.note});

  final List<String> paths;
  final String? note;

  String _nameOf(String path) => File(path).uri.pathSegments.last;

  @override
  Widget build(BuildContext context) {
    final single = paths.length == 1;
    final first = paths.first;
    final mime = first.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final totalBytes = paths.fold<int>(0, (sum, p) => sum + File(p).lengthSync());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 38, color: AppColors.success),
            ),
            const SizedBox(height: 14),
            Text(
              single ? 'Your image is ready' : '${paths.length} images ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              single ? '${_nameOf(first)} · ${formatBytes(totalBytes)}' : '${formatBytes(totalBytes)} in total',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: paths.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(paths[index]),
                    height: 96,
                    cacheHeight: 192,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const SizedBox(width: 72, height: 96),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: single ? 'Share' : 'Share all',
              icon: Icons.share_outlined,
              onPressed: () => shareImages(paths),
            ),
            if (single) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Save to phone',
                icon: Icons.download_rounded,
                onPressed: () => saveFileToDevice(context, first, _nameOf(first), mime),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'In the share menu, choose "Save to Files" or any folder app to keep them on your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
