import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// What Paperwise remembers about one PDF: where you stopped and if it is a favorite.
class ReadingInfo {
  const ReadingInfo({
    required this.path,
    this.page = 1,
    this.pageCount = 0,
    this.favorite = false,
    this.lastOpened,
  });

  final String path;

  /// The page you were on when you closed the viewer (first page is 1).
  final int page;

  /// Total pages, or 0 when the file was never opened in the viewer.
  final int pageCount;
  final bool favorite;
  final DateTime? lastOpened;

  /// How far through the PDF you are, from 0 to 1.
  double get progress => pageCount <= 0 ? 0 : (page / pageCount).clamp(0.0, 1.0);

  ReadingInfo copyWith({
    String? path,
    int? page,
    int? pageCount,
    bool? favorite,
    DateTime? lastOpened,
  }) {
    return ReadingInfo(
      path: path ?? this.path,
      page: page ?? this.page,
      pageCount: pageCount ?? this.pageCount,
      favorite: favorite ?? this.favorite,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }

  Map<String, Object?> toJson() => {
        'path': path,
        'page': page,
        'pageCount': pageCount,
        'favorite': favorite,
        'lastOpened': lastOpened?.millisecondsSinceEpoch,
      };

  static ReadingInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;
    final opened = json['lastOpened'];
    return ReadingInfo(
      path: path,
      page: json['page'] is int ? json['page'] as int : 1,
      pageCount: json['pageCount'] is int ? json['pageCount'] as int : 0,
      favorite: json['favorite'] == true,
      lastOpened: opened is int ? DateTime.fromMillisecondsSinceEpoch(opened) : null,
    );
  }
}

/// Remembers reading position and favorites. Everything stays in one small
/// JSON file in the app's own storage.
class ReadingLibrary extends ChangeNotifier {
  ReadingLibrary._();

  static final ReadingLibrary instance = ReadingLibrary._();

  final Map<String, ReadingInfo> _entries = {};
  Future<void> _writeQueue = Future.value();

  Future<File> _storage() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/paperwise_library.json');
  }

  /// Reads the saved list. A missing or damaged file just means an empty list.
  Future<void> load() async {
    try {
      final file = await _storage();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      _entries.clear();
      for (final item in decoded) {
        final info = ReadingInfo.fromJson(item);
        if (info != null) _entries[info.path] = info;
      }
      notifyListeners();
    } catch (_) {
      // Start fresh if the file can't be read.
    }
  }

  ReadingInfo? infoFor(String path) => _entries[path];

  bool isFavorite(String path) => _entries[path]?.favorite ?? false;

  /// PDFs you opened, newest first. Files that no longer exist are left out.
  List<ReadingInfo> recent({int limit = 1}) {
    final opened = _entries.values.where((e) => e.lastOpened != null && e.pageCount > 0).toList()
      ..sort((a, b) => b.lastOpened!.compareTo(a.lastOpened!));
    final result = <ReadingInfo>[];
    for (final info in opened) {
      if (!File(info.path).existsSync()) continue;
      result.add(info);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// Called when the viewer finishes loading a PDF.
  void recordOpened(String path, int pageCount) {
    final old = _entries[path] ?? ReadingInfo(path: path);
    final page = old.page.clamp(1, pageCount < 1 ? 1 : pageCount).toInt();
    _entries[path] = old.copyWith(pageCount: pageCount, page: page, lastOpened: DateTime.now());
    _changed();
  }

  /// Called while you read, so the next visit starts on the same page.
  void setPage(String path, int page, int pageCount) {
    final old = _entries[path] ?? ReadingInfo(path: path);
    if (old.page == page && old.pageCount == pageCount) return;
    _entries[path] = old.copyWith(page: page, pageCount: pageCount, lastOpened: DateTime.now());
    _changed();
  }

  void toggleFavorite(String path) {
    final old = _entries[path] ?? ReadingInfo(path: path);
    _entries[path] = old.copyWith(favorite: !old.favorite);
    _changed();
  }

  /// Keeps the saved data when a file is renamed.
  void move(String from, String to) {
    final old = _entries.remove(from);
    if (old == null) return;
    _entries[to] = old.copyWith(path: to);
    _changed();
  }

  /// Forgets a deleted file.
  void remove(String path) {
    if (_entries.remove(path) != null) _changed();
  }

  void _changed() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) => _write());
  }

  Future<void> _write() async {
    try {
      final file = await _storage();
      final data = jsonEncode([for (final e in _entries.values) e.toJson()]);
      await file.writeAsString(data, flush: true);
    } catch (_) {
      // Not being able to save the reading position is not worth an error.
    }
  }
}
