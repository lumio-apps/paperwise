import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../pdf_nup.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

enum _Border {
  none('No border'),
  thin('Thin border');

  const _Border(this.label);
  final String label;
}

/// Puts 2 or 4 pages of a PDF on each sheet, to save paper when printing.
class NUpPage extends StatefulWidget {
  const NUpPage({super.key});

  @override
  State<NUpPage> createState() => _NUpPageState();
}

class _NUpPageState extends State<NUpPage> {
  PickedPdf? _file;
  bool _landscape = false;
  SheetLayout _layout = SheetLayout.two;
  _Border _border = _Border.thin;
  bool _busy = false;
  String? _progress;

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
    if (file.isReady) {
      // The shape of the first page decides how the sheet is laid out.
      PdfDocument? document;
      try {
        document = await PdfTools.openDocument(file.path, file.name);
        final first = document.pages.first;
        _landscape = first.width > first.height;
      } catch (_) {
        _landscape = false;
      } finally {
        await document?.dispose();
      }
    }
    if (!mounted || _file != file) return;
    setState(() {});
  }

  Future<void> _create() async {
    final file = _file;
    if (file == null || !file.isReady || _busy) return;
    setState(() {
      _busy = true;
      _progress = 'Starting…';
    });
    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);
      final bytes = await PdfNUp.build(
        document,
        _layout,
        border: _border == _Border.thin,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = 'Drawing page ${done < total ? done + 1 : total} of $total');
        },
      );
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_${_layout.perSheet}up', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not make the sheets. Try a smaller PDF.');
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
      title: 'Pages per sheet',
      icon: Icons.grid_view_rounded,
      palette: TilePalette.teal,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.grid_view_rounded,
                palette: TilePalette.teal,
                title: 'Choose a PDF',
                message: 'Put 2 or 4 pages on one sheet and save paper when you print. Everything happens on your phone.',
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
                  Text(_progress!, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: 'Make sheets',
                  icon: Icons.grid_view_rounded,
                  onPressed: _create,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildOptions(PickedPdf file) {
    final pages = file.pageCount ?? 0;
    final sheets = (pages / _layout.perSheet).ceil();
    final grid = SheetGrid.of(_layout, pagesAreLandscape: _landscape);
    return [
      const SizedBox(height: 18),
      ChoiceGroup<SheetLayout>(
        label: 'Pages per sheet',
        options: SheetLayout.values,
        selected: _layout,
        labelOf: (l) => l.label,
        onChanged: (value) => setState(() => _layout = value),
        enabled: !_busy,
      ),
      const SizedBox(height: 16),
      ChoiceGroup<_Border>(
        label: 'Border around pages',
        options: _Border.values,
        selected: _border,
        labelOf: (b) => b.label,
        onChanged: (value) => setState(() => _border = value),
        enabled: !_busy,
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Row(
          children: [
            _SheetPreview(grid: grid, shown: pages < _layout.perSheet ? pages : _layout.perSheet, border: _border == _Border.thin),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('You will get'),
                  const SizedBox(height: 6),
                  Text(
                    sheets == 1 ? '1 sheet' : '$sheets sheets',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'from ${pages == 1 ? '1 page' : '$pages pages'}, A4 ${grid.landscape ? 'landscape' : 'portrait'}',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Pages are redrawn as pictures, so text on the new sheets can no longer be selected or searched. '
        'Your original file is not changed.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ];
  }
}

/// A small drawing of one sheet with its pages numbered.
class _SheetPreview extends StatelessWidget {
  const _SheetPreview({required this.grid, required this.shown, required this.border});

  final SheetGrid grid;
  final int shown;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final width = grid.landscape ? 128.0 : 92.0;
    final height = grid.landscape ? 92.0 : 128.0;
    var number = 0;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var r = 0; r < grid.rows; r++) ...[
            if (r > 0) const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < grid.columns; c++) ...[
                    if (c > 0) const SizedBox(width: 4),
                    Expanded(child: _cell(++number)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(int number) {
    final filled = number <= shown;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFE8EDFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: border && filled ? Border.all(color: const Color(0xFF8A86A6), width: 0.8) : null,
      ),
      child: filled
          ? Text('$number', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF3B5BDB)))
          : null,
    );
  }
}
