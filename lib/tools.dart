import 'package:flutter/material.dart';

import 'theme.dart';

enum ToolId { merge, split, pages, imageToPdf, pdfToImage, imagePrivacy, compress, scan, ocr, protect, sign, markup, search, more }

/// A tile on the home screen.
class ToolInfo {
  const ToolInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.palette,
    this.comingIn,
  });

  final ToolId id;
  final String title;
  final IconData icon;
  final TilePalette palette;

  /// The update this tool arrives in, or null when it already works.
  final String? comingIn;

  bool get isReady => comingIn == null;
}

List<ToolInfo> get homeTools => <ToolInfo>[
  ToolInfo(id: ToolId.merge, title: 'Merge PDF', icon: Icons.merge_type_rounded, palette: TilePalette.blue),
  ToolInfo(id: ToolId.split, title: 'Split PDF', icon: Icons.call_split_rounded, palette: TilePalette.orange),
  ToolInfo(id: ToolId.pages, title: 'Page tools', icon: Icons.view_module_outlined, palette: TilePalette.slate),
  ToolInfo(id: ToolId.imageToPdf, title: 'Image to PDF', icon: Icons.image_outlined, palette: TilePalette.pink),
  ToolInfo(
    id: ToolId.pdfToImage,
    title: 'PDF to image',
    icon: Icons.photo_size_select_actual_outlined,
    palette: TilePalette.green,
  ),
  ToolInfo(
    id: ToolId.imagePrivacy,
    title: 'Image privacy',
    icon: Icons.privacy_tip_outlined,
    palette: TilePalette.purple,
  ),
  ToolInfo(
    id: ToolId.compress,
    title: 'Compress',
    icon: Icons.compress_rounded,
    palette: TilePalette.green,
  ),
  ToolInfo(
    id: ToolId.scan,
    title: 'Scan to PDF',
    icon: Icons.document_scanner_outlined,
    palette: TilePalette.teal,
  ),
  ToolInfo(
    id: ToolId.ocr,
    title: 'Text from scans',
    icon: Icons.text_fields_rounded,
    palette: TilePalette.pink,
  ),
  ToolInfo(
    id: ToolId.protect,
    title: 'Protect',
    icon: Icons.lock_outline_rounded,
    palette: TilePalette.purple,
  ),
  ToolInfo(id: ToolId.sign, title: 'Edit & sign', icon: Icons.draw_outlined, palette: TilePalette.yellow),
  ToolInfo(id: ToolId.markup, title: 'Markup', icon: Icons.highlight_rounded, palette: TilePalette.orange),
  ToolInfo(id: ToolId.search, title: 'Search in PDF', icon: Icons.search_rounded, palette: TilePalette.blue),
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
