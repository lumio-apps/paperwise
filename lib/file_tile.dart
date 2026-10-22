import 'package:flutter/material.dart';

import 'file_actions.dart';
import 'file_store.dart';
import 'format.dart';
import 'library.dart';
import 'flat_ui.dart';
import 'theme.dart';
import 'widgets.dart';
import 'strings.dart';

enum _FileAction { open, favorite, share, save, rename, delete }

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
      messenger.showSnackBar(SnackBar(content: Text('Could not rename the file. Please try again.'.tr)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this PDF?'.tr),
        content: Text('"${file.name}" will be removed from Paperwise. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('Delete'.tr),
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
      case _FileAction.favorite:
        ReadingLibrary.instance.toggleFavorite(file.path);
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
    return ListenableBuilder(
      listenable: ReadingLibrary.instance,
      builder: (context, _) => _buildTile(context),
    );
  }

  Widget _buildTile(BuildContext context) {
    final info = ReadingLibrary.instance.infoFor(file.path);
    final favorite = info?.favorite ?? false;
    return PanelPress(
      radius: 20,
      onTap: () => openPdf(context, file.path),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
            children: [
              const PageThumb(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                        ),
                        if (favorite) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 18, color: TilePalette.yellow.color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatBytes(file.sizeBytes)} · ${formatDate(file.modified)}',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_FileAction>(
                tooltip: 'More options for ${file.name}',
                icon: Icon(Icons.more_vert_rounded, color: AppColors.muted),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _FileAction.open,
                    child: ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Read'.tr)),
                  ),
                  PopupMenuItem(
                    value: _FileAction.favorite,
                    child: ListTile(
                      leading: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded),
                      title: Text(favorite ? 'Remove from favorites'.tr : 'Add to favorites'.tr),
                    ),
                  ),
                  PopupMenuItem(
                    value: _FileAction.share,
                    child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share'.tr)),
                  ),
                  PopupMenuItem(
                    value: _FileAction.save,
                    child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Save to phone'.tr)),
                  ),
                  PopupMenuItem(
                    value: _FileAction.rename,
                    child: ListTile(leading: Icon(Icons.drive_file_rename_outline_rounded), title: Text('Rename'.tr)),
                  ),
                  PopupMenuItem(
                    value: _FileAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                      title: Text('Delete'.tr, style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ),
            ],
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
      title: Text('Rename PDF'.tr),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: 'New name'.tr, suffixText: '.pdf'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
        FilledButton(onPressed: _submit, child: Text('Rename'.tr)),
      ],
    );
  }
}
