import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

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
  await FileStore.instance.load();
  await ReadingLibrary.instance.load();
  runApp(const PaperwiseApp());
  ExternalOpen.start(navigatorKey);
}

class PaperwiseApp extends StatelessWidget {
  const PaperwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperwise',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}
