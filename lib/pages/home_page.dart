import 'package:flutter/material.dart';

import '../coming_soon_sheet.dart';
import '../file_store.dart';
import '../file_tile.dart';
import '../picked_pdf.dart';
import '../theme.dart';
import '../tools.dart';
import '../widgets.dart';
import 'compress_page.dart';
import 'edit_page.dart';
import 'id_card_page.dart';
import 'image_privacy_page.dart';
import 'images_page.dart';
import 'image_to_pdf_page.dart';
import 'info_page.dart';
import 'markup_page.dart';
import 'nup_page.dart';
import 'merge_page.dart';
import 'pages_page.dart';
import 'ocr_page.dart';
import 'pdf_to_image_page.dart';
import 'protect_page.dart';
import 'scan_page.dart';
import 'sheet_viewer_page.dart';
import 'split_page.dart';
import 'viewer_page.dart';
import '../strings.dart';

/// The first screen: tool tiles and the latest files.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onSeeAllFiles});

  final VoidCallback onSeeAllFiles;

  @override
  Widget build(BuildContext context) {
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
            for (final group in toolGroups) ...[
              _SectionTitle(group.title),
              const SizedBox(height: 8),
              _ToolGroupCard(tools: [for (final id in group.ids) homeTools.firstWhere((t) => t.id == id)]),
              const SizedBox(height: 18),
            ],
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
              SectionCard(
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
              )
            else
              for (var i = 0; i < recent.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FileTile(file: recent[i]),
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
    case ToolId.images:
      page = const ImagesPage();
    case ToolId.nup:
      page = const NUpPage();
    case ToolId.idCard:
      page = const IdCardPage();
    case ToolId.info:
      page = const InfoPage();
    case ToolId.excel:
      openSheetFromPicker(context);
      return;
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.tr.toUpperCase(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: AppColors.muted),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final palette = TilePalette.teal;
    return Tooltip(
      message: 'Every tool works without internet'.tr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: palette.color),
            const SizedBox(width: 6),
            Text(
              'Offline'.tr,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.color),
            ),
          ],
        ),
      ),
    );
  }
}

/// One group of tools as rows inside a single card.
class _ToolGroupCard extends StatelessWidget {
  const _ToolGroupCard({required this.tools});

  final List<ToolInfo> tools;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.line),
            _ToolRow(tool: tools[i]),
          ],
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});

  final ToolInfo tool;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openTool(context, tool),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tool.palette.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(tool.icon, size: 22, color: tool.palette.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.title.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                  if (tool.subtitle.isNotEmpty)
                    Text(
                      tool.subtitle.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (!tool.isReady)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Soon'.tr,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tool.palette.color),
                ),
              ),
            Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
