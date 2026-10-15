import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../pdf_editor.dart';
import '../pdf_fonts.dart';
import '../pdf_stamper.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;
import 'place_page.dart';

enum _Mode {
  place('Text & sign'),
  numbers('Page numbers'),
  headerFooter('Header & footer');

  const _Mode(this.label);
  final String label;
}

enum _NumberFormat {
  plain('1', '{n}'),
  page('Page 1', 'Page {n}'),
  of('Page 1 of N', 'Page {n} of {total}');

  const _NumberFormat(this.label, this.template);
  final String label;
  final String template;
}

enum _TextSize {
  small('Small', 9),
  medium('Medium', 11),
  large('Large', 14);

  const _TextSize(this.label, this.points);
  final String label;
  final double points;
}

enum _Align {
  left('Left', HAnchor.left),
  center('Center', HAnchor.center),
  right('Right', HAnchor.right);

  const _Align(this.label, this.anchor);
  final String label;
  final HAnchor anchor;
}

enum _Vertical {
  top('Top', true),
  bottom('Bottom', false);

  const _Vertical(this.label, this.atTop);
  final String label;
  final bool atTop;
}

enum _Family {
  sans('Sans', PdfFont.sans),
  serif('Serif', PdfFont.serif);

  const _Family(this.label, this.font);
  final String label;
  final PdfFont font;
}

/// Edit a PDF: add text and a signature, page numbers, header and footer.
class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final _startPage = TextEditingController(text: '1');
  final _header = TextEditingController();
  final _footer = TextEditingController();

  PickedPdf? _file;
  _Mode _mode = _Mode.place;
  bool _busy = false;

  _Vertical _vertical = _Vertical.bottom;
  _Align _numberAlign = _Align.center;
  _NumberFormat _format = _NumberFormat.of;
  _TextSize _size = _TextSize.medium;

  _Align _headerFooterAlign = _Align.center;
  _Family _family = _Family.sans;

  @override
  void dispose() {
    _startPage.dispose();
    _header.dispose();
    _footer.dispose();
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
    if (mounted && _file == file) setState(() {});
  }

  int get _fromPage {
    final value = int.tryParse(_startPage.text.trim()) ?? 1;
    final count = _file?.pageCount ?? 1;
    return value.clamp(1, count < 1 ? 1 : count).toInt();
  }

  String? get _problem {
    final file = _file;
    if (file == null) return 'Choose a PDF first.';
    if (file.isLoading) return 'Reading…';
    if (!file.isReady) return file.error ?? 'This PDF could not be read.';
    switch (_mode) {
      case _Mode.place:
        return null;
      case _Mode.numbers:
        return null;
      case _Mode.headerFooter:
        final header = _header.text;
        final footer = _footer.text;
        if (header.trim().isEmpty && footer.trim().isEmpty) return 'Type a header or a footer.';
        if (!PdfFont.canWrite(header) || !PdfFont.canWrite(footer)) {
          return 'Use letters, numbers and keyboard symbols only.';
        }
        return null;
    }
  }

  Future<void> _run() async {
    final file = _file;
    if (file == null || _problem != null || _busy) return;

    if (_mode == _Mode.place) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlacePage(file: file)));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    PdfDocument? document;
    try {
      final StampPlan plan;
      final String suffix;
      if (_mode == _Mode.numbers) {
        plan = StampPlan(
          everyPage: [
            EveryPageText(
              template: _format.template,
              horizontal: _numberAlign.anchor,
              atTop: _vertical.atTop,
              font: PdfFont.sans,
              size: _size.points,
              color: StampColor.gray,
              fromPage: _fromPage,
            ),
          ],
        );
        suffix = 'numbered';
      } else {
        final font = _family.font;
        plan = StampPlan(
          everyPage: [
            if (_header.text.trim().isNotEmpty)
              EveryPageText(
                template: _header.text.trim(),
                horizontal: _headerFooterAlign.anchor,
                atTop: true,
                font: font,
                size: _size.points,
                color: StampColor.gray,
              ),
            if (_footer.text.trim().isNotEmpty)
              EveryPageText(
                template: _footer.text.trim(),
                horizontal: _headerFooterAlign.anchor,
                atTop: false,
                font: font,
                size: _size.points,
                color: StampColor.gray,
              ),
          ],
        );
        suffix = 'edited';
      }
      document = await PdfTools.openDocument(file.path, file.name);
      final bytes = await PdfEditor.apply(document, plan);
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_$suffix', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    } finally {
      await document?.dispose();
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final problem = _problem;
    final label = switch (_mode) {
      _Mode.place => 'Open page editor',
      _Mode.numbers => 'Add page numbers',
      _Mode.headerFooter => 'Add header and footer',
    };
    return ToolPage(
      title: 'Edit and sign',
      icon: Icons.draw_outlined,
      palette: TilePalette.yellow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.draw_outlined,
                palette: TilePalette.yellow,
                title: 'Choose a PDF',
                message: 'Add text, your signature, page numbers, a header or a footer. Everything happens on your phone.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: _busy ? null : _chooseFile),
            const SizedBox(height: 18),
            ChoiceGroup<_Mode>(
              label: 'What do you want to add?',
              options: _Mode.values,
              selected: _mode,
              labelOf: (m) => m.label,
              onChanged: (m) => setState(() => _mode = m),
              enabled: !_busy,
            ),
            const SizedBox(height: 18),
            ..._buildMode(),
          ],
        ],
      ),
      bottom: file == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (problem != null && file.isReady) ...[
                  Text(problem, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: label,
                  icon: Icons.check_rounded,
                  onPressed: problem == null ? _run : null,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _buildMode() {
    switch (_mode) {
      case _Mode.place:
        return [
          Text(
            'Open the page editor to type text anywhere on a page, or draw your signature and place it. '
            'The text already in your PDF stays selectable. Your original file is not changed.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ];
      case _Mode.numbers:
        return [
          ChoiceGroup<_Vertical>(
            label: 'Where',
            options: _Vertical.values,
            selected: _vertical,
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _vertical = v),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_Align>(
            label: 'Side',
            options: _Align.values,
            selected: _numberAlign,
            labelOf: (a) => a.label,
            onChanged: (a) => setState(() => _numberAlign = a),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_NumberFormat>(
            label: 'Look',
            options: _NumberFormat.values,
            selected: _format,
            labelOf: (f) => f.label,
            onChanged: (f) => setState(() => _format = f),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_TextSize>(
            label: 'Size',
            options: _TextSize.values,
            selected: _size,
            labelOf: (s) => s.label,
            onChanged: (s) => setState(() => _size = s),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _startPage,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Start on page',
              helperText: 'Earlier pages, like a cover, get no number. This PDF has ${_file?.pageCount ?? 0} pages.',
              helperMaxLines: 2,
            ),
          ),
        ];
      case _Mode.headerFooter:
        return [
          TextField(
            controller: _header,
            enabled: !_busy,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Header (top of every page)'),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _footer,
            enabled: !_busy,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Footer (bottom of every page)',
              helperText: 'Use {n} for the page number and {total} for the number of pages.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_Align>(
            label: 'Side',
            options: _Align.values,
            selected: _headerFooterAlign,
            labelOf: (a) => a.label,
            onChanged: (a) => setState(() => _headerFooterAlign = a),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_Family>(
            label: 'Font',
            options: _Family.values,
            selected: _family,
            labelOf: (f) => f.label,
            onChanged: (f) => setState(() => _family = f),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<_TextSize>(
            label: 'Size',
            options: _TextSize.values,
            selected: _size,
            labelOf: (s) => s.label,
            onChanged: (s) => setState(() => _size = s),
            enabled: !_busy,
          ),
        ];
    }
  }
}
