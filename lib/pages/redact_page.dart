import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../image_tools.dart';
import '../theme.dart';
import '../widgets.dart';

/// Draw boxes over the parts of a picture that should be blurred or hidden.
///
/// Closes with the list of boxes when the user taps Done.
class RedactPage extends StatefulWidget {
  const RedactPage({super.key, required this.path, required this.initial});

  final String path;
  final List<RedactBox> initial;

  @override
  State<RedactPage> createState() => _RedactPageState();
}

class _RedactPageState extends State<RedactPage> {
  late final List<RedactBox> _boxes = List<RedactBox>.of(widget.initial);

  RedactPreview? _preview;
  bool _failed = false;
  bool _blackOut = false;

  Offset? _start;
  Offset? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final preview = await prepareRedactPreview(bytes);
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _finishBox() {
    final start = _start;
    final current = _current;
    _start = null;
    _current = null;
    if (start == null || current == null) {
      setState(() {});
      return;
    }
    final left = math.min(start.dx, current.dx);
    final right = math.max(start.dx, current.dx);
    final top = math.min(start.dy, current.dy);
    final bottom = math.max(start.dy, current.dy);
    setState(() {
      // Ignore tiny accidental drags.
      if (right - left > 0.015 && bottom - top > 0.015) {
        _boxes.add(RedactBox(left, top, right, bottom, blackOut: _blackOut));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return ToolPage(
      title: 'Blur or hide',
      icon: Icons.blur_on_rounded,
      palette: TilePalette.purple,
      body: _failed
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('This picture could not be opened.', textAlign: TextAlign.center),
              ),
            )
          : preview == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Drag on the picture to cover faces, plates or text.',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                      ),
                    ),
                    Expanded(child: _buildCanvas(preview)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Blur'),
                            selected: !_blackOut,
                            onSelected: (_) => setState(() => _blackOut = false),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Black box'),
                            selected: _blackOut,
                            onSelected: (_) => setState(() => _blackOut = true),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Undo',
                            onPressed: _boxes.isEmpty ? null : () => setState(_boxes.removeLast),
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          IconButton(
                            tooltip: 'Clear all',
                            onPressed: _boxes.isEmpty ? null : () => setState(_boxes.clear),
                            icon: const Icon(Icons.delete_sweep_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      bottom: PrimaryButton(
        label: _boxes.isEmpty ? 'Done' : 'Done · ${_boxes.length} ${_boxes.length == 1 ? 'area' : 'areas'}',
        icon: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(List<RedactBox>.of(_boxes)),
      ),
    );
  }

  Widget _buildCanvas(RedactPreview preview) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth - 32;
        final maxH = constraints.maxHeight;
        final scale = math.min(maxW / preview.width, maxH / preview.height);
        final w = preview.width * scale;
        final h = preview.height * scale;
        final left = (constraints.maxWidth - w) / 2;
        final top = (maxH - h) / 2;

        Offset toUnit(Offset local) => Offset(
              ((local.dx - left) / w).clamp(0.0, 1.0).toDouble(),
              ((local.dy - top) / h).clamp(0.0, 1.0).toDouble(),
            );

        return SizedBox(
          width: constraints.maxWidth,
          height: maxH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => setState(() {
              _start = toUnit(details.localPosition);
              _current = _start;
            }),
            onPanUpdate: (details) => setState(() => _current = toUnit(details.localPosition)),
            onPanEnd: (_) => _finishBox(),
            onPanCancel: _finishBox,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: w,
                  height: h,
                  child: Image.memory(preview.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: w,
                  height: h,
                  child: CustomPaint(
                    painter: _BoxPainter(
                      boxes: _boxes,
                      start: _start,
                      current: _current,
                      drawingBlack: _blackOut,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({required this.boxes, required this.start, required this.current, required this.drawingBlack});

  final List<RedactBox> boxes;
  final Offset? start;
  final Offset? current;
  final bool drawingBlack;

  void _draw(Canvas canvas, Size size, Rect unit, bool black) {
    final rect = Rect.fromLTRB(unit.left * size.width, unit.top * size.height, unit.right * size.width, unit.bottom * size.height);
    canvas.drawRect(rect, Paint()..color = black ? const Color(0xE6000000) : const Color(0x992346C8));
    canvas.drawRect(
      rect,
      Paint()
        ..color = black ? Colors.white : const Color(0xFF2346C8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      _draw(canvas, size, Rect.fromLTRB(box.left, box.top, box.right, box.bottom), box.blackOut);
    }
    final a = start;
    final b = current;
    if (a != null && b != null) {
      _draw(canvas, size, Rect.fromPoints(a, b), drawingBlack);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => true;
}
