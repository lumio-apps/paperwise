import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A friendly error for Office files that cannot be opened.
class OfficeFileException implements Exception {
  const OfficeFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the files inside a ZIP archive, which is what .xlsx and .docx files are.
///
/// Only what Office files need: stored and deflated entries, no encryption, no ZIP64.
class ZipReader {
  ZipReader(this._bytes) {
    _readDirectory();
  }

  final Uint8List _bytes;
  final Map<String, _ZipEntry> _entries = {};

  /// True when the bytes start like a ZIP file.
  static bool looksLikeZip(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;

  /// True for the older Office format, which is also used for password-locked files.
  static bool looksLikeOldOffice(Uint8List bytes) =>
      bytes.length > 8 && bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0;

  /// Names are compared without case, as Office does.
  bool has(String name) => _entries.containsKey(name.toLowerCase());

  /// The unpacked bytes of [name], or null when the archive has no such file.
  Uint8List? read(String name) {
    final entry = _entries[name.toLowerCase()];
    if (entry == null) return null;
    if (entry.encrypted) {
      throw const OfficeFileException('This file is locked with a password.');
    }
    final offset = entry.localOffset;
    if (offset + 30 > _bytes.length || _u32(offset) != 0x04034b50) {
      throw const OfficeFileException('This file is damaged.');
    }
    final start = offset + 30 + _u16(offset + 26) + _u16(offset + 28);
    final end = start + entry.compressedSize;
    if (end > _bytes.length) throw const OfficeFileException('This file is damaged.');
    final data = Uint8List.sublistView(_bytes, start, end);
    switch (entry.method) {
      case 0:
        return Uint8List.fromList(data);
      case 8:
        try {
          return Uint8List.fromList(ZLibDecoder(raw: true).convert(data));
        } catch (_) {
          throw const OfficeFileException('This file is damaged.');
        }
      default:
        throw const OfficeFileException('This file uses a packing method Paperwise cannot read.');
    }
  }

  /// The text of [name] (UTF-8), or null when the archive has no such file.
  String? readText(String name) {
    final bytes = read(name);
    if (bytes == null) return null;
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    return text;
  }

  int _u16(int at) => _bytes[at] | (_bytes[at + 1] << 8);

  int _u32(int at) => _bytes[at] | (_bytes[at + 1] << 8) | (_bytes[at + 2] << 16) | (_bytes[at + 3] << 24);

  void _readDirectory() {
    final length = _bytes.length;
    if (length < 22) throw const OfficeFileException('This file is damaged.');

    // The "end of central directory" record sits at the end, before an optional comment.
    var end = -1;
    final lowest = length - 22 - 65535 < 0 ? 0 : length - 22 - 65535;
    for (var i = length - 22; i >= lowest; i--) {
      if (_bytes[i] == 0x50 && _bytes[i + 1] == 0x4B && _bytes[i + 2] == 0x05 && _bytes[i + 3] == 0x06) {
        end = i;
        break;
      }
    }
    if (end < 0) throw const OfficeFileException('This file is damaged.');

    final count = _u16(end + 10);
    final directory = _u32(end + 16);
    if (directory == 0xFFFFFFFF || count == 0xFFFF) {
      throw const OfficeFileException('This file is too large for Paperwise to open.');
    }

    var at = directory;
    for (var i = 0; i < count; i++) {
      if (at + 46 > length || _u32(at) != 0x02014b50) break;
      final flags = _u16(at + 8);
      final method = _u16(at + 10);
      final compressed = _u32(at + 20);
      final nameLength = _u16(at + 28);
      final extraLength = _u16(at + 30);
      final commentLength = _u16(at + 32);
      final localOffset = _u32(at + 42);
      if (at + 46 + nameLength > length) break;
      final name = utf8.decode(Uint8List.sublistView(_bytes, at + 46, at + 46 + nameLength), allowMalformed: true);
      _entries[name.replaceAll('\\', '/').toLowerCase()] = _ZipEntry(
        method: method,
        compressedSize: compressed,
        localOffset: localOffset,
        encrypted: flags & 1 == 1,
      );
      at += 46 + nameLength + extraLength + commentLength;
    }
  }
}

class _ZipEntry {
  const _ZipEntry({
    required this.method,
    required this.compressedSize,
    required this.localOffset,
    required this.encrypted,
  });

  final int method;
  final int compressedSize;
  final int localOffset;
  final bool encrypted;
}

/// Joins a relationship target to the folder of the part that points to it.
///
/// `resolvePart('xl', 'worksheets/sheet1.xml')` gives `xl/worksheets/sheet1.xml`,
/// and a target that starts with `/` is taken from the top of the archive.
String resolvePart(String folder, String target) {
  final parts = <String>[];
  final full = target.startsWith('/') ? target.substring(1) : (folder.isEmpty ? target : '$folder/$target');
  for (final piece in full.split('/')) {
    if (piece.isEmpty || piece == '.') continue;
    if (piece == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(piece);
    }
  }
  return parts.join('/');
}
