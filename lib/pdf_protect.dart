import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import 'image_tools.dart';
import 'pdf_tools.dart';
import 'pdf_writer.dart';

enum WatermarkSize {
  small('Small', 0.05, 0.25),
  medium('Medium', 0.08, 0.45),
  large('Large', 0.13, 0.7);

  const WatermarkSize(this.label, this.textFactor, this.imageFactor);
  final String label;

  /// Text height compared with the short side of the page.
  final double textFactor;

  /// Picture width compared with the short side of the page.
  final double imageFactor;
}

enum WatermarkOpacity {
  light('Light', 0.18),
  medium('Medium', 0.32),
  strong('Strong', 0.5);

  const WatermarkOpacity(this.label, this.value);
  final String label;
  final double value;
}

enum WatermarkLayout {
  center('Centered'),
  tiled('Repeated');

  const WatermarkLayout(this.label);
  final String label;
}

/// What to stamp on every page: text, or a picture when [imageBytes] is set.
class WatermarkOptions {
  const WatermarkOptions({
    this.text = '',
    this.imageBytes,
    this.size = WatermarkSize.medium,
    this.opacity = WatermarkOpacity.medium,
    this.layout = WatermarkLayout.center,
  });

  final String text;
  final Uint8List? imageBytes;
  final WatermarkSize size;
  final WatermarkOpacity opacity;
  final WatermarkLayout layout;
}

/// Lock, unlock and watermark PDFs on the phone.
///
/// Locking and watermarking redraw each page as a sharp picture, so text in
/// the new file can no longer be selected or searched. Unlocking keeps
/// everything as it was.
class PdfProtect {
  PdfProtect._();

  static const int _dpi = 200;
  static const int _quality = 88;
  static const double _maxPixels = 16e6;

  /// Makes a copy of [document] that needs [password] to open.
  static Future<Uint8List> lock(
    PdfDocument document,
    String password, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (PdfWriter.passwordBytes(password) == null) {
      throw const PdfToolException('Use 1 to 32 letters, numbers or symbols from the keyboard.');
    }
    final pages = await _rasterize(document, onProgress: onProgress);
    final bytes = await Isolate.run(() => PdfWriter.build(pages, password: password));
    await _verifyLocked(bytes, password, pages.length);
    return bytes;
  }

  /// Makes a copy of [document] with the watermark on every page.
  static Future<Uint8List> watermark(
    PdfDocument document,
    WatermarkOptions options, {
    void Function(int done, int total)? onProgress,
  }) async {
    ui.Image? mark;
    final imageBytes = options.imageBytes;
    if (imageBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(imageBytes, targetWidth: 1024);
        mark = (await codec.getNextFrame()).image;
        codec.dispose();
      } catch (_) {
        throw const PdfToolException('That picture could not be opened.');
      }
    }
    try {
      final pages = await _rasterize(document, options: options, mark: mark, onProgress: onProgress);
      return await Isolate.run(() => PdfWriter.build(pages));
    } finally {
      mark?.dispose();
    }
  }

  /// Makes an unlocked copy of a PDF. Returns null when the file was not
  /// locked in the first place.
  static Future<Uint8List?> unlock(String path, String name, String password) async {
    var asked = false;
    final document = await PdfTools.openWithPassword(path, name, password, onPasswordNeeded: () => asked = true);
    try {
      if (!asked) return null;
      return await PdfTools.arrange(document, [for (var i = 0; i < document.pages.length; i++) PageEdit(i)]);
    } finally {
      await document.dispose();
    }
  }

  static Future<List<WriterPage>> _rasterize(
    PdfDocument document, {
    WatermarkOptions? options,
    ui.Image? mark,
    void Function(int done, int total)? onProgress,
  }) async {
    final count = document.pages.length;
    if (count == 0) throw const PdfToolException('This PDF has no pages.');
    final result = <WriterPage>[];
    for (var i = 0; i < count; i++) {
      onProgress?.call(i, count);
      final page = document.pages[i];
      final scale = _dpi / 72.0;
      var width = page.width * scale;
      var height = page.height * scale;
      if (width * height > _maxPixels) {
        final shrink = math.sqrt(_maxPixels / (width * height));
        width *= shrink;
        height *= shrink;
      }
      final rendered = await page.render(
        width: math.max(1, width.round()),
        height: math.max(1, height.round()),
        fullWidth: width,
        fullHeight: height,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) throw const PdfToolException('A page could not be drawn.');
      try {
        final Uint8List jpg;
        if (options == null) {
          jpg = await encodeBgraPixels(rendered.pixels, rendered.width, rendered.height, png: false, quality: _quality);
        } else {
          jpg = await _stamp(rendered.pixels, rendered.width, rendered.height, options, mark);
        }
        result.add(
          WriterPage(
            jpg: jpg,
            pixelWidth: rendered.width,
            pixelHeight: rendered.height,
            width: page.width,
            height: page.height,
          ),
        );
      } finally {
        rendered.dispose();
      }
    }
    onProgress?.call(count, count);
    return result;
  }

  /// Opens the new file with the password, and checks it is not open without one.
  static Future<void> _verifyLocked(Uint8List bytes, String password, int pageCount) async {
    const failed = PdfToolException('Could not lock this PDF safely. Nothing was saved.');
    var attempts = 0;
    try {
      final check = await PdfDocument.openData(bytes, passwordProvider: () => attempts++ == 0 ? password : null);
      final ok = check.pages.length == pageCount;
      await check.dispose();
      if (!ok) throw failed;
    } on PdfToolException {
      rethrow;
    } catch (_) {
      throw failed;
    }
    try {
      final open = await PdfDocument.openData(bytes, passwordProvider: () => null);
      await open.dispose();
      throw failed;
    } on PdfPasswordException {
      // Good: the file asks for a password.
    } on PdfToolException {
      rethrow;
    } catch (_) {
      throw failed;
    }
  }

  static Future<ui.Image> _decodeBgra(Uint8List bgra, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(bgra, width, height, ui.PixelFormat.bgra8888, completer.complete);
    return completer.future;
  }

  static Future<Uint8List> _stamp(
    Uint8List bgra,
    int width,
    int height,
    WatermarkOptions options,
    ui.Image? mark,
  ) async {
    final base = await _decodeBgra(bgra, width, height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(base, ui.Offset.zero, ui.Paint());

    final size = ui.Size(width.toDouble(), height.toDouble());
    if (mark != null) {
      _drawMark(canvas, size, options, mark);
    } else {
      _drawText(canvas, size, options);
    }

    final picture = recorder.endRecording();
    final stamped = await picture.toImage(width, height);
    final data = await stamped.toByteData(format: ui.ImageByteFormat.rawRgba);
    base.dispose();
    stamped.dispose();
    picture.dispose();
    if (data == null) throw const PdfToolException('A page could not be drawn.');
    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return Isolate.run(() {
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        bytesOffset: rgba.offsetInBytes,
        order: img.ChannelOrder.rgba,
        numChannels: 4,
      );
      return img.encodeJpg(image, quality: _quality);
    });
  }

  static void _drawText(ui.Canvas canvas, ui.Size size, WatermarkOptions options) {
    final shortSide = math.min(size.width, size.height);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final color = Color.fromRGBO(110, 110, 110, options.opacity.value);

    TextPainter layout(double fontSize) {
      return TextPainter(
        text: TextSpan(
          text: options.text,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    }

    var painter = layout(shortSide * options.size.textFactor);
    final limit = diagonal * 0.75;
    if (painter.width > limit) {
      painter = layout(shortSide * options.size.textFactor * limit / painter.width);
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    if (options.layout == WatermarkLayout.center) {
      canvas.rotate(-math.pi / 4);
      painter.paint(canvas, ui.Offset(-painter.width / 2, -painter.height / 2));
    } else {
      canvas.rotate(-math.pi / 6);
      final stepX = painter.width * 1.6;
      final stepY = painter.height * 3.2;
      var row = 0;
      for (var y = -diagonal; y < diagonal; y += stepY) {
        final shift = row.isOdd ? stepX / 2 : 0.0;
        for (var x = -diagonal + shift; x < diagonal; x += stepX) {
          painter.paint(canvas, ui.Offset(x, y));
        }
        row++;
      }
    }
    canvas.restore();
  }

  static void _drawMark(ui.Canvas canvas, ui.Size size, WatermarkOptions options, ui.Image mark) {
    final shortSide = math.min(size.width, size.height);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final markWidth = shortSide * options.size.imageFactor;
    final markHeight = markWidth * mark.height / mark.width;
    final source = ui.Rect.fromLTWH(0, 0, mark.width.toDouble(), mark.height.toDouble());
    final paint = ui.Paint()
      ..color = Color.fromRGBO(255, 255, 255, options.opacity.value)
      ..filterQuality = ui.FilterQuality.high;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    if (options.layout == WatermarkLayout.center) {
      canvas.drawImageRect(
        mark,
        source,
        ui.Rect.fromLTWH(-markWidth / 2, -markHeight / 2, markWidth, markHeight),
        paint,
      );
    } else {
      canvas.rotate(-math.pi / 6);
      final stepX = markWidth * 1.5;
      final stepY = markHeight * 1.8;
      var row = 0;
      for (var y = -diagonal; y < diagonal; y += stepY) {
        final shift = row.isOdd ? stepX / 2 : 0.0;
        for (var x = -diagonal + shift; x < diagonal; x += stepX) {
          canvas.drawImageRect(mark, source, ui.Rect.fromLTWH(x, y, markWidth, markHeight), paint);
        }
        row++;
      }
    }
    canvas.restore();
  }
}
