import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../office/doc_reader.dart';
import '../office/office_file.dart';
import '../office/zip_reader.dart';
import '../theme.dart';
import '../widgets.dart';

/// Picks a Word file and opens it in [DocViewerPage].
Future<void> openDocumentFromPicker(BuildContext context) async {
  final path = await pickOfficeFile(context, const ['docx']);
  if (path == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocViewerPage(path: path)));
}

/// Shows a Word (.docx) document to read. View only.
class DocViewerPage extends StatefulWidget {
  const DocViewerPage({super.key, required this.path});

  final String path;

  @override
  State<DocViewerPage> createState() => _DocViewerPageState();
}

class _DocViewerPageState extends State<DocViewerPage> {
  late final Future<DocumentData> _document = readDocumentFile(widget.path);
  double _zoom = 1;

  void _changeZoom(double step) {
    setState(() => _zoom = math.min(1.8, math.max(0.7, _zoom + step)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            OfficeViewerHeader(
              path: widget.path,
              actions: [
                IconButton(
                  tooltip: 'Smaller text',
                  onPressed: _zoom > 0.75 ? () => _changeZoom(-0.1) : null,
                  icon: Icon(Icons.text_decrease_rounded, color: AppColors.muted),
                ),
                IconButton(
                  tooltip: 'Larger text',
                  onPressed: _zoom < 1.75 ? () => _changeZoom(0.1) : null,
                  icon: Icon(Icons.text_increase_rounded, color: AppColors.muted),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder<DocumentData>(
                future: _document,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.accent),
                          const SizedBox(height: 16),
                          Text('Opening the file…', style: TextStyle(fontSize: 15, color: AppColors.muted)),
                        ],
                      ),
                    );
                  }
                  final document = snapshot.data;
                  if (document == null || document.blocks.isEmpty) {
                    final error = snapshot.error;
                    return Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.description_outlined,
                          palette: document == null ? TilePalette.orange : TilePalette.slate,
                          title: document == null ? 'Could not open this file' : 'Nothing to show',
                          message: document != null
                              ? 'This document is empty.'
                              : error is OfficeFileException
                                  ? error.message
                                  : 'This file could not be read. It may be damaged.',
                        ),
                      ),
                    );
                  }
                  return _DocumentView(blocks: document.blocks, zoom: _zoom);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.blocks, required this.zoom});

  final List<DocBlock> blocks;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: SelectionArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 760.0);
            final side = (constraints.maxWidth - width) / 2 + 18;
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(side, 20, side, 28),
              itemCount: blocks.length,
              itemBuilder: (context, i) => _BlockView(block: blocks[i], zoom: zoom, maxWidth: width - 36),
            );
          },
        ),
      ),
    );
  }
}

/// Draws one block of the document.
class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.zoom, required this.maxWidth});

  final DocBlock block;
  final double zoom;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      DocParagraph paragraph => _paragraph(paragraph),
      DocImage image => _image(image),
      DocMissingImage() => _missingImage(),
      DocPageBreak() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Divider(color: AppColors.line, thickness: 1, height: 1),
        ),
      DocTable table => _table(table),
    };
  }

  static const _bodySize = 15.5;

  double _headingSize(int heading) => switch (heading) {
        7 => 26,
        1 => 22,
        2 => 19,
        3 => 17.5,
        4 || 5 || 6 => 16.5,
        _ => _bodySize,
      };

  Widget _paragraph(DocParagraph paragraph) {
    final heading = paragraph.heading;
    final baseSize = _headingSize(heading) * zoom;
    if (paragraph.isEmpty) return SizedBox(height: 8 * zoom);

    final dark = AppColors.isDark;
    final spans = <InlineSpan>[
      for (final run in paragraph.runs)
        TextSpan(
          text: run.text,
          style: TextStyle(
            fontWeight: run.bold || heading > 0 ? FontWeight.w700 : FontWeight.w400,
            fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
            decoration: TextDecoration.combine([
              if (run.underline) TextDecoration.underline,
              if (run.strike) TextDecoration.lineThrough,
            ]),
            fontSize: _runSize(run, baseSize, heading),
            color: run.link ? AppColors.accent : (!dark && run.color != null ? Color(0xFF000000 | run.color!) : null),
            backgroundColor:
                run.highlight == null ? null : Color(0xFF000000 | run.highlight!).withValues(alpha: dark ? 0.35 : 0.45),
          ),
        ),
    ];

    final text = Text.rich(
      TextSpan(children: spans),
      textAlign: switch (paragraph.align) {
        DocAlign.center => TextAlign.center,
        DocAlign.end => TextAlign.end,
        DocAlign.justify => TextAlign.justify,
        DocAlign.start => TextAlign.start,
      },
      style: TextStyle(fontSize: baseSize, height: 1.45, color: AppColors.ink),
    );

    final label = paragraph.listLabel;
    Widget child = text;
    if (label != null) {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: math.max(26.0, label.length * 9.0) * zoom,
            child: Text(label, style: TextStyle(fontSize: baseSize, height: 1.45, color: AppColors.muted)),
          ),
          Expanded(child: text),
        ],
      );
    }

    final indent = label != null ? paragraph.listLevel * 18.0 : math.min(paragraph.indent, 48.0);
    return Padding(
      padding: EdgeInsets.only(
        left: indent * zoom,
        top: heading > 0 ? 10 * zoom : 0,
        bottom: (heading > 0 ? 6 : (label != null ? 4 : 10)) * zoom,
      ),
      child: child,
    );
  }

  double _runSize(DocRun run, double baseSize, int heading) {
    final size = run.sizePt;
    // The document's sizes are in points; 11 points shows as the body size.
    var result = size == null || heading > 0 ? baseSize : size * (_bodySize / 11) * zoom;
    result = math.min(48 * zoom, math.max(9 * zoom, result));
    return run.small ? result * 0.7 : result;
  }

  Widget _image(DocImage image) {
    final width = image.width > 0 ? math.min(image.width, maxWidth) : maxWidth;
    final height = image.width > 0 && image.height > 0 ? image.height * width / image.width : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            image.bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => _missingImage(),
          ),
        ),
      ),
    );
  }

  Widget _missingImage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 20, color: AppColors.muted),
            const SizedBox(width: 8),
            Text('Picture not shown', style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _table(DocTable table) {
    final columns = math.max(1, table.columns);
    final line = BorderSide(color: AppColors.line);
    // Narrow columns are hard to read on a phone; wide tables scroll sideways.
    final tableWidth = math.max(maxWidth, columns * 110.0);
    final grid = SizedBox(
      width: tableWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: line, left: line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in table.rows)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cell in row)
                      Expanded(
                        flex: cell.span,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                          decoration: BoxDecoration(
                            color: cell.shade == null || AppColors.isDark ? null : Color(0xFF000000 | cell.shade!),
                            border: Border(right: line, bottom: line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final inner in cell.blocks)
                                _BlockView(
                                  block: inner,
                                  zoom: zoom * 0.92,
                                  maxWidth: tableWidth / columns * cell.span - 16,
                                ),
                            ],
                          ),
                        ),
                      ),
                    // Rows with fewer cells than the grid keep the table square.
                    if (row.fold<int>(0, (sum, c) => sum + c.span) < columns)
                      Expanded(
                        flex: columns - row.fold<int>(0, (sum, c) => sum + c.span),
                        child: DecoratedBox(decoration: BoxDecoration(border: Border(right: line, bottom: line))),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: tableWidth > maxWidth
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid)
          : grid,
    );
  }
}
