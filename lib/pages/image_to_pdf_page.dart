import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../file_store.dart';
import '../format.dart';
import '../image_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

/// Turns photos from the gallery or camera into one PDF.
class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  // Big enough for sharp A4 pages, small enough to keep the PDF light.
  static const double _maxSide = 2480;
  static const int _quality = 85;

  final _picker = ImagePicker();
  final List<XFile> _images = [];
  ImagePdfOptions _options = const ImagePdfOptions();
  bool _busy = false;

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() => _images.addAll(picked));
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open your photos.');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (!mounted || photo == null) return;
      setState(() => _images.add(photo));
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the camera.');
    }
  }

  void _remove(int index) => setState(() => _images.removeAt(index));

  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _images.removeAt(from);
      _images.insert(to, item);
    });
  }

  Future<void> _create() async {
    if (_images.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = <Uint8List>[];
      for (final image in _images) {
        bytes.add(await image.readAsBytes());
      }
      final pdfBytes = await buildImagesPdf(bytes, _options);
      final saved = await FileStore.instance.save(FileStore.timestampName('Images'), pdfBytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Could not create the PDF. Try fewer or smaller photos.');
    }
  }

  String get _summary {
    final count = pageCountLabel(_images.length);
    if (_options.pageSize == PageSizeOption.fit) return 'Output: $count · pages fit each photo';
    return 'Output: $count · ${_options.pageSize.label} · ${_options.orientation.label}';
  }

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 6 : 4;
    return ToolPage(
      title: 'Image to PDF',
      icon: Icons.image_outlined,
      palette: TilePalette.pink,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (_images.isEmpty)
            SectionCard(
              child: EmptyState(
                icon: Icons.photo_library_outlined,
                palette: TilePalette.pink,
                title: 'Add your photos',
                message: 'Pick photos from your gallery or take new ones. Each photo becomes one page.',
                action: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Gallery',
                        icon: Icons.photo_library_outlined,
                        onPressed: _pickFromGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Camera',
                        icon: Icons.photo_camera_outlined,
                        onPressed: _takePhoto,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    _images.length == 1 ? '1 photo selected' : '${_images.length} photos selected',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                const Text(
                  'Hold and drag to reorder',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _images.length + 2,
              itemBuilder: (context, index) {
                if (index == _images.length) {
                  return _AddCell(icon: Icons.add_rounded, label: 'Gallery', onTap: _pickFromGallery);
                }
                if (index == _images.length + 1) {
                  return _AddCell(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: _takePhoto);
                }
                return _PhotoCell(
                  key: ObjectKey(_images[index]),
                  image: _images[index],
                  index: index,
                  onMove: _move,
                  onRemove: () => _remove(index),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              children: [
                ChoiceGroup<PageSizeOption>(
                  label: 'Page size',
                  options: PageSizeOption.values,
                  selected: _options.pageSize,
                  labelOf: (o) => o.label,
                  onChanged: (o) => setState(() => _options = _options.copyWith(pageSize: o)),
                ),
                const SizedBox(height: 18),
                ChoiceGroup<OrientationOption>(
                  label: 'Orientation',
                  options: OrientationOption.values,
                  selected: _options.orientation,
                  labelOf: (o) => o.label,
                  enabled: _options.pageSize != PageSizeOption.fit,
                  onChanged: (o) => setState(() => _options = _options.copyWith(orientation: o)),
                ),
                const SizedBox(height: 18),
                ChoiceGroup<MarginOption>(
                  label: 'Margin',
                  options: MarginOption.values,
                  selected: _options.margin,
                  labelOf: (o) => o.label,
                  onChanged: (o) => setState(() => _options = _options.copyWith(margin: o)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_images.isNotEmpty) ...[
            Text(_summary, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: 'Create PDF',
            onPressed: _images.isEmpty ? null : _create,
            busy: _busy,
          ),
        ],
      ),
    );
  }
}

/// A photo in the grid that can be dragged onto another spot.
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    super.key,
    required this.image,
    required this.index,
    required this.onMove,
    required this.onRemove,
  });

  final XFile image;
  final int index;
  final void Function(int from, int to) onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != index,
          onAcceptWithDetails: (details) => onMove(details.data, index),
          builder: (context, candidates, rejected) {
            final tile = _PhotoTile(
              image: image,
              number: index + 1,
              highlighted: candidates.isNotEmpty,
              onRemove: onRemove,
            );
            return LongPressDraggable<int>(
              data: index,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Opacity(opacity: 0.9, child: _PhotoImage(image: image)),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: tile),
              child: tile,
            );
          },
        );
      },
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.image});

  final XFile image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(image.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 300,
        errorBuilder: (context, error, stack) => Container(
          color: TilePalette.pink.tint,
          child: Icon(Icons.image_outlined, color: TilePalette.pink.color),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.number,
    required this.highlighted,
    required this.onRemove,
  });

  final XFile image;
  final int number;
  final bool highlighted;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo $number',
      child: Stack(
        children: [
          Positioned.fill(child: _PhotoImage(image: image)),
          if (highlighted)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent, width: 3),
                ),
              ),
            ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '$number',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onRemove,
              tooltip: 'Remove photo $number',
              icon: const Icon(Icons.close_rounded, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                foregroundColor: Colors.white,
                minimumSize: const Size(28, 28),
                fixedSize: const Size(28, 28),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCell extends StatelessWidget {
  const _AddCell({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF8E89B0), width: 1.5),
    );
    return Material(
      color: Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.accent),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
