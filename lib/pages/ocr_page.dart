import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../file_store.dart';
import '../pdf_ocr.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

enum _OcrMode { searchable, copyText }

/// Reads the text of scanned pages: makes the PDF searchable, or shows the text to copy.
class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  PickedPdf? _file;
  _OcrMode _mode = _OcrMode.searchable;
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
    if (mounted && _file == file) setState(() {});
  }

  Future<void> _start() async {
    final file = _file;
    if (file == null || !file.isReady || _busy) return;
    setState(() {
      _busy = true;
      _progress = 'Starting…';
    });
    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);
      final outcome = await PdfOcr.read(
        document,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = 'Reading page ${math.min(done + 1, total)} of $total');
        },
      );
      if (!mounted) return;

      if (_mode == _OcrMode.copyText) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        if (!outcome.foundText) {
          showMessage(context, 'No text was found on these pages.');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _TextResultPage(text: outcome.fullText)),
        );
        return;
      }

      if (outcome.pagesRead == 0) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        showMessage(context, 'This PDF already has searchable text. Nothing was saved.');
        return;
      }
      setState(() => _progress = 'Saving…');
      final bytes = await PdfOcr.makeSearchable(document, outcome);
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_searchable', bytes);
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
      _failed('Could not read the text in this PDF. Please try again.');
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
      title: 'Text from scans',
      icon: Icons.text_fields_rounded,
      palette: TilePalette.pink,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.text_fields_rounded,
                palette: TilePalette.pink,
                title: 'Choose a scanned PDF',
                message: 'Read the words on scanned pages. Everything happens on your phone, with no internet.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: _busy ? null : _chooseFile),
            if (file.isReady) ..._options(),
          ],
        ],
      ),
      bottom: (file == null || !file.isReady)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress != null) ...[
                  Text(_progress!.tr, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: _mode == _OcrMode.searchable ? 'Make searchable' : 'Read text',
                  icon: Icons.text_fields_rounded,
                  onPressed: _start,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  List<Widget> _options() {
    return [
      const SizedBox(height: 18),
      ChoiceGroup<_OcrMode>(
        label: 'What do you want?',
        options: _OcrMode.values,
        selected: _mode,
        labelOf: (m) => (m == _OcrMode.searchable ? 'Searchable PDF' : 'Copy text').tr,
        onChanged: (m) => setState(() => _mode = m),
        enabled: !_busy,
      ),
      const SizedBox(height: 8),
      Text(
        (_mode == _OcrMode.searchable
                ? 'Your scan stays exactly as it is. The words are added invisibly behind it, so you can search and copy from the PDF.'
                : 'Shows the text of the whole PDF, ready to copy or share.')
            .tr,
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reads English text. Clear, straight scans work best. Pages that already have text are skipped. '
                'Big PDFs take a while, so keep the screen on.'
                    .tr,
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Shows the recognized text so it can be selected, copied or shared.
class _TextResultPage extends StatelessWidget {
  const _TextResultPage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Text from scans',
      icon: Icons.text_fields_rounded,
      palette: TilePalette.pink,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          SectionCard(
            child: SelectableText(
              text,
              style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.ink),
            ),
          ),
        ],
      ),
      bottom: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Share',
              icon: Icons.share_outlined,
              onPressed: () => SharePlus.instance.share(ShareParams(text: text)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: 'Copy',
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) showMessage(context, 'Text copied.');
              },
            ),
          ),
        ],
      ),
    );
  }
}
