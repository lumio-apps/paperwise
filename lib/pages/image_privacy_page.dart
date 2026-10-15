import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../exif_info.dart';
import '../file_store.dart';
import '../format.dart';
import '../image_result_sheet.dart';
import '../image_tools.dart';
import '../theme.dart';
import '../widgets.dart';
import 'redact_page.dart';

enum _Size {
  original('Original', null),
  large('Large', 2048),
  medium('Medium', 1280),
  small('Small', 800);

  const _Size(this.label, this.maxSide);
  final String label;
  final int? maxSide;
}

enum _Quality {
  high('High', 92),
  medium('Medium', 80),
  low('Low', 60);

  const _Quality(this.label, this.value);
  final String label;
  final int value;
}

/// One picture waiting to be cleaned.
class _Item {
  _Item({required this.path, required this.name, required this.sizeBytes, required this.exif});

  final String path;
  final String name;
  final int sizeBytes;
  final ExifInfo exif;
  List<RedactBox> boxes = [];

}

/// Removes hidden data (location, device, date) from pictures, and can
/// resize, compress, blur or hide parts of them.
class ImagePrivacyPage extends StatefulWidget {
  const ImagePrivacyPage({super.key});

  @override
  State<ImagePrivacyPage> createState() => _ImagePrivacyPageState();
}

class _ImagePrivacyPageState extends State<ImagePrivacyPage> {
  final List<_Item> _items = [];
  _Size _size = _Size.original;
  _Quality _quality = _Quality.high;
  bool _reading = false;
  bool _busy = false;
  String? _progress;

  Future<void> _pick() async {
    final List<PlatformFile> picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the file picker.');
      return;
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _reading = true);
    var skipped = 0;
    final added = <_Item>[];
    for (final file in picked) {
      try {
        final path = await _localPath(file);
        if (path == null) {
          skipped++;
          continue;
        }
        final bytes = await File(path).readAsBytes();
        added.add(_Item(path: path, name: file.name, sizeBytes: bytes.length, exif: readExif(bytes)));
      } catch (_) {
        skipped++;
      }
    }
    if (!mounted) return;
    setState(() {
      _items.addAll(added);
      _reading = false;
    });
    if (skipped > 0) {
      showMessage(context, skipped == 1 ? 'One file could not be read.' : '$skipped files could not be read.');
    }
  }

  /// Makes sure we have a real file path, copying the file into the cache if needed.
  Future<String?> _localPath(PlatformFile file) async {
    final path = file.path;
    if (path != null && await File(path).exists()) return path;
    try {
      final bytes = await file.readAsBytes();
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}/picked');
      await dir.create(recursive: true);
      final copy = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${FileStore.cleanName(file.name)}');
      await copy.writeAsBytes(bytes, flush: true);
      return copy.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _editBoxes(_Item item) async {
    final result = await Navigator.of(context).push<List<RedactBox>>(
      MaterialPageRoute<List<RedactBox>>(builder: (_) => RedactPage(path: item.path, initial: item.boxes)),
    );
    if (result == null || !mounted) return;
    setState(() => item.boxes = result);
  }

  Future<void> _clean() async {
    if (_items.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _progress = null;
    });

    try {
      final temp = await getTemporaryDirectory();
      final folder = Directory('${temp.path}/paperwise_clean');
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);

      final used = <String>{};
      final paths = <String>[];
      var before = 0;
      var after = 0;

      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (mounted) setState(() => _progress = 'Cleaning ${i + 1} of ${_items.length}');

        final bytes = await File(item.path).readAsBytes();
        final result = await cleanImage(
          bytes,
          maxSide: _size.maxSide,
          quality: _quality.value,
          boxes: item.boxes,
        );

        final dot = item.name.lastIndexOf('.');
        final stem = FileStore.cleanName(dot > 0 ? item.name.substring(0, dot) : item.name);
        final extension = result.png ? 'png' : 'jpg';
        var name = '${stem}_clean.$extension';
        var n = 2;
        while (!used.add(name)) {
          name = '${stem}_clean_$n.$extension';
          n++;
        }

        final out = File('${folder.path}/$name');
        await out.writeAsBytes(result.bytes, flush: true);
        paths.add(out.path);
        before += bytes.length;
        after += result.bytes.length;
      }

      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      await showImagesResultSheet(
        context,
        paths,
        note: 'Hidden data removed · ${formatBytes(before)} to ${formatBytes(after)}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      showMessage(context, 'Could not clean the pictures. Try fewer or smaller ones.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Image privacy',
      icon: Icons.privacy_tip_outlined,
      palette: TilePalette.purple,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          if (_items.isEmpty)
            SectionCard(
              child: EmptyState(
                icon: Icons.privacy_tip_outlined,
                palette: TilePalette.purple,
                title: 'Clean your pictures',
                message: 'Remove location, phone name and date from photos before you share them. '
                    'You can also resize, compress, and blur faces or text.',
                action: _reading
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Choose pictures', icon: Icons.add_rounded, onPressed: _pick),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_items.length} ${_items.length == 1 ? 'picture' : 'pictures'}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                TextButton.icon(
                  onPressed: (_busy || _reading) ? null : _pick,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Add more'),
                ),
              ],
            ),
            if (_reading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemCard(
                  item: _items[i],
                  onBlur: _busy ? null : () => _editBoxes(_items[i]),
                  onRemove: _busy ? null : () => setState(() => _items.removeAt(i)),
                ),
              ),
            const SizedBox(height: 10),
            ChoiceGroup<_Size>(
              label: 'Size',
              options: _Size.values,
              selected: _size,
              labelOf: (s) => s.label,
              onChanged: (s) => setState(() => _size = s),
              enabled: !_busy,
            ),
            const SizedBox(height: 4),
            Text(
              _size.maxSide == null ? 'Keeps the original size.' : 'Longest side at most ${_size.maxSide} pixels.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            ChoiceGroup<_Quality>(
              label: 'Compression (JPG)',
              options: _Quality.values,
              selected: _quality,
              labelOf: (q) => q.label,
              onChanged: (q) => setState(() => _quality = q),
              enabled: !_busy,
            ),
            const SizedBox(height: 4),
            Text(
              'Lower quality makes smaller files. PNG pictures stay sharp and are not compressed this way.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text(
              'Paperwise rebuilds each picture from its pixels only, so every hidden detail is left behind. '
              'Your originals are never changed.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted),
            ),
          ],
        ],
      ),
      bottom: _items.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_progress != null) ...[
                  Text(_progress!, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 10),
                ],
                PrimaryButton(
                  label: _items.length == 1 ? 'Clean picture' : 'Clean ${_items.length} pictures',
                  icon: Icons.cleaning_services_outlined,
                  busy: _busy,
                  onPressed: _reading ? null : _clean,
                ),
              ],
            ),
    );
  }
}

/// A picture with what was found inside it.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onBlur, required this.onRemove});

  final _Item item;
  final VoidCallback? onBlur;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final exif = item.exif;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(item.path),
                  width: 64,
                  height: 64,
                  cacheWidth: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.track,
                    child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatBytes(item.sizeBytes),
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (exif.hasLocation)
                          _Chip(icon: Icons.location_on_outlined, text: exif.locationText!, warning: true),
                        if (exif.device != null) _Chip(icon: Icons.smartphone_outlined, text: exif.device!, warning: true),
                        if (exif.dateText != null) _Chip(icon: Icons.event_outlined, text: exif.dateText!, warning: true),
                        if (exif.software != null && exif.software!.length <= 28)
                          _Chip(icon: Icons.apps_outlined, text: exif.software!, warning: false),
                        if (!exif.hasPrivateDetails)
                          const _Chip(icon: Icons.check_circle_outline, text: 'No details found', warning: false),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onBlur,
                icon: const Icon(Icons.blur_on_rounded, size: 20),
                label: Text(item.boxes.isEmpty ? 'Blur or hide parts' : 'Blur or hide · ${item.boxes.length}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.warning});

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = warning ? TilePalette.orange : TilePalette.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.color),
            ),
          ),
        ],
      ),
    );
  }
}
