import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Looks applied to a scanned page.
enum ScanFilter {
  original('Original'),
  magic('Magic color'),
  bw('Black & white'),
  gray('Gray');

  const ScanFilter(this.label);
  final String label;
}

/// Crop corners as 8 numbers between 0 and 1: top-left x and y, top-right,
/// bottom-right, bottom-left.
const List<double> defaultScanCorners = [0.04, 0.04, 0.96, 0.04, 0.96, 0.96, 0.04, 0.96];

/// A photo made ready for scanning: a large copy for the final PDF and a small
/// one for quick previews. Both are already turned the right way up.
class ScanSource {
  const ScanSource({
    required this.full,
    required this.small,
    required this.smallWidth,
    required this.smallHeight,
  });

  final Uint8List full;
  final Uint8List small;
  final int smallWidth;
  final int smallHeight;
}

/// One page in the scanner with its crop and look.
class ScanPageData {
  ScanPageData(this.source) : corners = List<double>.of(defaultScanCorners);

  ScanSource source;
  List<double> corners;
  ScanFilter filter = ScanFilter.magic;

  /// Small processed picture shown in the page list.
  Uint8List? thumbnail;
}

// ---------------------------------------------------------------------------
// Public, background-isolate entry points
// ---------------------------------------------------------------------------

/// Reads a photo, fixes its rotation and makes the full and small copies.
Future<ScanSource> prepareScanSource(Uint8List bytes) => Isolate.run(() => _prepare(bytes));

/// Turns both copies of a photo a quarter turn.
Future<ScanSource> rotateScanSource(ScanSource source, {required bool clockwise}) {
  return Isolate.run(() {
    final full = _rotate(_decode(source.full), clockwise);
    final small = _rotate(_decode(source.small), clockwise);
    return ScanSource(
      full: _encodeJpg(full, 90),
      small: _encodeJpg(small, 85),
      smallWidth: small.width,
      smallHeight: small.height,
    );
  });
}

/// Crops [source] to [corners], straightens it and applies [filter].
/// Returns a JPEG.
Future<Uint8List> renderScan(
  Uint8List source,
  List<double> corners,
  ScanFilter filter, {
  int maxSide = 2400,
  int quality = 85,
}) {
  return Isolate.run(() => _render(source, corners, filter, maxSide, quality));
}

/// Encodes raw BGRA pixels (like a rendered PDF page) as a JPG or PNG file.
Future<Uint8List> encodeBgraPixels(
  Uint8List bgra,
  int width,
  int height, {
  required bool png,
  int quality = 90,
}) {
  return Isolate.run(() {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bgra.buffer,
      bytesOffset: bgra.offsetInBytes,
      order: img.ChannelOrder.bgra,
      numChannels: 4,
    );
    return png ? img.encodePng(image) : img.encodeJpg(image, quality: quality);
  });
}

// ---------------------------------------------------------------------------
// Pixel helpers (plain RGB bytes, 3 per pixel)
// ---------------------------------------------------------------------------

class _Rgb {
  _Rgb(this.width, this.height, this.data);

  final int width;
  final int height;
  final Uint8List data;
}

_Rgb _toRgb(img.Image image) {
  final width = image.width;
  final height = image.height;
  final raw = image.getBytes(order: img.ChannelOrder.rgb);
  if (raw.length == width * height * 3) {
    return _Rgb(width, height, Uint8List.fromList(raw));
  }
  // The picture came with an alpha channel; drop it.
  final out = Uint8List(width * height * 3);
  final channels = raw.length ~/ (width * height);
  for (var i = 0; i < width * height; i++) {
    out[i * 3] = raw[i * channels];
    out[i * 3 + 1] = raw[i * channels + 1];
    out[i * 3 + 2] = raw[i * channels + 2];
  }
  return _Rgb(width, height, out);
}

_Rgb _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('This is not a picture.');
  return _toRgb(decoded);
}

Uint8List _encodeJpg(_Rgb rgb, int quality) {
  final image = img.Image.fromBytes(
    width: rgb.width,
    height: rgb.height,
    bytes: rgb.data.buffer,
    numChannels: 3,
  );
  return img.encodeJpg(image, quality: quality);
}

img.Image _shrink(img.Image image, int maxSide) {
  final longest = math.max(image.width, image.height);
  if (longest <= maxSide) return image;
  return img.copyResize(
    image,
    width: image.width >= image.height ? maxSide : null,
    height: image.height > image.width ? maxSide : null,
    interpolation: img.Interpolation.linear,
  );
}

ScanSource _prepare(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('This is not a picture.');
  final upright = img.bakeOrientation(decoded);
  final full = _shrink(upright, 2480);
  final small = _shrink(full, 1000);
  return ScanSource(
    full: img.encodeJpg(full, quality: 90),
    small: img.encodeJpg(small, quality: 85),
    smallWidth: small.width,
    smallHeight: small.height,
  );
}

_Rgb _rotate(_Rgb src, bool clockwise) {
  final w = src.width;
  final h = src.height;
  final out = Uint8List(w * h * 3);
  // After a quarter turn the new picture is h wide and w tall.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final int nx;
      final int ny;
      if (clockwise) {
        nx = h - 1 - y;
        ny = x;
      } else {
        nx = y;
        ny = w - 1 - x;
      }
      final from = (y * w + x) * 3;
      final to = (ny * h + nx) * 3;
      out[to] = src.data[from];
      out[to + 1] = src.data[from + 1];
      out[to + 2] = src.data[from + 2];
    }
  }
  return _Rgb(h, w, out);
}

// ---------------------------------------------------------------------------
// Crop and straighten
// ---------------------------------------------------------------------------

Uint8List _render(Uint8List source, List<double> corners, ScanFilter filter, int maxSide, int quality) {
  final src = _decode(source);

  // Corner points in source pixels.
  final px = <double>[
    for (var i = 0; i < 8; i++) i.isEven ? corners[i] * src.width : corners[i] * src.height,
  ];
  double dist(int a, int b) => math.sqrt(math.pow(px[a * 2] - px[b * 2], 2) + math.pow(px[a * 2 + 1] - px[b * 2 + 1], 2));

  var outW = math.max(dist(0, 1), dist(3, 2));
  var outH = math.max(dist(0, 3), dist(1, 2));
  final longest = math.max(outW, outH);
  final scale = longest > maxSide ? maxSide / longest : 1.0;
  outW *= scale;
  outH *= scale;
  final width = math.max(1, outW.round());
  final height = math.max(1, outH.round());

  final warped = _warp(src, px, width, height);
  switch (filter) {
    case ScanFilter.original:
      break;
    case ScanFilter.gray:
      _toGray(warped);
    case ScanFilter.bw:
      _blackAndWhite(warped);
    case ScanFilter.magic:
      _magicColor(warped);
  }
  return _encodeJpg(warped, quality);
}

/// Maps the unit square onto the four points (top-left, top-right,
/// bottom-right, bottom-left) and samples the source for every output pixel.
_Rgb _warp(_Rgb src, List<double> p, int outW, int outH) {
  final x0 = p[0], y0 = p[1];
  final x1 = p[2], y1 = p[3];
  final x2 = p[4], y2 = p[5];
  final x3 = p[6], y3 = p[7];

  final dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
  final dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  final det = dx1 * dy2 - dx2 * dy1;

  var g = 0.0;
  var h = 0.0;
  if (det.abs() > 1e-9 && (dx3.abs() > 1e-9 || dy3.abs() > 1e-9)) {
    g = (dx3 * dy2 - dx2 * dy3) / det;
    h = (dx1 * dy3 - dx3 * dy1) / det;
  }
  final a = x1 - x0 + g * x1;
  final b = x3 - x0 + h * x3;
  final c = x0;
  final d = y1 - y0 + g * y1;
  final e = y3 - y0 + h * y3;
  final f = y0;

  final out = Uint8List(outW * outH * 3);
  final sw = src.width;
  final sh = src.height;
  final data = src.data;

  for (var y = 0; y < outH; y++) {
    final v = (y + 0.5) / outH;
    for (var x = 0; x < outW; x++) {
      final u = (x + 0.5) / outW;
      final denom = g * u + h * v + 1;
      var sx = (a * u + b * v + c) / denom - 0.5;
      var sy = (d * u + e * v + f) / denom - 0.5;
      if (sx < 0) sx = 0;
      if (sy < 0) sy = 0;
      if (sx > sw - 1) sx = (sw - 1).toDouble();
      if (sy > sh - 1) sy = (sh - 1).toDouble();

      final ix = sx.floor();
      final iy = sy.floor();
      final fx = sx - ix;
      final fy = sy - iy;
      final ix2 = ix + 1 < sw ? ix + 1 : ix;
      final iy2 = iy + 1 < sh ? iy + 1 : iy;

      final i00 = (iy * sw + ix) * 3;
      final i10 = (iy * sw + ix2) * 3;
      final i01 = (iy2 * sw + ix) * 3;
      final i11 = (iy2 * sw + ix2) * 3;
      final o = (y * outW + x) * 3;

      for (var ch = 0; ch < 3; ch++) {
        final top = data[i00 + ch] * (1 - fx) + data[i10 + ch] * fx;
        final bottom = data[i01 + ch] * (1 - fx) + data[i11 + ch] * fx;
        out[o + ch] = (top * (1 - fy) + bottom * fy).round();
      }
    }
  }
  return _Rgb(outW, outH, out);
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

Uint8List _luma(_Rgb rgb) {
  final count = rgb.width * rgb.height;
  final lum = Uint8List(count);
  final d = rgb.data;
  for (var i = 0; i < count; i++) {
    lum[i] = ((d[i * 3] * 299 + d[i * 3 + 1] * 587 + d[i * 3 + 2] * 114) ~/ 1000);
  }
  return lum;
}

/// Sums of brightness so the average of any box can be read in one step.
Int32List _integral(Uint8List lum, int w, int h) {
  final stride = w + 1;
  final table = Int32List(stride * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0;
    for (var x = 0; x < w; x++) {
      row += lum[y * w + x];
      table[(y + 1) * stride + x + 1] = table[y * stride + x + 1] + row;
    }
  }
  return table;
}

double _boxMean(Int32List table, int w, int h, int x, int y, int r) {
  final stride = w + 1;
  final left = math.max(0, x - r);
  final top = math.max(0, y - r);
  final right = math.min(w, x + r + 1);
  final bottom = math.min(h, y + r + 1);
  final sum = table[bottom * stride + right] - table[top * stride + right] - table[bottom * stride + left] + table[top * stride + left];
  return sum / ((right - left) * (bottom - top));
}

void _toGray(_Rgb rgb) {
  final lum = _luma(rgb);
  final d = rgb.data;
  for (var i = 0; i < lum.length; i++) {
    d[i * 3] = lum[i];
    d[i * 3 + 1] = lum[i];
    d[i * 3 + 2] = lum[i];
  }
}

/// Clean black text on white paper, even with uneven light.
void _blackAndWhite(_Rgb rgb) {
  final w = rgb.width;
  final h = rgb.height;
  final lum = _luma(rgb);
  final table = _integral(lum, w, h);
  final r = math.max(8, math.min(w, h) ~/ 24);
  final d = rgb.data;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final mean = _boxMean(table, w, h, x, y, r);
      final value = lum[i] < mean * 0.88 ? 0 : 255;
      d[i * 3] = value;
      d[i * 3 + 1] = value;
      d[i * 3 + 2] = value;
    }
  }
}

/// Whitens the paper, evens out shadows and keeps the colors.
void _magicColor(_Rgb rgb) {
  final w = rgb.width;
  final h = rgb.height;
  final lum = _luma(rgb);
  final table = _integral(lum, w, h);
  final r = math.max(16, math.min(w, h) ~/ 12);
  final d = rgb.data;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final paper = _boxMean(table, w, h, x, y, r) * 1.05 + 1;
      for (var ch = 0; ch < 3; ch++) {
        var ratio = d[i * 3 + ch] / paper;
        if (ratio > 1) ratio = 1;
        // A gentle curve darkens text and keeps the paper white.
        ratio = math.pow(ratio, 1.5).toDouble();
        d[i * 3 + ch] = (ratio * 255).round();
      }
    }
  }
}
