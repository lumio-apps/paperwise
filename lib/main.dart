import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app_settings.dart';
import 'external_open.dart';
import 'file_store.dart';
import 'home_shell.dart';
import 'library.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Outfit font is bundled in the app, so its license is shown with the others.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Outfit font'], text);
  });

  await pdfrxFlutterInitialize();
  await AppSettings.instance.load();
  await FileStore.instance.load();
  await ReadingLibrary.instance.load();
  runApp(const PaperwiseApp());
  ExternalOpen.start(navigatorKey);
}

class PaperwiseApp extends StatefulWidget {
  const PaperwiseApp({super.key});

  @override
  State<PaperwiseApp> createState() => _PaperwiseAppState();
}

class _PaperwiseAppState extends State<PaperwiseApp> {
  bool? _dark;
  AppLanguage? _language;

  /// Many screens read colors and texts straight from [AppColors] and `.tr`.
  /// When the look or the language changes, every screen is asked to draw again.
  void _syncLook(bool dark, AppLanguage language) {
    AppColors.isDark = dark;
    final changed = _dark != null && (_dark != dark || _language != language);
    _dark = dark;
    _language = language;
    if (changed) WidgetsBinding.instance.addPostFrameCallback((_) => _redrawEverything());
  }

  void _redrawEverything() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          title: 'Paperwise',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(dark: false),
          darkTheme: buildTheme(dark: true),
          themeMode: settings.themeMode,
          themeAnimationDuration: Duration.zero,
          locale: Locale(settings.language.code),
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            _syncLook(Theme.of(context).brightness == Brightness.dark, settings.language);
            return child ?? const SizedBox.shrink();
          },
          home: const HomeShell(),
        );
      },
    );
  }
}
