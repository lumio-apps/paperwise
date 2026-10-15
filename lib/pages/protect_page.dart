import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../format.dart';
import '../pdf_protect.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

enum _Mode {
  lock('Lock'),
  unlock('Unlock'),
  watermark('Watermark');

  const _Mode(this.label);
  final String label;
}

enum _MarkType {
  text('Text'),
  image('Picture');

  const _MarkType(this.label);
  final String label;
}

/// Lock a PDF with a password, remove a password, or stamp a watermark.
class ProtectPage extends StatefulWidget {
  const ProtectPage({super.key});

  @override
  State<ProtectPage> createState() => _ProtectPageState();
}

class _ProtectPageState extends State<ProtectPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _markText = TextEditingController(text: 'CONFIDENTIAL');

  PickedPdf? _file;
  _Mode _mode = _Mode.lock;
  bool _hidden = true;
  bool _busy = false;
  String? _progress;

  _MarkType _markType = _MarkType.text;
  Uint8List? _markImage;
  String? _markImageName;
  WatermarkSize _size = WatermarkSize.medium;
  WatermarkOpacity _opacity = WatermarkOpacity.medium;
  WatermarkLayout _layout = WatermarkLayout.center;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _markText.dispose();
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
    setState(() {
      _file = file;
      _password.clear();
      _confirm.clear();
    });
    await file.load();
    if (!mounted || _file != file) return;
    setState(() {
      // A locked PDF can only be unlocked, so go there straight away.
      if (file.locked) _mode = _Mode.unlock;
    });
  }

  Future<void> _chooseMarkImage() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked == null || !mounted) return;
      final path = picked.path;
      final bytes = path != null ? await File(path).readAsBytes() : await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _markImage = bytes;
        _markImageName = picked.name;
      });
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open that picture.');
    }
  }

  /// Why the button is off, or null when everything is filled in.
  String? get _problem {
    final file = _file;
    if (file == null || _busy) return 'Choose a PDF first.';
    if (file.isLoading) return 'Reading…';
    switch (_mode) {
      case _Mode.lock:
        if (!file.isReady) return file.error ?? 'Reading…';
        if (_password.text.length < 4) return 'Use at least 4 characters.';
        if (_password.text != _confirm.text) return 'The two passwords are different.';
        return null;
      case _Mode.unlock:
        if (!file.locked) return 'This PDF is not locked.';
        if (_password.text.isEmpty) return 'Type the password.';
        return null;
      case _Mode.watermark:
        if (!file.isReady) return file.error ?? 'Reading…';
        if (_markType == _MarkType.text && _markText.text.trim().isEmpty) return 'Type the watermark text.';
        if (_markType == _MarkType.image && _markImage == null) return 'Choose a picture.';
        return null;
    }
  }

  Future<void> _run() async {
    final file = _file;
    if (file == null || _problem != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _progress = 'Starting…';
    });

    void progress(int done, int total) {
      if (mounted) setState(() => _progress = 'Page ${math.min(done + 1, total)} of $total');
    }

    PdfDocument? document;
    try {
      final Uint8List? bytes;
      final String suffix;
      switch (_mode) {
        case _Mode.lock:
          document = await PdfTools.openDocument(file.path, file.name);
          bytes = await PdfProtect.lock(document, _password.text, onProgress: progress);
          suffix = 'locked';
        case _Mode.unlock:
          setState(() => _progress = 'Unlocking…');
          bytes = await PdfProtect.unlock(file.path, file.name, _password.text);
          suffix = 'unlocked';
        case _Mode.watermark:
          document = await PdfTools.openDocument(file.path, file.name);
          bytes = await PdfProtect.watermark(
            document,
            WatermarkOptions(
              text: _markType == _MarkType.text ? _markText.text.trim() : '',
              imageBytes: _markType == _MarkType.image ? _markImage : null,
              size: _size,
              opacity: _opacity,
              layout: _layout,
            ),
            onProgress: progress,
          );
          suffix = 'watermarked';
      }
      if (!mounted) return;
      if (bytes == null) {
        _finish();
        showMessage(context, 'This PDF is not locked with a password. Nothing was saved.');
        return;
      }
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_$suffix', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      _finish();
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    } finally {
      await document?.dispose();
    }
  }

  void _finish() {
    setState(() {
      _busy = false;
      _progress = null;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    _finish();
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final problem = _problem;
    final label = switch (_mode) {
      _Mode.lock => 'Lock PDF',
      _Mode.unlock => 'Unlock PDF',
      _Mode.watermark => 'Add watermark',
    };
    return ToolPage(
      title: 'Protect',
      icon: Icons.lock_outline_rounded,
      palette: TilePalette.purple,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (file == null)
            SectionCard(
              child: EmptyState(
                icon: Icons.lock_outline_rounded,
                palette: TilePalette.purple,
                title: 'Choose a PDF',
                message: 'Lock it with a password, unlock it, or add a watermark. Everything happens on your phone.',
                action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
              ),
            )
          else ...[
            PickedPdfCard(
              file: file,
              onChange: _busy ? null : _chooseFile,
              detail: file.locked ? 'Locked · ${formatBytes(file.sizeBytes)}' : null,
            ),
            const SizedBox(height: 18),
            ChoiceGroup<_Mode>(
              label: 'What do you want to do?',
              options: _Mode.values,
              selected: _mode,
              labelOf: (m) => m.label,
              onChanged: (m) => setState(() {
                _mode = m;
                _password.clear();
                _confirm.clear();
              }),
              enabled: !_busy,
            ),
            const SizedBox(height: 18),
            ..._buildMode(file),
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
                ] else if (problem != null && !_busy && _mode != _Mode.watermark) ...[
                  Text(problem, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: label,
                  icon: Icons.lock_outline_rounded,
                  onPressed: problem == null ? _run : null,
                  busy: _busy,
                ),
              ],
            ),
    );
  }

  Widget _passwordField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      obscureText: _hidden,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _hidden = !_hidden),
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
    );
  }

  List<Widget> _buildMode(PickedPdf file) {
    switch (_mode) {
      case _Mode.lock:
        return [
          const FieldLabel('Password'),
          const SizedBox(height: 8),
          _passwordField(_password, 'Choose a password'),
          const SizedBox(height: 10),
          _passwordField(_confirm, 'Type it again'),
          const SizedBox(height: 14),
          Text(
            'Paperwise does not keep your password. If you forget it, nobody can open the file again. '
            'Pages are redrawn as pictures, so text in the locked copy cannot be selected or searched. '
            'Your original file is not changed.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ];
      case _Mode.unlock:
        return [
          const FieldLabel('Password of this PDF'),
          const SizedBox(height: 8),
          _passwordField(_password, 'Type the password'),
          const SizedBox(height: 14),
          Text(
            'You get an unlocked copy. Text stays selectable. Your original locked file is not changed.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ];
      case _Mode.watermark:
        return [
          ChoiceGroup<_MarkType>(
            label: 'Watermark',
            options: _MarkType.values,
            selected: _markType,
            labelOf: (t) => t.label,
            onChanged: (t) => setState(() => _markType = t),
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          if (_markType == _MarkType.text)
            TextField(
              controller: _markText,
              enabled: !_busy,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'For example CONFIDENTIAL'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    _markImageName ?? 'No picture chosen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
                SecondaryButton(
                  label: 'Choose picture',
                  icon: Icons.image_outlined,
                  onPressed: _busy ? null : _chooseMarkImage,
                ),
              ],
            ),
          const SizedBox(height: 14),
          ChoiceGroup<WatermarkSize>(
            label: 'Size',
            options: WatermarkSize.values,
            selected: _size,
            labelOf: (s) => s.label,
            onChanged: (s) => setState(() => _size = s),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<WatermarkOpacity>(
            label: 'Strength',
            options: WatermarkOpacity.values,
            selected: _opacity,
            labelOf: (o) => o.label,
            onChanged: (o) => setState(() => _opacity = o),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          ChoiceGroup<WatermarkLayout>(
            label: 'Layout',
            options: WatermarkLayout.values,
            selected: _layout,
            labelOf: (l) => l.label,
            onChanged: (l) => setState(() => _layout = l),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          Text(
            'The watermark is burned into the pages, so it cannot be removed later. Pages become pictures, so '
            'text in the new copy cannot be selected or searched. Your original file is not changed.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ];
    }
  }
}
