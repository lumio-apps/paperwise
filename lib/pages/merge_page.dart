import 'package:flutter/material.dart';

import '../file_store.dart';
import '../format.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

/// Joins several PDFs into one, in the order the user chooses.
class MergePage extends StatefulWidget {
  const MergePage({super.key});

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  final List<PickedPdf> _files = [];
  final _nameController = TextEditingController(text: FileStore.timestampName('Merged'));
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<PickedPdf> get _ready => _files.where((f) => f.isReady).toList();

  Future<void> _addFiles() async {
    final List<PickedPdf> added;
    try {
      added = await pickPdfFiles(multiple: true);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the file picker.');
      return;
    }
    if (!mounted || added.isEmpty) return;
    setState(() => _files.addAll(added));
    for (final file in added) {
      await file.load();
      if (!mounted) return;
      setState(() {});
    }
  }

  void _remove(PickedPdf file) => setState(() => _files.remove(file));

  Future<void> _merge() async {
    final ready = _ready;
    if (ready.length < 2 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final bytes = await PdfTools.merge(
        [for (final f in ready) f.path],
        [for (final f in ready) f.name],
      );
      final name = _nameController.text.trim().isEmpty ? FileStore.timestampName('Merged') : _nameController.text;
      final saved = await FileStore.instance.save(name, bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Could not merge these PDFs. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    final totalPages = ready.fold<int>(0, (sum, f) => sum + (f.pageCount ?? 0));
    final totalBytes = ready.fold<int>(0, (sum, f) => sum + f.sizeBytes);

    return ToolPage(
      title: 'Merge PDF',
      icon: Icons.merge_type_rounded,
      palette: TilePalette.blue,
      body: _files.isEmpty ? _buildEmpty() : _buildList(),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready.isNotEmpty) ...[
            Row(
              children: [
                const Text('Total', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                const Spacer(),
                Text(
                  '${pageCountLabel(totalPages)} · ${formatBytes(totalBytes)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: ready.length < 2 ? 'Add at least 2 PDFs' : 'Merge ${fileCountLabel(ready.length)}',
            onPressed: ready.length < 2 ? null : _merge,
            busy: _busy,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        SectionCard(
          child: EmptyState(
            icon: Icons.merge_type_rounded,
            palette: TilePalette.blue,
            title: 'Choose PDFs to merge',
            message: 'Pick two or more PDFs. You can drag them into the order you want.',
            action: PrimaryButton(label: 'Choose PDFs', icon: Icons.add_rounded, onPressed: _addFiles),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      buildDefaultDragHandles: false,
      header: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Drag files to set the order. The top file comes first.',
          style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
        ),
      ),
      itemCount: _files.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _files.removeAt(oldIndex);
          _files.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final file = _files[index];
        return Padding(
          key: ObjectKey(file),
          padding: const EdgeInsets.only(bottom: 10),
          child: _MergeFileCard(file: file, index: index, onRemove: () => _remove(file)),
        );
      },
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _addFiles,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add more files'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.accent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Output file name'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Name of the new PDF', suffixText: '.pdf'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MergeFileCard extends StatelessWidget {
  const _MergeFileCard({required this.file, required this.index, required this.onRemove});

  final PickedPdf file;
  final int index;
  final VoidCallback onRemove;

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

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.drag_indicator_rounded, color: Color(0xFF8E89B0)),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.primary : TilePalette.blue.tint,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: index == 0 ? Colors.white : TilePalette.blue.color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
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
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove ${file.name}',
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
