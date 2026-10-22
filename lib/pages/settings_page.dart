import 'package:flutter/material.dart';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_settings.dart';
import '../backup.dart';
import '../file_actions.dart';
import '../flat_ui.dart';
import '../strings.dart';
import '../theme.dart';
import '../update_service.dart';
import '../widgets.dart';

const _sourceUrl = 'https://github.com/lumio-apps/paperwise';

/// App info, updates, privacy and licenses.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Your privacy'.tr),
        content: const Text(
          'Paperwise works fully offline. Every tool runs on your phone, so your files never leave it.\n\n'
          'There are no ads, no analytics and no account.\n\n'
          'The only time Paperwise uses the internet is when you tap "Check for updates", '
          'which asks GitHub whether a newer version exists.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'.tr)),
        ],
      ),
    );
  }

  Future<void> _backUp() async {
    try {
      final file = await PaperwiseBackup.create();
      if (!mounted) return;
      if (file == null) {
        showMessage(context, 'Nothing to back up yet.'.tr);
        return;
      }
      final name = file.uri.pathSegments.last;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Backup is ready'.tr),
          content: Text('Keep it somewhere safe, like Drive or your computer.'.tr),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/octet-stream')]));
              },
              child: Text('Share'.tr),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                saveFileToDevice(context, file.path, name, 'application/octet-stream');
              },
              child: Text('Save to phone'.tr),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not make the backup. Please try again.'.tr);
    }
  }

  Future<void> _restore() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.any);
      if (picked == null || !mounted) return;
      var path = picked.path;
      if (path == null || !await File(path).exists()) {
        final temp = await getTemporaryDirectory();
        final copy = File('${temp.path}/restore.pwbackup');
        await copy.writeAsBytes(await picked.readAsBytes(), flush: true);
        path = copy.path;
      }
      final result = await PaperwiseBackup.restore(path);
      if (mounted) showMessage(context, restoredMessage(result.restored, result.skipped));
    } on NotABackupException {
      if (mounted) showMessage(context, 'That is not a Paperwise backup.'.tr);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not restore the backup. Please try again.'.tr);
    }
  }

  Future<void> _copySourceLink() async {
    await Clipboard.setData(const ClipboardData(text: _sourceUrl));
    if (mounted) showMessage(context, 'Link copied.'.tr);
  }

  void _showLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'Paperwise',
      applicationVersion: _version,
      applicationIcon: const Padding(
        padding: EdgeInsets.all(12),
        child: AppLogo(size: 64),
      ),
      applicationLegalese: '© Lumio Apps · MIT License',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppSettings.instance, builder: (context, _) => _content(context));
  }

  Widget _content(BuildContext context) {
    final settings = AppSettings.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          'Settings'.tr,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Row(
            children: [
              const AppLogo(size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paperwise',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _version.isEmpty ? 'Offline PDF toolkit' : 'Version $_version',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                    Text(
                      'by Lumio Apps',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Look'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text('Light'.tr)),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text('Dark'.tr)),
                    ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text('System'.tr)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (value) => settings.setThemeMode(value.first),
                ),
              ),
              const SizedBox(height: 18),
              Text('Language'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  segments: [
                    for (final language in AppLanguage.values)
                      ButtonSegment(value: language, label: Text(language.label)),
                  ],
                  selected: {settings.language},
                  onSelectionChanged: (value) => settings.setLanguage(value.first),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.backup_outlined,
              palette: TilePalette.teal,
              title: 'Back up your files',
              subtitle: 'Save your PDFs and settings in one file',
              onTap: _backUp,
            ),
            _SettingsTile(
              icon: Icons.settings_backup_restore_rounded,
              palette: TilePalette.pink,
              title: 'Restore from a backup',
              subtitle: 'Bring back files from a Paperwise backup',
              onTap: _restore,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.system_update_rounded,
              palette: TilePalette.blue,
              title: 'Check for updates',
              subtitle: 'Asks GitHub if a newer version exists',
              onTap: () => UpdateService.checkForUpdates(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.shield_outlined,
              palette: TilePalette.green,
              title: 'Privacy',
              subtitle: 'No ads, no tracking, no account',
              onTap: _showPrivacy,
            ),
            _SettingsTile(
              icon: Icons.code_rounded,
              palette: TilePalette.slate,
              title: 'Source code',
              subtitle: 'github.com/lumio-apps/paperwise',
              trailing: Icons.content_copy_rounded,
              onTap: _copySourceLink,
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              palette: TilePalette.orange,
              title: 'Open source licenses',
              subtitle: 'Paperwise is free and open source',
              onTap: _showLicenses,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Simple, private, open source apps by Lumio Apps'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final TilePalette palette;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Panel(
        pressed: true,
        radius: 14,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: palette.color, size: 22)),
      ),
      title: Text(
        title.tr,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      subtitle: Text(subtitle.tr, style: TextStyle(fontSize: 13, color: AppColors.muted)),
      trailing: Icon(trailing, color: AppColors.muted, size: 20),
    );
  }
}
