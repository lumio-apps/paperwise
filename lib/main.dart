import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import 'file_store.dart';
import 'home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Outfit font is bundled in the app, so its license is shown with the others.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Outfit font'], text);
  });

  await pdfrxFlutterInitialize();
  await FileStore.instance.load();
  runApp(const PaperwiseApp());
}

class PaperwiseApp extends StatelessWidget {
  const PaperwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperwise',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeShell(),
    );
  }
}
