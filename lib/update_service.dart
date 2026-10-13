import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Checks GitHub Releases for a newer APK and installs it inside the app.
///
/// This is the only part of Paperwise that uses the internet, and only when
/// the user taps "Check for updates".
class UpdateService {
  static const _latestReleaseUrl = 'https://api.github.com/repos/lumio-apps/paperwise/releases/latest';

  /// Shows the full "Check for updates" flow with dialogs.
  static Future<void> checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates...'), duration: Duration(seconds: 1)),
    );

    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http
          .get(Uri.parse(_latestReleaseUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('You are on the latest version (${info.version}).')),
        );
        return;
      }
      if (res.statusCode != 200) throw Exception('Server returned ${res.statusCode}');

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String? ?? '').trim();
      final latest = latestTag.replaceFirst(RegExp(r'^[vV]'), '');
      final notes = (data['body'] as String? ?? '').trim();
      final assets = (data['assets'] as List? ?? []).cast<Map<String, dynamic>>();
      final apk = assets.where((a) => (a['name'] as String? ?? '').endsWith('.apk')).firstOrNull;

      if (!context.mounted) return;

      if (latest.isEmpty || !_isNewer(latest, info.version) || apk == null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('You are on the latest version (${info.version}).')),
        );
        return;
      }

      final install = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update available: $latestTag'),
          content: SingleChildScrollView(
            child: Text(
              'Current version: ${info.version}\n\n'
              '${notes.isEmpty ? 'A new version is ready to install.' : notes}',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
          ],
        ),
      );
      if (install != true || !context.mounted) return;

      await _downloadAndInstall(context, apk['browser_download_url'] as String);
    } catch (_) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not check for updates. Check your internet connection.')),
      );
    }
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url) async {
    final progress = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Downloading update'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (ctx, value, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                Text(value == null ? 'Starting...' : '${(value * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      ),
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) throw Exception('Download failed');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Paperwise-update.apk');
      final sink = file.openWrite();
      final total = response.contentLength ?? 0;
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) progress.value = received / total;
      }
      await sink.close();

      navigator.pop();
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open installer: ${result.message}')),
        );
      }
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Download failed. Please try again.')),
      );
    } finally {
      client.close();
      progress.dispose();
    }
  }

  /// Returns true if [latest] (e.g. "1.2.0") is newer than [current].
  static bool _isNewer(String latest, String current) {
    List<int> parse(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parse(latest);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
