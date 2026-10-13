import 'package:flutter/material.dart';

import 'theme.dart';

enum ToolId { merge, split, imageToPdf, compress, scan, protect, sign, more }

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

const homeTools = <ToolInfo>[
  ToolInfo(id: ToolId.merge, title: 'Merge PDF', icon: Icons.merge_type_rounded, palette: TilePalette.blue),
  ToolInfo(id: ToolId.split, title: 'Split PDF', icon: Icons.call_split_rounded, palette: TilePalette.orange),
  ToolInfo(id: ToolId.imageToPdf, title: 'Image to PDF', icon: Icons.image_outlined, palette: TilePalette.pink),
  ToolInfo(
    id: ToolId.compress,
    title: 'Compress',
    icon: Icons.compress_rounded,
    palette: TilePalette.green,
    comingIn: 'v0.5',
  ),
  ToolInfo(
    id: ToolId.scan,
    title: 'Scan to PDF',
    icon: Icons.document_scanner_outlined,
    palette: TilePalette.teal,
    comingIn: 'v0.4',
  ),
  ToolInfo(
    id: ToolId.protect,
    title: 'Protect',
    icon: Icons.lock_outline_rounded,
    palette: TilePalette.purple,
    comingIn: 'v0.6',
  ),
  ToolInfo(id: ToolId.sign, title: 'Sign', icon: Icons.draw_outlined, palette: TilePalette.yellow, comingIn: 'v0.7'),
  ToolInfo(id: ToolId.more, title: 'More tools', icon: Icons.grid_view_rounded, palette: TilePalette.slate),
];

/// One planned update, shown in "What's coming".
class PlannedUpdate {
  const PlannedUpdate(this.version, this.title, this.details);

  final String version;
  final String title;
  final String details;
}

const plannedUpdates = <PlannedUpdate>[
  PlannedUpdate(
    'v0.2',
    'PDF viewer',
    'Read any PDF inside Paperwise with zoom, page jump and thumbnails. '
        'Continue where you left off, mark favorites, and open PDFs from other apps.',
  ),
  PlannedUpdate('v0.3', 'Page tools', 'Reorder, rotate, delete and extract pages on a visual page grid.'),
  PlannedUpdate(
    'v0.4',
    'Convert',
    'Save PDF pages as JPG or PNG. Scan paper to PDF with your camera, with crop and filters.',
  ),
  PlannedUpdate(
    'v0.5',
    'Compress',
    'Make PDFs smaller with light, balanced or strong compression, and see the new size first.',
  ),
  PlannedUpdate('v0.6', 'Security', 'Lock a PDF with a password, unlock it, and add a text or image watermark.'),
  PlannedUpdate('v0.7', 'Edit', 'Add text, your signature, page numbers, header and footer.'),
  PlannedUpdate('v0.8', 'Markup and search', 'Highlight, draw and add shapes. Search for words inside a PDF.'),
  PlannedUpdate(
    'v0.9',
    'Your way',
    'Dark mode, more languages, sort and search your files, and local backup.',
  ),
  PlannedUpdate('v1.0', 'Ready for stores', 'Final polish, then Paperwise on F-Droid and Google Play.'),
];
