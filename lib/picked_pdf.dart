import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'file_store.dart';
import 'pdf_tools.dart';

/// A PDF the user picked from their phone.
class PickedPdf {
  PickedPdf({required this.path, required this.name, required this.sizeBytes});

  final String path;
  final String name;
  final int sizeBytes;

  /// Filled in after the PDF is read; null while loading.
  int? pageCount;

  /// Set when the PDF can't be used (locked or damaged).
  String? error;

  /// True when the PDF is locked with a password.
  bool locked = false;

  bool get isReady => pageCount != null && error == null;
  bool get isLoading => pageCount == null && error == null;

  /// Reads the page count, or stores a friendly error.
  Future<void> load() async {
    try {
      pageCount = await PdfTools.pageCount(path, name);
    } on PdfLockedException catch (e) {
      locked = true;
      error = e.message;
    } on PdfToolException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'This file could not be read.';
    }
  }
}

/// Opens the system file picker for PDFs.
///
/// Returns an empty list if the user closes the picker.
Future<List<PickedPdf>> pickPdfFiles({required bool multiple}) async {
  final List<PlatformFile> picked;
  if (multiple) {
    picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
  } else {
    final one = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    picked = one == null ? const [] : [one];
  }

  final result = <PickedPdf>[];
  for (final file in picked) {
    final path = await _localPath(file);
    if (path == null) continue;
    result.add(PickedPdf(path: path, name: file.name, sizeBytes: await File(path).length()));
  }
  return result;
}

/// Makes sure we have a real file path, copying the file into the cache if needed.
Future<String?> _localPath(PlatformFile file) async {
  final path = file.path;
  if (path != null && await File(path).exists()) return path;
  try {
    final bytes = await file.readAsBytes();
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/picked');
    await dir.create(recursive: true);
    final copy = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${FileStore.cleanName(file.name)}.pdf');
    await copy.writeAsBytes(bytes, flush: true);
    return copy.path;
  } catch (_) {
    return null;
  }
}
