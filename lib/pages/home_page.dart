import 'package:flutter/material.dart';

import '../coming_soon_sheet.dart';
import '../file_store.dart';
import '../file_tile.dart';
import '../theme.dart';
import '../tools.dart';
import '../widgets.dart';
import 'image_to_pdf_page.dart';
import 'merge_page.dart';
import 'pages_page.dart';
import 'pdf_to_image_page.dart';
import 'scan_page.dart';
import 'split_page.dart';

/// The first screen: tool tiles and the latest files.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSeeAllFiles});

  final VoidCallback onSeeAllFiles;

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 4 : 2;
    return ListenableBuilder(
      listenable: FileStore.instance,
      builder: (context, _) {
        final recent = FileStore.instance.files.take(3).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Row(
              children: [
                AppLogo(),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paperwise',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                _OfflineBadge(),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Pick a tool'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 96,
              ),
              itemCount: homeTools.length,
              itemBuilder: (context, index) => _ToolTile(tool: homeTools[index]),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Recent files')),
                if (recent.isNotEmpty)
                  TextButton(
                    onPressed: onSeeAllFiles,
                    child: const Text(
                      'See all',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              const SectionCard(
                child: Row(
                  children: [
                    PageThumb(),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'PDFs you make will show up here, ready to open or share.',
                        style: TextStyle(fontSize: 15, height: 1.35, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final file in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FileTile(file: file),
                ),
          ],
        );
      },
    );
  }
}

/// Opens the screen for [tool], or says when it is coming.
void openTool(BuildContext context, ToolInfo tool) {
  final Widget page;
  switch (tool.id) {
    case ToolId.merge:
      page = const MergePage();
    case ToolId.split:
      page = const SplitPage();
    case ToolId.pages:
      page = const PagesPage();
    case ToolId.pdfToImage:
      page = const PdfToImagePage();
    case ToolId.scan:
      page = const ScanToPdfPage();
    case ToolId.imageToPdf:
      page = const ImageToPdfPage();
    case ToolId.more:
      showComingSoonSheet(context);
      return;
    case ToolId.compress:
    case ToolId.protect:
    case ToolId.sign:
      showMessage(context, '${tool.title} is coming in ${tool.comingIn}. Stay tuned!');
      return;
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Every tool works without internet',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Offline',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final ToolInfo tool;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Material(
      color: tool.palette.tint,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => openTool(context, tool),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(tool.icon, size: 28, color: tool.palette.color),
                  const Spacer(),
                  if (!tool.isReady)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Soon',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tool.palette.color),
                      ),
                    ),
                ],
              ),
              Text(
                tool.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
