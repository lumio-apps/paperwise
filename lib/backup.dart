import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'file_store.dart';
import 'library.dart';

/// Thrown when a picked file is not a Paperwise backup.
class NotABackupException implements Exception {
  const NotABackupException();
}

/// What a restore brought back.
class RestoreResult {
  const RestoreResult({required this.restored, required this.skipped});

  final int restored;
  final int skipped;
}

/// Packs every PDF made with Paperwise, the reading list and the saved
/// signature into one ".pwbackup" file, and unpacks it again.
///
/// The file is a simple list of entries, written and read piece by piece so
/// large PDFs never have to fit in memory at once.
class PaperwiseBackup {
  PaperwiseBackup._();

  static const _magic = [0x50, 0x57, 0x42, 0x4B, 0x31]; // "PWBK1"
  static const _typePdf = 1;
  static const _typeLibrary = 2;
  static const _typeSignature = 3;
  static const _maxNameBytes = 512;
  static const _maxJsonBytes = 8 * 1024 * 1024;

  /// Writes a backup into the cache folder. Returns null when there is nothing to save.
  static Future<File?> create() async {
    await FileStore.instance.load();
    final folder = await FileStore.instance.folder();
    final pdfs = FileStore.instance.files;
    if (pdfs.isEmpty) return null;

    final temp = await getTemporaryDirectory();
    final out = File('${temp.path}/${FileStore.timestampName('Paperwise_backup')}.pwbackup');
    final sink = out.openWrite();
    try {
      sink.add(_magic);
      for (final pdf in pdfs) {
        final file = File(pdf.path);
        if (!await file.exists()) continue;
        _writeHeader(sink, _typePdf, pdf.name, await file.length());
        await sink.addStream(file.openRead());
      }
      final library = utf8.encode(jsonEncode(ReadingLibrary.instance.exportByName(folder.path)));
      _writeHeader(sink, _typeLibrary, 'library', library.length);
      sink.add(library);

      final docs = await getApplicationDocumentsDirectory();
      final signature = File('${docs.path}/paperwise_signature.json');
      if (await signature.exists()) {
        _writeHeader(sink, _typeSignature, 'signature', await signature.length());
        await sink.addStream(signature.openRead());
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return out;
  }

  /// Puts the contents of the backup at [path] back on this phone.
  ///
  /// Files that are already here with the same size are left alone.
  static Future<RestoreResult> restore(String path) async {
    final source = await File(path).open();
    try {
      final total = await source.length();
      final magic = total >= _magic.length ? await source.read(_magic.length) : Uint8List(0);
      if (magic.length != _magic.length) throw const NotABackupException();
      for (var i = 0; i < _magic.length; i++) {
        if (magic[i] != _magic[i]) throw const NotABackupException();
      }

      final folder = await FileStore.instance.folder();
      final docs = await getApplicationDocumentsDirectory();
      final renamed = <String>[];
      List<dynamic>? libraryJson;
      var restored = 0;
      var skipped = 0;

      while (await source.position() < total) {
        final head = await source.read(1 + 4);
        if (head.length < 5) throw const NotABackupException();
        final type = head[0];
        final nameLength = ByteData.sublistView(head, 1, 5).getUint32(0);
        if (nameLength > _maxNameBytes) throw const NotABackupException();
        final nameBytes = await source.read(nameLength);
        final sizeBytes = await source.read(8);
        if (nameBytes.length != nameLength || sizeBytes.length != 8) throw const NotABackupException();
        final size = ByteData.sublistView(sizeBytes).getUint64(0);
        final start = await source.position();
        if (size > total - start) throw const NotABackupException();
        final name = utf8.decode(nameBytes, allowMalformed: true);

        if (type == _typePdf) {
          final safe = _safePdfName(name);
          final target = File('${folder.path}/$safe');
          if (safe.isNotEmpty && await target.exists() && await target.length() == size) {
            skipped++;
            renamed.add(safe);
          } else if (safe.isNotEmpty) {
            final unique = await _uniqueFile(folder, safe);
            await _copyOut(source, size, unique);
            restored++;
            renamed.add(unique.uri.pathSegments.last);
          }
        } else if (type == _typeLibrary && size <= _maxJsonBytes) {
          final data = await source.read(size);
          try {
            final decoded = jsonDecode(utf8.decode(data));
            if (decoded is List) libraryJson = decoded;
          } catch (_) {
            // A damaged reading list is not worth failing the restore.
          }
        } else if (type == _typeSignature && size <= _maxJsonBytes) {
          final data = await source.read(size);
          final signature = File('${docs.path}/paperwise_signature.json');
          if (!await signature.exists()) await signature.writeAsBytes(data, flush: true);
        }
        await source.setPosition(start + size);
      }

      await FileStore.instance.load();
      if (libraryJson != null) ReadingLibrary.instance.importByName(libraryJson, folder.path, renamed);
      return RestoreResult(restored: restored, skipped: skipped);
    } finally {
      await source.close();
    }
  }

  static void _writeHeader(IOSink sink, int type, String name, int size) {
    final nameBytes = utf8.encode(name);
    final head = ByteData(1 + 4)..setUint8(0, type);
    head.setUint32(1, nameBytes.length);
    final sizeData = ByteData(8)..setUint64(0, size);
    sink
      ..add(head.buffer.asUint8List())
      ..add(nameBytes)
      ..add(sizeData.buffer.asUint8List());
  }

  /// Keeps only the file name, so a backup can never write outside the folder.
  static String _safePdfName(String name) {
    final last = name.split(RegExp(r'[\\/]')).last.trim();
    if (!last.toLowerCase().endsWith('.pdf') || last.length <= 4) return '';
    return last.replaceAll(RegExp(r'[:*?"<>|\x00-\x1F]'), '_');
  }

  static Future<File> _uniqueFile(Directory dir, String name) async {
    final base = name.substring(0, name.length - 4);
    var candidate = File('${dir.path}/$name');
    var n = 2;
    while (await candidate.exists()) {
      candidate = File('${dir.path}/$base ($n).pdf');
      n++;
    }
    return candidate;
  }

  static Future<void> _copyOut(RandomAccessFile source, int size, File target) async {
    final sink = await target.open(mode: FileMode.write);
    try {
      var left = size;
      while (left > 0) {
        final chunk = await source.read(left < 1 << 20 ? left : 1 << 20);
        if (chunk.isEmpty) throw const NotABackupException();
        await sink.writeFrom(chunk);
        left -= chunk.length;
      }
    } finally {
      await sink.close();
    }
  }
}
