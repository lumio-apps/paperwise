import 'dart:typed_data';

/// The private details found inside a photo.
class ExifInfo {
  const ExifInfo({
    this.make,
    this.model,
    this.software,
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.hasMetadata = false,
  });

  final String? make;
  final String? model;
  final String? software;

  /// As written by the camera, like "2026:10:12 18:30:05".
  final String? dateTaken;
  final double? latitude;
  final double? longitude;

  /// True when the file has a camera data block (EXIF), even an empty one.
  final bool hasMetadata;

  bool get hasLocation => latitude != null && longitude != null;

  /// Phone or camera name, like "Google Pixel 7".
  String? get device {
    final parts = [make, model].whereType<String>().where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    // Many phones repeat the brand in the model name.
    if (parts.length == 2 && parts[1].toLowerCase().startsWith(parts[0].toLowerCase())) return parts[1];
    return parts.join(' ');
  }

  /// Date in a friendly form, like "12 Oct 2026".
  String? get dateText {
    final text = dateTaken;
    if (text == null) return null;
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})').firstMatch(text);
    if (match == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) return null;
    return '${int.parse(match.group(3)!)} ${months[month - 1]} ${match.group(1)}';
  }

  String? get locationText =>
      hasLocation ? '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}' : null;

  /// True when there is something private worth removing.
  bool get hasPrivateDetails => hasLocation || device != null || dateTaken != null || software != null;
}

/// Reads camera details from a JPEG file. Other file types, and damaged
/// files, give an empty result.
ExifInfo readExif(Uint8List bytes) {
  final reader = _ExifReader(bytes);
  try {
    reader.run();
  } catch (_) {
    // Keep whatever was read before the problem.
  }
  return reader.result();
}

class _ExifReader {
  _ExifReader(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;

  late Endian _endian;
  int _tiff = 0;

  bool found = false;
  String? make;
  String? model;
  String? software;
  String? dateTaken;
  String? _latRef;
  String? _lonRef;
  double? _lat;
  double? _lon;

  ExifInfo result() {
    double? lat = _lat;
    double? lon = _lon;
    if (lat != null && _latRef == 'S') lat = -lat;
    if (lon != null && _lonRef == 'W') lon = -lon;
    return ExifInfo(
      make: make,
      model: model,
      software: software,
      dateTaken: dateTaken,
      latitude: lat,
      longitude: lon,
      hasMetadata: found,
    );
  }

  void run() {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return;
    var pos = 2;
    while (pos + 4 <= bytes.length) {
      if (bytes[pos] != 0xFF) return;
      final marker = bytes[pos + 1];
      if (marker == 0xDA || marker == 0xD9) return; // start of picture data
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        pos += 2;
        continue;
      }
      final length = data.getUint16(pos + 2, Endian.big);
      if (marker == 0xE1 && _isExifHeader(pos + 4)) {
        _readTiff(pos + 10);
        return;
      }
      pos += 2 + length;
    }
  }

  bool _isExifHeader(int at) {
    if (at + 6 > bytes.length) return false;
    const header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
    for (var i = 0; i < 6; i++) {
      if (bytes[at + i] != header[i]) return false;
    }
    return true;
  }

  void _readTiff(int start) {
    _tiff = start;
    if (start + 8 > bytes.length) return;
    final order = String.fromCharCodes(bytes.sublist(start, start + 2));
    if (order == 'II') {
      _endian = Endian.little;
    } else if (order == 'MM') {
      _endian = Endian.big;
    } else {
      return;
    }
    if (data.getUint16(start + 2, _endian) != 42) return;
    found = true;
    _readIfd(data.getUint32(start + 4, _endian), _Ifd.main);
  }

  void _readIfd(int offset, _Ifd kind) {
    final base = _tiff + offset;
    if (base + 2 > bytes.length) return;
    final count = data.getUint16(base, _endian);
    for (var i = 0; i < count; i++) {
      final entry = base + 2 + i * 12;
      if (entry + 12 > bytes.length) return;
      final tag = data.getUint16(entry, _endian);
      final type = data.getUint16(entry + 2, _endian);
      final n = data.getUint32(entry + 4, _endian);

      switch (kind) {
        case _Ifd.main:
          switch (tag) {
            case 0x010F:
              make = _ascii(entry, type, n);
            case 0x0110:
              model = _ascii(entry, type, n);
            case 0x0131:
              software = _ascii(entry, type, n);
            case 0x0132:
              dateTaken ??= _ascii(entry, type, n);
            case 0x8769:
              _readIfd(data.getUint32(entry + 8, _endian), _Ifd.exif);
            case 0x8825:
              _readIfd(data.getUint32(entry + 8, _endian), _Ifd.gps);
          }
        case _Ifd.exif:
          if (tag == 0x9003) dateTaken = _ascii(entry, type, n);
        case _Ifd.gps:
          switch (tag) {
            case 0x0001:
              _latRef = _ascii(entry, type, n);
            case 0x0002:
              _lat = _degrees(entry, type, n);
            case 0x0003:
              _lonRef = _ascii(entry, type, n);
            case 0x0004:
              _lon = _degrees(entry, type, n);
          }
      }
    }
  }

  /// Where the value of an entry starts: inside the entry if it is 4 bytes or
  /// less, otherwise at the offset stored in the entry.
  int _valueAt(int entry, int size) {
    return size <= 4 ? entry + 8 : _tiff + data.getUint32(entry + 8, _endian);
  }

  String? _ascii(int entry, int type, int n) {
    if (type != 2 || n == 0) return null;
    final at = _valueAt(entry, n);
    if (at < 0 || at + n > bytes.length) return null;
    var end = at + n;
    while (end > at && bytes[end - 1] == 0) {
      end--;
    }
    final text = String.fromCharCodes(bytes.sublist(at, end)).trim();
    return text.isEmpty ? null : text;
  }

  /// Degrees, minutes and seconds stored as three fractions.
  double? _degrees(int entry, int type, int n) {
    if (type != 5 || n < 3) return null;
    final at = _valueAt(entry, n * 8);
    if (at < 0 || at + 24 > bytes.length) return null;
    double part(int i) {
      final top = data.getUint32(at + i * 8, _endian);
      final bottom = data.getUint32(at + i * 8 + 4, _endian);
      return bottom == 0 ? 0 : top / bottom;
    }

    return part(0) + part(1) / 60 + part(2) / 3600;
  }
}

enum _Ifd { main, exif, gps }
