import 'package:flutter/material.dart';

import 'file_actions.dart';
import 'file_store.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';
import 'strings.dart';

/// Shows what a tool just made, with Open, Share and Save buttons.
Future<void> showResultSheet(BuildContext context, List<OutputFile> results) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => _ResultSheet(results: results),
  );
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.results});

  final List<OutputFile> results;

  @override
  Widget build(BuildContext context) {
    final single = results.length == 1;
    final totalBytes = results.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final first = results.first;

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
              single ? 'Your PDF is ready'.tr : '${fileCountLabel(results.length)} ready',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              single
                  ? '${first.name} · ${formatBytes(first.sizeBytes)}'
                  : '${formatBytes(totalBytes)} in total · saved in Paperwise',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.muted),
            ),
            if (!single) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 168),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final f = results[index];
                    return Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          formatBytes(f.sizeBytes),
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (single) ...[
              PrimaryButton(
                label: 'Open'.tr,
                icon: Icons.open_in_new_rounded,
                onPressed: () => openPdf(context, first.path),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Share'.tr,
                      icon: Icons.share_outlined,
                      onPressed: () => sharePdfs([first.path]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Save to phone'.tr,
                      icon: Icons.download_rounded,
                      onPressed: () => savePdfToDevice(context, first.path, first.name),
                    ),
                  ),
                ],
              ),
            ] else
              PrimaryButton(
                label: 'Share all'.tr,
                icon: Icons.share_outlined,
                onPressed: () => sharePdfs([for (final f in results) f.path]),
              ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Done'.tr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
