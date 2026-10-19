import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../pdf_info.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

/// Shows what a PDF says about itself (author, software, dates) and can save
/// a copy with those details removed.
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  PickedPdf? _file;
  PdfInfo? _info;
  bool _busy = false;
  String? _note;

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
      _info = null;
      _note = null;
    });
    await file.load();
    if (!mounted || _file != file) return;
    PdfInfo? info;
    if (file.isReady) {
      try {
        info = PdfInfo.read(await File(file.path).readAsBytes());
      } catch (_) {
        info = null;
      }
    }
    if (!mounted || _file != file) return;
    setState(() => _info = info);
  }

  Future<void> _clean() async {
    final file = _file;
    if (file == null || !file.isReady || _busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });
    PdfDocument? document;
    try {
      document = await PdfTools.openDocument(file.path, file.name);
      final bytes = await PdfTools.arrange(document, [
        for (var i = 0; i < document.pages.length; i++) PageEdit(i),
      ]);
      final after = PdfInfo.read(bytes);
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_clean', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _note = after.isClean
            ? 'Saved a copy without author, software or date details.'
            : 'Saved a copy, but it still has: ${_summary(after)}.';
      });
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not clean this PDF. Please try again.');
    } finally {
      await document?.dispose();
    }
  }

  String _summary(PdfInfo info) {
    final parts = <String>[
      for (final key in info.fields.keys) PdfInfo.labelOf(key).toLowerCase(),
      if (info.hasXmp) 'extra metadata',
    ];
    return parts.isEmpty ? 'some details' : parts.join(', ');
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return ToolPage(
      title: 'PDF info',
      icon: Icons.info_outline_rounded,
      palette: TilePalette.teal,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.info_outline_rounded,
                palette: TilePalette.teal,
                title: 'Choose a PDF',
                message: 'See the author, software and dates saved inside it, and remove them before you share.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(file: file, onChange: _busy ? null : _chooseFile),
            if (file.isReady) ..._buildDetails(),
          ],
        ],
      ),
      bottom: (file == null || !file.isReady)
          ? null
          : PrimaryButton(
              label: 'Save a clean copy',
              icon: Icons.cleaning_services_outlined,
              onPressed: _clean,
              busy: _busy,
            ),
    );
  }

  List<Widget> _buildDetails() {
    final info = _info;
    return [
      const SizedBox(height: 18),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('Saved inside this PDF'),
            const SizedBox(height: 8),
            if (info == null)
              Text('Could not read the details.', style: TextStyle(fontSize: 15, color: AppColors.muted))
            else ...[
              if (info.fields.isEmpty && info.readable)
                Text('No author, software or date details found.',
                    style: TextStyle(fontSize: 15, color: AppColors.success)),
              for (final entry in info.fields.entries) _row(PdfInfo.labelOf(entry.key), entry.value),
              if (info.hasXmp) _row('Extra metadata', 'Present'),
              if (!info.readable)
                Text(
                  'The details are packed in a way Paperwise cannot read here. A clean copy will still drop them.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
            ],
            if (_note != null) ...[
              const SizedBox(height: 10),
              Text(_note!, style: TextStyle(fontSize: 14, color: AppColors.success)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'A clean copy is rebuilt page by page, so these details are left out. Text stays selectable, but '
        'bookmarks, links and form fields are not kept. Your original file is not changed.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ];
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ],
      ),
    );
  }
}
