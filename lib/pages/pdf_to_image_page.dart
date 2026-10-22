import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../format.dart';
import '../image_result_sheet.dart';
import '../image_tools.dart';
import '../page_ranges.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../save_folder.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Format {
  jpg('JPG', 'jpg'),
  png('PNG', 'png');

  const _Format(this.label, this.extension);
  final String label;
  final String extension;
}

enum _Quality {
  standard('Standard', 150),
  high('High', 220),
  best('Best', 300);

  const _Quality(this.label, this.dpi);
  final String label;
  final int dpi;
}

enum _Pages {
  all('All pages'),
  some('Some pages');

  const _Pages(this.label);
  final String label;
}

/// Saves the pages of a PDF as JPG or PNG pictures.
class PdfToImagePage extends StatefulWidget {
  const PdfToImagePage({super.key});

  @override
  State<PdfToImagePage> createState() => _PdfToImagePageState();
}

class _PdfToImagePageState extends State<PdfToImagePage> {
  // Keeps one picture from using too much memory, even for huge pages.
  static const double _maxPixels = 24e6;

  final _rangeController = TextEditingController();
  PickedPdf? _file;
  _Format _format = _Format.jpg;
  _Quality _quality = _Quality.standard;
  _Pages _pages = _Pages.all;
  bool _busy = false;
  String? _progress;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

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
    setState(() => _file = file);
    await file.load();
    if (!mounted || _file != file) return;
    setState(() {
      final count = file.pageCount;
      if (count != null) _rangeController.text = count == 1 ? '1' : '1-$count';
    });
  }

  RangeParseResult? get _parsed {
    final count = _file?.pageCount;
    if (count == null || _pages != _Pages.some) return null;
    return parsePageRanges(_rangeController.text, count);
  }

  /// Page numbers to save, starting at 1.
  List<int> get _selectedPages {
    final file = _file;
    final count = file?.pageCount;
    if (file == null || count == null || !file.isReady) return const [];
    if (_pages == _Pages.all) return [for (var i = 1; i <= count; i++) i];
    final parsed = _parsed;
    if (parsed == null || !parsed.isValid) return const [];
    final numbers = <int>{};
    for (final range in parsed.ranges) {
      for (var n = range.start; n <= range.end; n++) {
        numbers.add(n);
      }
    }
    return numbers.toList()..sort();
  }

  Future<void> _convert() async {
    final file = _file;
    final pages = _selectedPages;
    if (file == null || pages.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _progress = null;
    });

    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);

      final temp = await getTemporaryDirectory();
      final folder = Directory('${temp.path}/paperwise_images');
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);

      final base = FileStore.cleanName(file.name);
      final digits = pages.last.toString().length;
      final paths = <String>[];

      for (var i = 0; i < pages.length; i++) {
        final number = pages[i];
        if (mounted) setState(() => _progress = 'Saving page ${i + 1} of ${pages.length}');

        final page = document.pages[number - 1];
        final scale = _quality.dpi / 72.0;
        var width = page.width * scale;
        var height = page.height * scale;
        if (width * height > _maxPixels) {
          final shrink = math.sqrt(_maxPixels / (width * height));
          width *= shrink;
          height *= shrink;
        }

        final rendered = await page.render(
          width: width.round(),
          height: height.round(),
          fullWidth: width,
          fullHeight: height,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) throw const PdfToolException('A page could not be drawn.');
        final Uint8List bytes;
        try {
          bytes = await encodeBgraPixels(
            rendered.pixels,
            rendered.width,
            rendered.height,
            png: _format == _Format.png,
          );
        } finally {
          rendered.dispose();
        }

        final name = pages.length == 1
            ? '$base.${_format.extension}'
            : '${base}_page${number.toString().padLeft(digits, '0')}.${_format.extension}';
        final out = File('${folder.path}/$name');
        await out.writeAsBytes(bytes, flush: true);
        unawaited(SaveFolder.copyIfSet(out.path, name, _format == _Format.png ? 'image/png' : 'image/jpeg'));
        paths.add(out.path);
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      await showImagesResultSheet(context, paths);
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not save the pages. Try a lower quality or fewer pages.');
    } finally {
      await document?.dispose();
    }
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
    });
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final pages = _selectedPages;

    return ToolPage(
      title: 'PDF to image',
      icon: Icons.photo_size_select_actual_outlined,
      palette: TilePalette.green,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.photo_size_select_actual_outlined,
                palette: TilePalette.green,
                title: 'Choose a PDF',
                message: 'Save its pages as JPG or PNG pictures. Everything happens on your phone.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: _busy ? null : _chooseFile),
            if (file.isReady) ..._buildOptions(file),
          ],
        ],
      ),
      bottom: file == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress != null) ...[
                  Text(_progress!, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: pages.isEmpty ? 'Save as images' : 'Save ${pageCountLabel(pages.length)} as ${_format.label}',
                  icon: Icons.image_outlined,
                  onPressed: pages.isEmpty ? null : _convert,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildOptions(PickedPdf file) {
    return [
      const SizedBox(height: 18),
      ChoiceGroup<_Format>(
        label: 'Picture type',
        options: _Format.values,
        selected: _format,
        labelOf: (f) => f.label,
        onChanged: (f) => setState(() => _format = f),
        enabled: !_busy,
      ),
      const SizedBox(height: 4),
      Text(
        _format == _Format.jpg ? 'Smaller files, good for photos and sharing.' : 'Sharper text, bigger files.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      ChoiceGroup<_Quality>(
        label: 'Quality',
        options: _Quality.values,
        selected: _quality,
        labelOf: (q) => q.label,
        onChanged: (q) => setState(() => _quality = q),
        enabled: !_busy,
      ),
      const SizedBox(height: 18),
      ChoiceGroup<_Pages>(
        label: 'Pages',
        options: _Pages.values,
        selected: _pages,
        labelOf: (p) => p.label,
        onChanged: (p) => setState(() => _pages = p),
        enabled: !_busy,
      ),
      if (_pages == _Pages.some) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _rangeController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'For example 1-3, 7',
            helperText: 'This PDF has ${pageCountLabel(file.pageCount ?? 0)}.',
            errorText: _parsed?.error,
            errorMaxLines: 2,
          ),
        ),
      ],
    ];
  }
}

/// The chosen PDF with its size and a "Change" button.
class PickedPdfCard extends StatelessWidget {
  const PickedPdfCard({super.key, required this.file, required this.onChange, this.detail});

  final PickedPdf file;
  final VoidCallback? onChange;

  /// Replaces the default line under the name, for example "Locked".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final String line;
    if (detail != null) {
      line = detail!;
    } else if (file.error != null) {
      line = file.error!;
    } else if (file.isLoading) {
      line = 'Reading…';
    } else {
      line = '${pageCountLabel(file.pageCount ?? 0)} · ${formatBytes(file.sizeBytes)}';
    }
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          const PageThumb(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  line,
                  style: TextStyle(fontSize: 13, color: (file.error != null && detail == null) ? AppColors.danger : AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}
