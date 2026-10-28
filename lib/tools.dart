import 'package:flutter/material.dart';

import 'theme.dart';

enum ToolId { merge, split, pages, imageToPdf, pdfToImage, images, imagePrivacy, compress, scan, ocr, protect, sign, markup, search, info, nup, idCard, excel, more }

/// A tile on the home screen.
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.palette,
    this.subtitle = '',
    this.comingIn,
  });

  final ToolId id;
  final String title;
  final IconData icon;
  final TilePalette palette;

  /// A few words under the title on the home screen.
  final String subtitle;

  /// The update this tool arrives in, or null when it already works.
  final String? comingIn;

  bool get isReady => comingIn == null;
}

List<ToolInfo> get homeTools => <ToolInfo>[
  ToolInfo(id: ToolId.merge, title: 'Merge PDF', icon: Icons.merge_type_rounded, palette: TilePalette.blue, subtitle: 'Join PDFs into one'),
  ToolInfo(id: ToolId.split, title: 'Split PDF', icon: Icons.call_split_rounded, palette: TilePalette.orange, subtitle: 'By range or every page'),
  ToolInfo(id: ToolId.pages, title: 'Page tools', icon: Icons.view_module_outlined, palette: TilePalette.slate, subtitle: 'Reorder, rotate, delete'),
  ToolInfo(id: ToolId.nup, title: 'Pages per sheet', icon: Icons.grid_view_rounded, palette: TilePalette.teal, subtitle: 'Save paper when printing'),
  ToolInfo(id: ToolId.idCard, title: 'ID card to PDF', icon: Icons.badge_outlined, palette: TilePalette.blue, subtitle: 'Front and back on one page'),
  ToolInfo(id: ToolId.imageToPdf, title: 'Image to PDF', icon: Icons.image_outlined, palette: TilePalette.pink, subtitle: 'Photos become pages'),
  ToolInfo(
    id: ToolId.pdfToImage,
    title: 'PDF to image',
    icon: Icons.photo_size_select_actual_outlined,
    palette: TilePalette.green,
    subtitle: 'Save pages as pictures',
  ),
  ToolInfo(
    id: ToolId.imagePrivacy,
    title: 'Image privacy',
    icon: Icons.privacy_tip_outlined,
    palette: TilePalette.purple,
    subtitle: 'Remove location, blur faces',
  ),
  ToolInfo(
    id: ToolId.compress,
    title: 'Compress',
    icon: Icons.compress_rounded,
    palette: TilePalette.green,
    subtitle: 'See the size first',
  ),
  ToolInfo(
    id: ToolId.scan,
    title: 'Scan to PDF',
    icon: Icons.document_scanner_outlined,
    palette: TilePalette.teal,
    subtitle: 'Camera, crop, build',
  ),
  ToolInfo(
    id: ToolId.ocr,
    title: 'Text from scans',
    icon: Icons.text_fields_rounded,
    palette: TilePalette.pink,
    subtitle: 'Make scans searchable',
  ),
  ToolInfo(
    id: ToolId.protect,
    title: 'Protect',
    icon: Icons.lock_outline_rounded,
    palette: TilePalette.purple,
    subtitle: 'Password and watermark',
  ),
  ToolInfo(id: ToolId.sign, title: 'Edit & sign', icon: Icons.draw_outlined, palette: TilePalette.yellow, subtitle: 'Text, signature, numbers'),
  ToolInfo(id: ToolId.markup, title: 'Markup', icon: Icons.highlight_rounded, palette: TilePalette.orange, subtitle: 'Highlight and draw'),
  ToolInfo(id: ToolId.images, title: 'Images from PDF', icon: Icons.collections_outlined, palette: TilePalette.yellow, subtitle: 'Save pictures stored inside'),
  ToolInfo(id: ToolId.search, title: 'Search in PDF', icon: Icons.search_rounded, palette: TilePalette.blue, subtitle: 'Find words in a PDF'),
  ToolInfo(id: ToolId.excel, title: 'Excel viewer', icon: Icons.table_chart_outlined, palette: TilePalette.green, subtitle: 'Open .xlsx and .csv sheets'),
  ToolInfo(id: ToolId.info, title: 'PDF info', icon: Icons.info_outline_rounded, palette: TilePalette.teal, subtitle: 'Author, dates, clean copy'),
];

/// One planned update, shown in "What's coming".
class PlannedUpdate {
  const PlannedUpdate(this.version, this.title, this.details);

  final String version;
  final String title;
  final String details;
}

const plannedUpdates = <PlannedUpdate>[
  PlannedUpdate('v1.0', 'Ready for everyone', 'Final polish, then Paperwise on Google Play and GitHub Releases.'),
];

/// The home screen shows the tools in these groups, in this order.
class ToolGroup {
  const ToolGroup(this.title, this.ids);

  final String title;
  final List<ToolId> ids;
}

const toolGroups = <ToolGroup>[
  ToolGroup('Organize', [ToolId.merge, ToolId.split, ToolId.pages, ToolId.nup]),
  ToolGroup('Convert and scan', [ToolId.imageToPdf, ToolId.idCard, ToolId.pdfToImage, ToolId.images, ToolId.scan, ToolId.ocr]),
  ToolGroup('Secure and edit', [ToolId.compress, ToolId.protect, ToolId.sign, ToolId.markup, ToolId.imagePrivacy]),
  ToolGroup('Read and find', [ToolId.search, ToolId.info, ToolId.excel]),
];
