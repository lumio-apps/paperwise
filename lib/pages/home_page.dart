import 'package:flutter/material.dart';

import '../coming_soon_sheet.dart';
import '../file_store.dart';
import '../file_tile.dart';
import '../neumorphic.dart';
import '../picked_pdf.dart';
import '../theme.dart';
import '../tools.dart';
import '../widgets.dart';
import 'compress_page.dart';
import 'edit_page.dart';
import 'image_privacy_page.dart';
import 'image_to_pdf_page.dart';
import 'info_page.dart';
import 'markup_page.dart';
import 'merge_page.dart';
import 'pages_page.dart';
import 'ocr_page.dart';
import 'pdf_to_image_page.dart';
import 'protect_page.dart';
import 'scan_page.dart';
import 'split_page.dart';
import 'viewer_page.dart';
import '../strings.dart';

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
            Row(
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
              itemBuilder: (context, index) => _ToolTile(tool: homeTools[index], index: index),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Recent files')),
                if (recent.isNotEmpty)
                  TextButton(
                    onPressed: onSeeAllFiles,
                    child: Text(
                      'See all'.tr,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              RiseIn(
                delay: const Duration(milliseconds: 500),
                child: SectionCard(
                  child: Row(
                    children: [
                      PageThumb(),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'PDFs you make will show up here, ready to open or share.'.tr,
                          style: TextStyle(fontSize: 15, height: 1.35, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (var i = 0; i < recent.length; i++)
                RiseIn(
                  delay: Duration(milliseconds: 500 + 80 * i),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FileTile(file: recent[i]),
                  ),
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
    case ToolId.imagePrivacy:
      page = const ImagePrivacyPage();
    case ToolId.imageToPdf:
      page = const ImageToPdfPage();
    case ToolId.more:
      showComingSoonSheet(context);
      return;
    case ToolId.compress:
      page = const CompressPage();
    case ToolId.ocr:
      page = const OcrPage();
    case ToolId.protect:
      page = const ProtectPage();
    case ToolId.sign:
      page = const EditPage();
    case ToolId.markup:
      page = const MarkupPage();
    case ToolId.search:
      _openSearch(context);
      return;
    case ToolId.info:
      page = const InfoPage();
  }
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Picks a PDF and opens it in the viewer with the search box ready.
Future<void> _openSearch(BuildContext context) async {
  try {
    final picked = await pickPdfFiles(multiple: false);
    if (picked.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ViewerPage(path: picked.first.path, startWithSearch: true)),
    );
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not open the file picker.'.tr);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Every tool works without internet'.tr,
      child: NeuBox(
        pressed: true,
        radius: 18,
        depth: 3,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Offline'.tr,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.index});

  final ToolInfo tool;
  final int index;

  @override
  Widget build(BuildContext context) {
    return RiseIn(
      delay: Duration(milliseconds: 45 * index),
      child: NeuPress(
        radius: 24,
        depth: 8,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        onTap: () => openTool(context, tool),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                NeuBox(
                  pressed: true,
                  radius: 20,
                  depth: 3,
                  child: SizedBox(width: 40, height: 40, child: Icon(tool.icon, size: 22, color: tool.palette.color)),
                ),
                const Spacer(),
                if (!tool.isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Soon'.tr,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tool.palette.color),
                    ),
                  ),
              ],
            ),
            Text(
              tool.title.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
