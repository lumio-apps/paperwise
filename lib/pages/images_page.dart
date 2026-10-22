import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../file_store.dart';
import '../format.dart';
import '../image_result_sheet.dart';
import '../pdf_images.dart';
import '../picked_pdf.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

/// Saves the pictures stored inside a PDF as separate files.
class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});

  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  // Reading a huge PDF into memory could crash the app on small phones.
  static const int _maxBytes = 250 * 1024 * 1024;
  static const int _previewCount = 12;

  PickedPdf? _file;
  ImageScan? _scan;
  bool _scanning = false;
  bool _busy = false;
  String? _problem;

  Future<void> _chooseFile() async {
    final List<PickedPdf> picked;
    try {
      picked = await pickPdfFiles(multiple: false);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the file picker.');
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    setState(() {
      _file = file;
      _scan = null;
      _problem = null;
    });
    await file.load();
    if (!mounted || _file != file) return;
    setState(() {});
    if (file.isReady) await _find(file);
  }

  Future<void> _find(PickedPdf file) async {
    if (file.sizeBytes > _maxBytes) {
      setState(() => _problem = 'This PDF is too big to search for pictures on a phone.');
      return;
    }
    setState(() => _scanning = true);
    try {
      final data = await File(file.path).readAsBytes();
      final scan = await PdfImages.scan(data);
      if (!mounted || _file != file) return;
      setState(() {
        _scan = scan;
        _scanning = false;
      });
    } on LockedPdfException {
      if (!mounted || _file != file) return;
      setState(() {
        _scanning = false;
        _problem = 'This PDF is locked. Unlock it with Protect first, then try again.';
      });
    } catch (_) {
      if (!mounted || _file != file) return;
      setState(() {
        _scanning = false;
        _problem = 'Could not look for pictures in this PDF.';
      });
    }
  }

  Future<void> _save() async {
    final file = _file;
    final scan = _scan;
    if (file == null || scan == null || scan.images.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final temp = await getTemporaryDirectory();
      final folder = Directory('${temp.path}/paperwise_images');
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);

      final base = FileStore.cleanName(file.name);
      final digits = scan.images.length.toString().length;
      final paths = <String>[];
      for (var i = 0; i < scan.images.length; i++) {
        final image = scan.images[i];
        final number = (i + 1).toString().padLeft(digits, '0');
        final out = File('${folder.path}/${base}_image$number.${image.extension}');
        await out.writeAsBytes(image.bytes, flush: true);
        paths.add(out.path);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await showImagesResultSheet(context, paths);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Could not save the pictures. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final scan = _scan;
    final canSave = scan != null && scan.images.isNotEmpty;
    return ToolPage(
      title: 'Images from PDF',
      icon: Icons.collections_outlined,
      palette: TilePalette.yellow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.collections_outlined,
                palette: TilePalette.yellow,
                title: 'Choose a PDF',
                message: 'Save the photos and pictures inside a PDF as separate files, exactly as they are stored.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: (_busy || _scanning) ? null : _chooseFile),
            if (file.isReady) ..._buildResult(scan),
          ],
        ],
      ),
      bottom: canSave
          ? PrimaryButton(
              label: scan.images.length == 1 ? 'Save 1 picture' : 'Save ${scan.images.length} pictures',
              icon: Icons.download_rounded,
              onPressed: _save,
              busy: _busy,
            )
          : null,
    );
  }

  List<Widget> _buildResult(ImageScan? scan) {
    if (_problem != null) {
      return [
        const SizedBox(height: 18),
        SectionCard(child: Text(_problem!, style: TextStyle(fontSize: 15, color: AppColors.danger))),
      ];
    }
    if (_scanning || scan == null) {
      return [
        const SizedBox(height: 18),
        SectionCard(
          child: Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Looking for pictures…', style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ),
            ],
          ),
        ),
      ];
    }

    final images = scan.images;
    if (images.isEmpty) {
      return [
        const SizedBox(height: 18),
        SectionCard(
          child: Text(
            scan.skipped > 0
                ? 'Found ${scan.skipped} pictures, but in a format Paperwise cannot save yet. '
                    'Try PDF to image to save whole pages instead.'
                : 'No pictures found. This PDF has only text and shapes. Use PDF to image to save whole pages.',
            style: TextStyle(fontSize: 15, height: 1.35, color: AppColors.muted),
          ),
        ),
      ];
    }

    final totalBytes = images.fold<int>(0, (sum, i) => sum + i.bytes.length);
    final shown = images.take(_previewCount).toList();
    return [
      const SizedBox(height: 18),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Found in this PDF'),
            const SizedBox(height: 6),
            Text(
              '${images.length == 1 ? '1 picture' : '${images.length} pictures'} · ${formatBytes(totalBytes)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final image in shown) _Thumb(bytes: image.bytes)],
            ),
            if (images.length > shown.length) ...[
              const SizedBox(height: 8),
              Text(
                '+ ${images.length - shown.length} more',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            if (scan.skipped > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${scan.skipped} more could not be saved because of their format.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Photos come out exactly as they are stored in the PDF, so there is no loss of quality. '
        'Pictures that only act as see-through masks are left out.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ];
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes,
        width: 72,
        height: 72,
        cacheWidth: 144,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: 72,
          height: 72,
          color: AppColors.track,
          child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
        ),
      ),
    );
  }
}
