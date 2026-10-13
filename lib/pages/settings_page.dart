import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../coming_soon_sheet.dart';
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
        title: const Text('Your privacy'),
        content: const Text(
          'Paperwise works fully offline. Every tool runs on your phone, so your files never leave it.\n\n'
          'There are no ads, no analytics and no account.\n\n'
          'The only time Paperwise uses the internet is when you tap "Check for updates", '
          'which asks GitHub whether a newer version exists.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _copySourceLink() async {
    await Clipboard.setData(const ClipboardData(text: _sourceUrl));
    if (mounted) showMessage(context, 'Link copied.');
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Settings',
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
                    const Text(
                      'Paperwise',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _version.isEmpty ? 'Offline PDF toolkit' : 'Version $_version',
                      style: const TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                    const Text(
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
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.system_update_rounded,
              palette: TilePalette.blue,
              title: 'Check for updates',
              subtitle: 'Asks GitHub if a newer version exists',
              onTap: () => UpdateService.checkForUpdates(context),
            ),
            _SettingsTile(
              icon: Icons.upcoming_outlined,
              palette: TilePalette.purple,
              title: "What's coming",
              subtitle: 'The tools in the next updates',
              onTap: () => showComingSoonSheet(context),
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
        const Center(
          child: Text(
            'Simple, private, open source apps by Lumio Apps',
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
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: palette.color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      trailing: Icon(trailing, color: AppColors.muted, size: 20),
    );
  }
}
