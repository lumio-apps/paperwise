import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A drawn signature. Points are fractions (0 to 1) of the box around it.
class SignatureData {
  const SignatureData({required this.strokes, required this.aspect});

  /// Each stroke is a flat list x,y,x,y...
  final List<List<double>> strokes;

  /// Width divided by height of the box around the signature.
  final double aspect;

  Map<String, Object?> toJson() => {'aspect': aspect, 'strokes': strokes};

  static SignatureData? fromJson(Object? json) {
    if (json is! Map) return null;
    final aspect = json['aspect'];
    final strokes = json['strokes'];
    if (aspect is! num || strokes is! List) return null;
    final result = <List<double>>[];
    for (final stroke in strokes) {
      if (stroke is! List) return null;
      result.add([for (final value in stroke) (value as num).toDouble()]);
    }
    if (result.isEmpty || aspect <= 0) return null;
    return SignatureData(strokes: result, aspect: aspect.toDouble());
  }
}

/// Keeps one signature in the app's own storage so it can be used again.
class SignatureStore {
  SignatureStore._();

  static Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/paperwise_signature.json');
  }

  static Future<SignatureData?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return SignatureData.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SignatureData data) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(data.toJson()), flush: true);
    } catch (_) {
      // Not being able to remember the signature is not worth an error.
    }
  }

  static Future<void> remove() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing to do.
    }
  }
}
