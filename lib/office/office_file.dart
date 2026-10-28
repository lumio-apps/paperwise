import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../file_store.dart';
import '../theme.dart';
import '../widgets.dart';

/// File kinds the Office viewers open, by file ending.
const sheetEndings = ['.xlsx', '.csv', '.tsv'];
const documentEndings = ['.docx'];

bool isSheetFile(String path) => sheetEndings.any(path.toLowerCase().endsWith);
bool isDocumentFile(String path) => documentEndings.any(path.toLowerCase().endsWith);

/// The MIME type Android uses for [path].
String officeMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (lower.endsWith('.csv')) return 'text/csv';
  if (lower.endsWith('.tsv')) return 'text/tab-separated-values';
  return 'application/octet-stream';
}

/// The file name of [path], without the folder.
String officeFileName(String path) => path.split(RegExp(r'[\\/]')).last;

/// Opens the system file picker for one file with one of [extensions] (no dot).
///
/// Returns a local path, or null when nothing was picked.
Future<String?> pickOfficeFile(BuildContext context, List<String> extensions) async {
  try {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: extensions);
    if (file == null) return null;
    final path = file.path;
    if (path != null && await File(path).exists()) return path;

    // Some file providers only give bytes: keep a copy in the cache.
    final bytes = await file.readAsBytes();
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/picked');
    await dir.create(recursive: true);
    final dot = file.name.lastIndexOf('.');
    final ending = dot < 0 ? '' : file.name.substring(dot).toLowerCase();
    final base = FileStore.cleanName(dot < 0 ? file.name : file.name.substring(0, dot));
    final copy = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$base$ending');
    await copy.writeAsBytes(bytes, flush: true);
    return copy.path;
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not open the file picker.');
    return null;
  }
}

/// Opens the share sheet for an Office file.
Future<void> shareOfficeFile(String path) async {
  await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: officeMimeType(path))]));
}

/// Hands the file to another app on the phone, for example to edit it.
Future<void> openOfficeFileElsewhere(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await OpenFilex.open(path, type: officeMimeType(path));
  if (result.type != ResultType.done) {
    messenger.showSnackBar(const SnackBar(content: Text('No other app for this file was found on this phone.')));
  }
}

/// The top bar of the Office viewers: back, file name and a menu.
class OfficeViewerHeader extends StatelessWidget {
  const OfficeViewerHeader({super.key, required this.path, this.actions = const []});

  final String path;

  /// Extra buttons shown before the menu.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              officeFileName(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: AppColors.ink),
            ),
          ),
          ...actions,
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(Icons.more_vert_rounded, color: AppColors.muted),
            onSelected: (action) {
              if (action == 'share') {
                shareOfficeFile(path);
              } else {
                openOfficeFileElsewhere(context, path);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'share',
                child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share')),
              ),
              PopupMenuItem(
                value: 'other',
                child: ListTile(leading: Icon(Icons.open_in_new_rounded), title: Text('Open in another app')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
