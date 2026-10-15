import 'package:flutter/material.dart';

import '../file_store.dart';
import '../format.dart';
import '../page_ranges.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

enum SplitMode {
  ranges('By range'),
  everyPage('Every page');

  const SplitMode(this.label);
  final String label;
}

/// Cuts one PDF into smaller PDFs.
class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  // Draw at most this many page squares; very long PDFs get a short note instead.
  static const _maxPagesShown = 300;
  static const _maxPartsShown = 12;

  final _rangeController = TextEditingController();
  PickedPdf? _file;
  SplitMode _mode = SplitMode.ranges;
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
      if (count != null) _rangeController.text = suggestedRanges(count);
    });
  }

  RangeParseResult? get _parsed {
    final count = _file?.pageCount;
    if (count == null || _mode != SplitMode.ranges) return null;
    return parsePageRanges(_rangeController.text, count);
  }

  List<PageRange> get _ranges {
    final file = _file;
    final count = file?.pageCount;
    if (file == null || count == null || !file.isReady) return const [];
    if (_mode == SplitMode.everyPage) return everyPage(count);
    final parsed = _parsed;
    return parsed != null && parsed.isValid ? parsed.ranges : const [];
  }

  Future<void> _split() async {
    final file = _file;
    final ranges = _ranges;
    if (file == null || ranges.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _progress = null;
    });

    final base = FileStore.cleanName(file.name);
    final mode = _mode;
    final results = <OutputFile>[];
    try {
      await PdfTools.split(file.path, file.name, ranges, (index, bytes) async {
        final suffix = mode == SplitMode.everyPage ? 'page${ranges[index].start}' : 'part${index + 1}';
        results.add(await FileStore.instance.save('${base}_$suffix', bytes));
        if (mounted && ranges.length > 1) {
          setState(() => _progress = 'Saved ${index + 1} of ${ranges.length}');
        }
      });
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      await showResultSheet(context, results);
    } on PdfToolException catch (e) {
      await _failed(e.message);
    } catch (_) {
      await _failed('Could not split this PDF. Please try again.');
    }
  }

  Future<void> _failed(String message) async {
    await FileStore.instance.load();
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
    final ranges = _ranges;

    return ToolPage(
      title: 'Split PDF',
      icon: Icons.call_split_rounded,
      palette: TilePalette.orange,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.call_split_rounded,
                palette: TilePalette.orange,
                title: 'Choose a PDF to split',
                message: 'Cut one PDF into smaller files by page ranges, or make one file per page.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            _FileCard(file: file, onChange: _busy ? null : _chooseFile),
            if (file.isReady) ..._buildOptions(file, ranges),
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
                  label: ranges.isEmpty ? 'Split PDF' : 'Split into ${fileCountLabel(ranges.length)}',
                  onPressed: ranges.isEmpty ? null : _split,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildOptions(PickedPdf file, List<PageRange> ranges) {
    final count = file.pageCount ?? 0;
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 10 : 6;
    final shown = count < _maxPagesShown ? count : _maxPagesShown;

    return [
      const SizedBox(height: 18),
      ChoiceGroup<SplitMode>(
        label: 'How to split',
        options: SplitMode.values,
        selected: _mode,
        labelOf: (m) => m.label,
        onChanged: (m) => setState(() => _mode = m),
      ),
      if (_mode == SplitMode.ranges) ...[
        const SizedBox(height: 18),
        const FieldLabel('Page ranges'),
        const SizedBox(height: 8),
        TextField(
          controller: _rangeController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'For example 1-3, 4-8, 9',
            helperText: 'Each range becomes a new file.',
            errorText: _parsed?.error,
            errorMaxLines: 2,
          ),
        ),
      ],
      const SizedBox(height: 20),
      const FieldLabel('Pages'),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 58,
        ),
        itemCount: shown,
        itemBuilder: (context, index) {
          final page = index + 1;
          final part = ranges.indexWhere((r) => r.contains(page));
          return _PageSquare(
            number: page,
            palette: part < 0 ? null : TilePalette.cycle[part % TilePalette.cycle.length],
          );
        },
      ),
      if (count > shown) ...[
        const SizedBox(height: 8),
        Text(
          '+ ${pageCountLabel(count - shown)} more',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
      if (ranges.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          '${fileCountLabel(ranges.length)} will be created',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < ranges.length && i < _maxPartsShown; i++)
              _PartChip(
                title: 'Part ${i + 1}',
                range: ranges[i],
                palette: TilePalette.cycle[i % TilePalette.cycle.length],
              ),
            if (ranges.length > _maxPartsShown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '+ ${ranges.length - _maxPartsShown} more',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ],
    ];
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file, required this.onChange});

  final PickedPdf file;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final error = file.error;
    final String details;
    if (error != null) {
      details = error;
    } else if (file.isLoading) {
      details = 'Reading…';
    } else {
      details = '${pageCountLabel(file.pageCount ?? 0)} · ${formatBytes(file.sizeBytes)}';
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: error != null ? AppColors.danger : AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(
              'Change',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageSquare extends StatelessWidget {
  const _PageSquare({required this.number, required this.palette});

  final int number;

  /// Null when the page is not in any range.
  final TilePalette? palette;

  @override
  Widget build(BuildContext context) {
    final palette = this.palette;
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: palette?.tint ?? AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette?.color ?? AppColors.line, width: 1.5),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette == null ? AppColors.muted : AppColors.ink,
        ),
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({required this.title, required this.range, required this.palette});

  final String title;
  final PageRange range;
  final TilePalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: palette.color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(width: 6),
          Text(range.label, style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}
