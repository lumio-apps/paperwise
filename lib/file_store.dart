import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'library.dart';
import 'save_folder.dart';

/// A PDF that Paperwise created and keeps on this phone.
class OutputFile {
  const OutputFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;
}

/// Keeps every PDF made by Paperwise in one folder inside the app's storage
/// and tells the screens when that list changes.
class FileStore extends ChangeNotifier {
  FileStore._();

  static final FileStore instance = FileStore._();

  Directory? _dir;
  List<OutputFile> _files = const [];

  /// Newest first.
  List<OutputFile> get files => _files;

  Future<Directory> folder() async {
    final existing = _dir;
    if (existing != null) return existing;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Paperwise');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Reads the folder again and updates [files].
  Future<void> load() async {
    final dir = await folder();
    final found = <OutputFile>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.pdf')) continue;
      final stat = await entity.stat();
      found.add(OutputFile(
        path: entity.path,
        name: entity.uri.pathSegments.last,
        sizeBytes: stat.size,
        modified: stat.modified,
      ));
    }
    found.sort((a, b) => b.modified.compareTo(a.modified));
    _files = found;
    notifyListeners();
  }

  /// Saves [bytes] as a new PDF named after [baseName].
  ///
  /// Call [load] after a batch of saves so the screens update once.
  Future<OutputFile> save(String baseName, Uint8List bytes) async {
    final dir = await folder();
    final file = await _uniqueFile(dir, cleanName(baseName));
    await file.writeAsBytes(bytes, flush: true);
    unawaited(SaveFolder.copyIfSet(file.path, file.uri.pathSegments.last, 'application/pdf'));
    return OutputFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      sizeBytes: bytes.length,
      modified: DateTime.now(),
    );
  }

  Future<void> delete(OutputFile file) async {
    final f = File(file.path);
    if (await f.exists()) await f.delete();
    ReadingLibrary.instance.remove(file.path);
    await load();
  }

  /// Gives [file] a new name, adding " (2)" and so on if that name is taken.
  Future<void> rename(OutputFile file, String newName) async {
    final dir = await folder();
    final base = cleanName(newName);
    if ('$base.pdf' == file.name) return;
    final target = await _uniqueFile(dir, base);
    await File(file.path).rename(target.path);
    ReadingLibrary.instance.move(file.path, target.path);
    await load();
  }

  /// Turns any text into a safe file name without the ".pdf" ending.
  static String cleanName(String input) {
    var name = input.trim();
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (name.length > 80) name = name.substring(0, 80).trim();
    return name.isEmpty ? 'Paperwise' : name;
  }

  /// A name like "Paperwise_20261012_2345" for files made right now.
  static String timestampName(String prefix) {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${prefix}_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  Future<File> _uniqueFile(Directory dir, String base) async {
    var candidate = File('${dir.path}/$base.pdf');
    var n = 2;
    while (await candidate.exists()) {
      candidate = File('${dir.path}/$base ($n).pdf');
      n++;
    }
    return candidate;
  }
}
