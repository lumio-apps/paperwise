import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One picture found inside a PDF, ready to be saved as a file.
class FoundImage {
  const FoundImage({required this.bytes, required this.extension, required this.width, required this.height});

  final Uint8List bytes;

  /// "jpg" or "png".
  final String extension;
  final int width;
  final int height;
}

/// The pictures found in a PDF, and how many were left out.
class ImageScan {
  const ImageScan(this.images, this.skipped);

  final List<FoundImage> images;

  /// Pictures in a format Paperwise cannot turn into a file yet.
  final int skipped;
}

/// Thrown when the PDF is locked, so its pictures cannot be read.
class LockedPdfException implements Exception {
  const LockedPdfException();
}

/// Finds the pictures stored inside a PDF, without drawing any page.
///
/// It reads the raw file. Photos saved as JPEG come out exactly as they are in
/// the PDF. Plain RGB and gray pictures are turned into PNG. Other formats
/// (for example scans stored as black and white fax data) are counted as skipped.
class PdfImages {
  PdfImages._();

  /// Smaller pictures than this (in pixels, each side) are icons and lines, not photos.
  static const int _minSide = 24;

  static Future<ImageScan> scan(Uint8List data) => Isolate.run(() => _scan(data));

  static ImageScan _scan(Uint8List data) {
    final text = latin1.decode(data);
    if (RegExp(r'/Encrypt[\s/<\[]').hasMatch(text)) throw const LockedPdfException();

    // Pictures that only act as a see-through mask for another picture.
    final masks = <int>{
      for (final m in RegExp(r'/(?:SMask|Mask)\s+(\d+)\s+\d+\s+R').allMatches(text)) int.parse(m.group(1)!),
    };

    final found = <FoundImage>[];
    var skipped = 0;
    final seen = <int>{};

    for (final m in RegExp(r'>>\s*stream(?:\r\n|\n|\r)').allMatches(text)) {
      final objStart = text.lastIndexOf(' obj', m.start);
      if (objStart < 0) continue;
      final dict = text.substring(objStart + 4, m.start + 2);
      if (!RegExp(r'/Subtype\s*/Image').hasMatch(dict)) continue;
      if (RegExp(r'/ImageMask\s+true').hasMatch(dict)) continue;

      final before = text.substring(math.max(0, objStart - 24), objStart);
      final number = RegExp(r'(\d+)\s+\d+\s*$').firstMatch(before);
      if (number != null && masks.contains(int.parse(number.group(1)!))) continue;
      if (number != null && !seen.add(int.parse(number.group(1)!))) continue;

      final width = _int(dict, 'Width');
      final height = _int(dict, 'Height');
      if (width == null || height == null || width < _minSide || height < _minSide) continue;

      var end = text.indexOf('endstream', m.end);
      if (end < 0) continue;
      if (end > m.end && text.codeUnitAt(end - 1) == 10) end--;
      if (end > m.end && text.codeUnitAt(end - 1) == 13) end--;
      final stream = Uint8List.sublistView(data, m.end, end);

      try {
        final image = _extract(dict, stream, width, height);
        if (image == null) {
          skipped++;
        } else {
          found.add(image);
        }
      } catch (_) {
        skipped++;
      }
    }
    return ImageScan(found, skipped);
  }

  static int? _int(String dict, String key) {
    final m = RegExp('/$key\\s+(\\d+)').firstMatch(dict);
    return m == null ? null : int.parse(m.group(1)!);
  }

  static List<String> _filters(String dict) {
    final m = RegExp(r'/Filter\s*(\[[^\]]*\]|/\w+)').firstMatch(dict);
    if (m == null) return const [];
    return RegExp(r'/(\w+)').allMatches(m.group(1)!).map((x) => x.group(1)!).toList();
  }

  static FoundImage? _extract(String dict, Uint8List stream, int width, int height) {
    final filters = _filters(dict);
    final cmyk = dict.contains('/DeviceCMYK');

    // A JPEG photo: the stream already is a JPEG file.
    if (filters.isNotEmpty && filters.last == 'DCTDecode' && filters.length <= 2) {
      if (cmyk) return null;
      var bytes = Uint8List.fromList(stream);
      if (filters.length == 2) {
        if (filters.first != 'FlateDecode') return null;
        bytes = Uint8List.fromList(ZLibDecoder().convert(stream));
      }
      return FoundImage(bytes: bytes, extension: 'jpg', width: width, height: height);
    }

    // Plain pixels, packed with Flate.
    if (filters.length == 1 && filters.first == 'FlateDecode') {
      if (cmyk) return null;
      final bpc = _int(dict, 'BitsPerComponent') ?? 8;
      if (bpc != 8) return null;
      var raw = Uint8List.fromList(ZLibDecoder().convert(stream));

      final predictor = _int(dict, 'Predictor') ?? 1;
      if (predictor >= 10) {
        final colors = _int(dict, 'Colors') ?? 1;
        raw = _unpredict(raw, width * colors, colors, height);
      } else if (predictor != 1) {
        return null;
      }

      final channels = raw.length ~/ (width * height);
      if ((channels != 1 && channels != 3) || raw.length < width * height * channels) return null;
      final picture = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: raw.buffer,
        numChannels: channels,
      );
      return FoundImage(bytes: Uint8List.fromList(img.encodePng(picture)), extension: 'png', width: width, height: height);
    }
    return null;
  }

  /// Undoes the PNG-style row filters that PDF writers use to pack pixels.
  static Uint8List _unpredict(Uint8List raw, int rowBytes, int bpp, int rows) {
    final out = Uint8List(rowBytes * rows);
    final stride = rowBytes + 1;
    for (var r = 0; r < rows; r++) {
      final src = r * stride;
      if (src + stride > raw.length) break;
      final filter = raw[src];
      final dst = r * rowBytes;
      for (var i = 0; i < rowBytes; i++) {
        final x = raw[src + 1 + i];
        final a = i >= bpp ? out[dst + i - bpp] : 0;
        final b = r > 0 ? out[dst - rowBytes + i] : 0;
        final c = (r > 0 && i >= bpp) ? out[dst - rowBytes + i - bpp] : 0;
        final int value;
        switch (filter) {
          case 1:
            value = x + a;
          case 2:
            value = x + b;
          case 3:
            value = x + ((a + b) >> 1);
          case 4:
            value = x + _paeth(a, b, c);
          default:
            value = x;
        }
        out[dst + i] = value & 0xFF;
      }
    }
    return out;
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }
}
