import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../file_store.dart';
import '../format.dart';
import '../image_pdf.dart';
import '../image_tools.dart';
import '../platform_info.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'scan_edit_page.dart';

/// Scan paper with the camera: crop, pick a look, and make a PDF.
class ScanToPdfPage extends StatefulWidget {
  const ScanToPdfPage({super.key});

  @override
  State<ScanToPdfPage> createState() => _ScanToPdfPageState();
}

class _ScanToPdfPageState extends State<ScanToPdfPage> {
  final _picker = ImagePicker();
  final List<ScanPageData> _pages = [];

  bool _preparing = false;
  bool _busy = false;
  String? _progress;

  Future<void> _capture() async {
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2480,
        maxHeight: 2480,
        imageQuality: 90,
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the camera.');
      return;
    }
    if (photo == null || !mounted) return;
    final added = await _addPhotos([photo]);
    // A new camera shot is opened right away so the corners can be set.
    if (added.isNotEmpty && mounted) await _edit(added.first);
  }

  Future<void> _fromGallery() async {
    final List<XFile> picked;
    try {
      picked = await _picker.pickMultiImage(maxWidth: 2480, maxHeight: 2480, imageQuality: 90);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open your photos.');
      return;
    }
    if (picked.isEmpty || !mounted) return;
    await _addPhotos(picked);
  }

  Future<List<ScanPageData>> _addPhotos(List<XFile> photos) async {
    setState(() => _preparing = true);
    final added = <ScanPageData>[];
    var failed = 0;
    for (final photo in photos) {
      try {
        final Uint8List bytes = await photo.readAsBytes();
        final page = ScanPageData(await prepareScanSource(bytes));
        await _updateThumbnail(page);
        added.add(page);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return added;
    setState(() {
      _pages.addAll(added);
      _preparing = false;
    });
    if (failed > 0) {
      showMessage(context, failed == 1 ? 'One photo could not be read.' : '$failed photos could not be read.');
    }
    return added;
  }

  Future<void> _updateThumbnail(ScanPageData page) async {
    page.thumbnail = await renderScan(page.source.small, page.corners, page.filter, maxSide: 520, quality: 75);
  }

  Future<void> _edit(ScanPageData page) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ScanEditPage(page: page)),
    );
    if (changed != true || !mounted) return;
    try {
      await _updateThumbnail(page);
    } catch (_) {
      // Keep the old thumbnail.
    }
    if (mounted) setState(() {});
  }

  void _remove(int index) => setState(() => _pages.removeAt(index));

  void _move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= _pages.length || to >= _pages.length) return;
    setState(() {
      final page = _pages.removeAt(from);
      _pages.insert(to, page);
    });
  }

  Future<void> _create() async {
    if (_pages.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _progress = null;
    });
    try {
      final images = <Uint8List>[];
      for (var i = 0; i < _pages.length; i++) {
        final page = _pages[i];
        if (_pages.length > 1 && mounted) {
          setState(() => _progress = 'Preparing page ${i + 1} of ${_pages.length}');
        }
        images.add(await renderScan(page.source.full, page.corners, page.filter));
      }
      final pdfBytes = await buildImagesPdf(
        images,
        const ImagePdfOptions(pageSize: PageSizeOption.fit, margin: MarginOption.none),
      );
      final saved = await FileStore.instance.save(FileStore.timestampName('Scan'), pdfBytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      await showResultSheet(context, [saved]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      showMessage(context, 'Could not create the PDF. Try fewer pages.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 4 : 2;
    return ToolPage(
      title: 'Scan to PDF',
      icon: Icons.document_scanner_outlined,
      palette: TilePalette.teal,
      body: _pages.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                SectionCard(
                  child: EmptyState(
                    icon: Icons.document_scanner_outlined,
                    palette: TilePalette.teal,
                    title: 'Scan a document',
                    message: 'Take a photo of a page, set its corners, and pick a look. '
                        'Add more pages, then make one PDF.',
                    action: _preparing
                        ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                child: SecondaryButton(
                                  label: 'Gallery',
                                  icon: Icons.photo_library_outlined,
                                  onPressed: _fromGallery,
                                ),
                              ),
                              if (PlatformInfo.hasCamera) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SecondaryButton(
                                    label: 'Camera',
                                    icon: Icons.photo_camera_outlined,
                                    onPressed: _capture,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_preparing) const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    '${pageCountLabel(_pages.length)} · tap to crop, hold and drag to move',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return DragTarget<int>(
                        key: ObjectKey(page),
                        onWillAcceptWithDetails: (details) => details.data != index,
                        onAcceptWithDetails: (details) => _move(details.data, index),
                        builder: (context, candidates, rejected) {
                          final cell = _PageCell(
                            page: page,
                            number: index + 1,
                            highlight: candidates.isNotEmpty,
                            onTap: _busy ? null : () => _edit(page),
                            onRemove: _busy ? null : () => _remove(index),
                          );
                          return LongPressDraggable<int>(
                            data: index,
                            maxSimultaneousDrags: _busy ? 0 : 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 110,
                                height: 150,
                                child: Opacity(opacity: 0.92, child: _PageCell(page: page, number: index + 1)),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: 0.3, child: cell),
                            child: cell,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      bottom: _pages.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress != null) ...[
                  Text(_progress!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    if (PlatformInfo.hasCamera) ...[
                      Expanded(
                        child: SecondaryButton(
                          label: 'Camera',
                          icon: Icons.photo_camera_outlined,
                          onPressed: (_busy || _preparing) ? null : _capture,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SecondaryButton(
                        label: 'Gallery',
                        icon: Icons.photo_library_outlined,
                        onPressed: (_busy || _preparing) ? null : _fromGallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Create PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  busy: _busy,
                  onPressed: _preparing ? null : _create,
                ),
              ],
            ),
    );
  }
}

/// A scanned page in the grid, with its number and a remove button.
class _PageCell extends StatelessWidget {
  const _PageCell({
    required this.page,
    required this.number,
    this.highlight = false,
    this.onTap,
    this.onRemove,
  });

  final ScanPageData page;
  final int number;
  final bool highlight;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final thumbnail = page.thumbnail;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: highlight ? TilePalette.orange.color : AppColors.line,
                  width: highlight ? 3 : 1,
                ),
              ),
              child: thumbnail == null
                  ? const SizedBox.shrink()
                  : Image.memory(thumbnail, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 2,
              top: 2,
              child: IconButton(
                tooltip: 'Remove page $number',
                onPressed: onRemove,
                icon: const Icon(Icons.cancel_rounded),
                color: AppColors.danger,
                iconSize: 24,
              ),
            ),
        ],
      ),
    );
  }
}
