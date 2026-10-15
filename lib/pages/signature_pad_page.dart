import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../signature_store.dart';
import '../theme.dart';
import '../widgets.dart';

/// A white pad to draw a signature with a finger or mouse.
///
/// Closes with the drawn [SignatureData], or nothing when cancelled.
class SignaturePadPage extends StatefulWidget {
  const SignaturePadPage({super.key});

  @override
  State<SignaturePadPage> createState() => _SignaturePadPageState();
}

class _SignaturePadPageState extends State<SignaturePadPage> {
  final List<List<Offset>> _strokes = [];
  bool _remember = true;

  void _done() {
    final points = [for (final stroke in _strokes) ...stroke];
    if (points.isEmpty) return;
    var minX = points.first.dx;
    var maxX = minX;
    var minY = points.first.dy;
    var maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final width = math.max(maxX - minX, 1.0);
    final height = math.max(maxY - minY, 1.0);
    final data = SignatureData(
      strokes: [
        for (final stroke in _strokes)
          [
            for (final p in stroke) ...[(p.dx - minX) / width, (p.dy - minY) / height],
          ],
      ],
      aspect: (width / height).clamp(0.3, 8.0).toDouble(),
    );
    if (_remember) SignatureStore.save(data);
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: 'Draw your signature',
      icon: Icons.draw_outlined,
      palette: TilePalette.yellow,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.muted.withValues(alpha: 0.4)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                    onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                    child: CustomPaint(painter: _PadPainter(_strokes), size: Size.infinite),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _strokes.isEmpty ? null : () => setState(_strokes.removeLast),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Undo'),
                ),
                TextButton.icon(
                  onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear'),
                ),
              ],
            ),
            CheckboxListTile(
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Remember it on this phone', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
      bottom: PrimaryButton(
        label: 'Use this signature',
        icon: Icons.check_rounded,
        onPressed: _strokes.isEmpty ? null : _done,
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14339F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) => true;
}
