import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../format.dart';
import '../pdf_compress.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

/// Makes a PDF smaller, and shows the expected size before you start.
class CompressPage extends StatefulWidget {
  const CompressPage({super.key});

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  PickedPdf? _file;
  CompressLevel _level = CompressLevel.balanced;
  final Map<CompressLevel, int> _estimates = {};
  bool _estimating = false;
  bool _busy = false;
  String? _progress;
  String? _summary;
  int _token = 0;

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
      _estimates.clear();
      _summary = null;
    });
    await file.load();
    if (!mounted || _file != file) return;
    setState(() {});
    if (file.isReady) _estimate();
  }

  void _setLevel(CompressLevel level) {
    setState(() => _level = level);
    _estimate();
  }

  Future<void> _estimate() async {
    final file = _file;
    final level = _level;
    if (file == null || !file.isReady || _estimates.containsKey(level)) return;
    final token = ++_token;
    setState(() => _estimating = true);
    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);
      final bytes = await PdfCompressor.estimate(document, level);
      if (!mounted || token != _token) return;
      setState(() {
        _estimates[level] = bytes;
        _estimating = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _estimating = false);
    } finally {
      await document?.dispose();
    }
  }

  Future<void> _compress() async {
    final file = _file;
    if (file == null || !file.isReady || _busy) return;
    setState(() {
      _busy = true;
      _progress = 'Starting…';
      _summary = null;
    });
    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);
      final bytes = await PdfCompressor.compress(
        document,
        _level,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = 'Compressing page ${math.min(done + 1, total)} of $total');
        },
      );
      if (!mounted) return;

      if (bytes.length >= file.sizeBytes * 0.95) {
        setState(() {
          _busy = false;
          _progress = null;
          _summary = 'This PDF is already small, so compressing would not help. Nothing was saved.';
        });
        return;
      }

      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_compressed', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      final percent = ((1 - bytes.length / file.sizeBytes) * 100).round();
      setState(() {
        _busy = false;
        _progress = null;
        _summary = '${formatBytes(file.sizeBytes)} → ${formatBytes(bytes.length)} ($percent% smaller)';
      });
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not compress this PDF. Try Strong, or a smaller file.');
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
    return ToolPage(
      title: 'Compress PDF',
      icon: Icons.compress_rounded,
      palette: TilePalette.green,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.compress_rounded,
                palette: TilePalette.green,
                title: 'Choose a PDF',
                message: 'Make it smaller for sharing. Everything happens on your phone.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: _busy ? null : _chooseFile),
            if (file.isReady) ..._buildOptions(file),
          ],
        ],
      ),
      bottom: (file == null || !file.isReady)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress != null) ...[
                  Text(_progress!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: 'Compress PDF',
                  icon: Icons.compress_rounded,
                  onPressed: _compress,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildOptions(PickedPdf file) {
    final estimate = _estimates[_level];
    return [
      const SizedBox(height: 18),
      ChoiceGroup<CompressLevel>(
        label: 'Compression',
        options: CompressLevel.values,
        selected: _level,
        labelOf: (l) => l.label,
        onChanged: _setLevel,
        enabled: !_busy,
      ),
      const SizedBox(height: 4),
      Text(_level.hint, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      const SizedBox(height: 16),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Expected size'),
            const SizedBox(height: 6),
            Text(
              estimate != null
                  ? '${formatBytes(file.sizeBytes)} → about ${formatBytes(estimate)}'
                  : (_estimating ? 'Working it out…' : 'Not available'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            if (estimate != null && estimate >= file.sizeBytes * 0.95) ...[
              const SizedBox(height: 6),
              const Text(
                'This PDF will not get much smaller, so nothing will be saved.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 10),
              Text(_summary!, style: const TextStyle(fontSize: 14, color: AppColors.success)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'The size is an estimate from a few pages. Pages are redrawn as pictures, so text can no longer be '
        'selected or searched. Compression works best on scans and photo PDFs.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ];
  }
}
