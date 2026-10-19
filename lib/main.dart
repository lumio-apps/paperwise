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

  // A screen that fails to draw would be a plain grey box in the release app.
  // Show what went wrong instead, so it can be reported and fixed.
  ErrorWidget.builder = _errorScreen;

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

Widget _errorScreen(FlutterErrorDetails details) {
  var message = details.exceptionAsString();
  if (message.length > 700) message = '${message.substring(0, 700)}…';
  final trace = (details.stack?.toString() ?? '')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .take(14)
      .map((line) => line.length > 150 ? line.substring(0, 150) : line)
      .join('\n');
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFFF4F2FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This screen could not be shown.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF241F4F),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press the back button to leave. Your files are safe.',
                style: TextStyle(fontSize: 15, color: Color(0xFF5B5778), decoration: TextDecoration.none),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5B5778),
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                trace,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF5B5778),
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PaperwiseApp extends StatefulWidget {
  const PaperwiseApp({super.key});

  @override
  State<PaperwiseApp> createState() => _PaperwiseAppState();
}

class _PaperwiseAppState extends State<PaperwiseApp> {
  bool? _dark;
  AppLanguage? _language;
  bool? _reduce;

  /// Many screens read colors and texts straight from [AppColors] and `.tr`.
  /// When the look or the language changes, every screen is asked to draw again.
  void _syncLook(bool dark, AppLanguage language, bool reduce) {
    AppColors.isDark = dark;
    final changed = _dark != null && (_dark != dark || _language != language || _reduce != reduce);
    _dark = dark;
    _language = language;
    _reduce = reduce;
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
            _syncLook(Theme.of(context).brightness == Brightness.dark, settings.language, settings.reduceEffects);
            return child ?? const SizedBox.shrink();
          },
          home: const HomeShell(),
        );
      },
    );
  }
}
