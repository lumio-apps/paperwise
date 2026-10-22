import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../file_store.dart';
import '../id_card_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Border {
  thin('Thin border'),
  none('No border');

  const _Border(this.label);
  final String label;
}

/// Puts the front and back of an ID card (Aadhaar, PAN, licence) on one A4 page.
class IdCardPage extends StatefulWidget {
  const IdCardPage({super.key});

  @override
  State<IdCardPage> createState() => _IdCardPageState();
}

class _IdCardPageState extends State<IdCardPage> {
  // Big enough for a sharp print of a card, small enough to keep the PDF light.
  static const double _maxSide = 2000;
  static const int _quality = 88;

  final _picker = ImagePicker();
  XFile? _front;
  XFile? _back;
  CardSize _size = CardSize.actual;
  _Border _border = _Border.thin;
  bool _busy = false;

  Future<void> _pick({required bool front, required ImageSource source}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (!mounted || picked == null) return;
      setState(() {
        if (front) {
          _front = picked;
        } else {
          _back = picked;
        }
      });
    } catch (_) {
      if (mounted) showMessage(context, source == ImageSource.camera ? 'Could not open the camera.' : 'Could not open your photos.');
    }
  }

  void _clear({required bool front}) {
    setState(() {
      if (front) {
        _front = null;
      } else {
        _back = null;
      }
    });
  }

  Future<void> _create() async {
    final front = _front;
    if (front == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await buildIdCardPdf(
        front: await front.readAsBytes(),
        back: await _back?.readAsBytes(),
        size: _size,
        border: _border == _Border.thin,
      );
      final saved = await FileStore.instance.save(FileStore.timestampName('ID_card'), bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Could not create the PDF. Try different photos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'ID card to PDF',
      icon: Icons.badge_outlined,
      palette: TilePalette.blue,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _Slot(
            title: 'Front',
            file: _front,
            enabled: !_busy,
            onGallery: () => _pick(front: true, source: ImageSource.gallery),
            onCamera: () => _pick(front: true, source: ImageSource.camera),
            onClear: () => _clear(front: true),
          ),
          const SizedBox(height: 14),
          _Slot(
            title: 'Back (optional)',
            file: _back,
            enabled: !_busy,
            onGallery: () => _pick(front: false, source: ImageSource.gallery),
            onCamera: () => _pick(front: false, source: ImageSource.camera),
            onClear: () => _clear(front: false),
          ),
          const SizedBox(height: 18),
          ChoiceGroup<CardSize>(
            label: 'Size on paper',
            options: CardSize.values,
            selected: _size,
            labelOf: (s) => s.label,
            onChanged: (value) => setState(() => _size = value),
            enabled: !_busy,
          ),
          const SizedBox(height: 4),
          Text(
            _size == CardSize.actual
                ? 'Printed at the real size of a card (85.6 × 54 mm).'
                : 'Bigger, about 15 cm wide, easier to read.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          ChoiceGroup<_Border>(
            label: 'Border',
            options: _Border.values,
            selected: _border,
            labelOf: (b) => b.label,
            onChanged: (value) => setState(() => _border = value),
            enabled: !_busy,
          ),
          const SizedBox(height: 14),
          Text(
            'Both sides go on one A4 page, front on top. Take the photos flat and in good light, with all four corners visible.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
      bottom: PrimaryButton(
        label: 'Create PDF',
        icon: Icons.picture_as_pdf_outlined,
        onPressed: _front == null ? null : _create,
        busy: _busy,
      ),
    );
  }
}

/// A place for one side of the card: add a photo, or see and change it.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.title,
    required this.file,
    required this.enabled,
    required this.onGallery,
    required this.onCamera,
    required this.onClear,
  });

  final String title;
  final XFile? file;
  final bool enabled;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final picked = file;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: FieldLabel(title)),
              if (picked != null)
                TextButton(
                  onPressed: enabled ? onClear : null,
                  child: const Text('Remove'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (picked == null)
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(label: 'Gallery', icon: Icons.photo_library_outlined, onPressed: enabled ? onGallery : null),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(label: 'Camera', icon: Icons.photo_camera_outlined, onPressed: enabled ? onCamera : null),
                ),
              ],
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(picked.path),
                height: 170,
                width: double.infinity,
                cacheHeight: 400,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  height: 170,
                  color: AppColors.track,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
