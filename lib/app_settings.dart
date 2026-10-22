import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// How the Files list is ordered.
enum FileSort { newest, oldest, nameAZ, nameZA, largest, smallest }

/// The languages Paperwise can show.
enum AppLanguage {
  english('en', 'English'),
  hindi('hi', 'हिन्दी');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(Object? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return english;
  }
}

/// The choices from Settings: look (light, dark or system), language, file
/// order. They are kept in one small JSON file in the app's own storage.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.english;
  FileSort _fileSort = FileSort.newest;
  bool _readerNight = false;
  Future<void> _writeQueue = Future.value();

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  FileSort get fileSort => _fileSort;

  /// True when the PDF viewer shows pages with inverted colors (white text on dark).
  bool get readerNight => _readerNight;

  Future<File> _storage() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/paperwise_settings.json');
  }

  /// Reads the saved choices. A missing or damaged file just means the defaults.
  Future<void> load() async {
    try {
      final file = await _storage();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == decoded['theme'],
        orElse: () => ThemeMode.light,
      );
      _language = AppLanguage.fromCode(decoded['language']);
      _fileSort = FileSort.values.firstWhere(
        (s) => s.name == decoded['fileSort'],
        orElse: () => FileSort.newest,
      );
      _readerNight = decoded['readerNight'] == true;
      notifyListeners();
    } catch (_) {
      // Start with the defaults if the file can't be read.
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _changed();
  }

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    _changed();
  }

  void setFileSort(FileSort sort) {
    if (sort == _fileSort) return;
    _fileSort = sort;
    _changed();
  }

  void setReaderNight(bool value) {
    if (value == _readerNight) return;
    _readerNight = value;
    _changed();
  }

  void _changed() {
    notifyListeners();
    _writeQueue = _writeQueue.then((_) => _write());
  }

  Future<void> _write() async {
    try {
      final file = await _storage();
      final data = jsonEncode({
        'theme': _themeMode.name,
        'language': _language.code,
        'fileSort': _fileSort.name,
        'readerNight': _readerNight,
      });
      await file.writeAsString(data, flush: true);
    } catch (_) {
      // Not being able to save a choice is not worth an error.
    }
  }
}
