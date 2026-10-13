import 'package:flutter/material.dart';

import 'file_actions.dart';
import 'file_store.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

enum _FileAction { open, share, save, rename, delete }

/// One saved PDF in a list, with a menu for Open, Share, Save, Rename and Delete.
class FileTile extends StatelessWidget {
  const FileTile({super.key, required this.file});

  final OutputFile file;

  Future<void> _rename(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(currentName: file.name),
    );
    if (newName == null) return;
    try {
      await FileStore.instance.rename(file, newName);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not rename the file. Please try again.')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this PDF?'),
        content: Text('"${file.name}" will be removed from Paperwise. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await FileStore.instance.delete(file);
  }

  void _onAction(BuildContext context, _FileAction action) {
    switch (action) {
      case _FileAction.open:
        openPdf(context, file.path);
      case _FileAction.share:
        sharePdfs([file.path]);
      case _FileAction.save:
        savePdfToDevice(context, file.path, file.name);
      case _FileAction.rename:
        _rename(context);
      case _FileAction.delete:
        _confirmDelete(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openPdf(context, file.path),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatBytes(file.sizeBytes)} · ${formatDate(file.modified)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_FileAction>(
                tooltip: 'More options for ${file.name}',
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _FileAction.open,
                    child: ListTile(leading: Icon(Icons.open_in_new_rounded), title: Text('Open')),
                  ),
                  PopupMenuItem(
                    value: _FileAction.share,
                    child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share')),
                  ),
                  PopupMenuItem(
                    value: _FileAction.save,
                    child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Save to phone')),
                  ),
                  PopupMenuItem(
                    value: _FileAction.rename,
                    child: ListTile(leading: Icon(Icons.drive_file_rename_outline_rounded), title: Text('Rename')),
                  ),
                  PopupMenuItem(
                    value: _FileAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      title: Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a new file name and returns it, or null when cancelled.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentName});

  final String currentName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final name = widget.currentName;
    final base = name.toLowerCase().endsWith('.pdf') ? name.substring(0, name.length - 4) : name;
    _controller = TextEditingController(text: base)
      ..selection = TextSelection(baseOffset: 0, extentOffset: base.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename PDF'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'New name', suffixText: '.pdf'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Rename')),
      ],
    );
  }
}
