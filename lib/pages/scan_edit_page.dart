import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../image_tools.dart';
import '../theme.dart';
import '../widgets.dart';

/// Crop, straighten and choose a look for one scanned page.
///
/// Changes are written straight into [page]. Closes with `true` when the user
/// taps Done.
class ScanEditPage extends StatefulWidget {
  const ScanEditPage({super.key, required this.page});

  final ScanPageData page;

  @override
  State<ScanEditPage> createState() => _ScanEditPageState();
}

class _ScanEditPageState extends State<ScanEditPage> {
  late List<double> _corners;
  late ScanFilter _filter;
  late ScanSource _source;

  bool _showPreview = false;
  bool _working = false;
  Uint8List? _preview;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _corners = List<double>.of(widget.page.corners);
    _filter = widget.page.filter;
    _source = widget.page.source;
  }

  Future<void> _refreshPreview() async {
    final token = ++_token;
    setState(() => _working = true);
    try {
      final bytes = await renderScan(_source.small, _corners, _filter, maxSide: 1000, quality: 80);
      if (!mounted || token != _token) return;
      setState(() {
        _preview = bytes;
        _working = false;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _working = false);
      showMessage(context, 'Could not show the preview.');
    }
  }

  void _setMode(bool preview) {
    setState(() => _showPreview = preview);
    if (preview) _refreshPreview();
  }

  void _setFilter(ScanFilter filter) {
    setState(() {
      _filter = filter;
      _showPreview = true;
    });
    _refreshPreview();
  }

  Future<void> _rotate(bool clockwise) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final rotated = await rotateScanSource(_source, clockwise: clockwise);
      if (!mounted) return;
      setState(() {
        _source = rotated;
        _corners = List<double>.of(defaultScanCorners);
        _preview = null;
        _working = false;
      });
      if (_showPreview) await _refreshPreview();
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      showMessage(context, 'Could not turn the page.');
    }
  }

  void _done() {
    widget.page
      ..source = _source
      ..corners = _corners
      ..filter = _filter;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final previewBytes = _preview;
    return ToolPage(
      title: 'Crop and filter',
      icon: Icons.crop_rounded,
      palette: TilePalette.teal,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: (_showPreview && previewBytes != null)
                        ? Center(child: Image.memory(previewBytes, fit: BoxFit.contain, gaplessPlayback: true))
                        : _CropArea(
                            key: ValueKey(_source),
                            bytes: _source.small,
                            imageWidth: _source.smallWidth,
                            imageHeight: _source.smallHeight,
                            corners: _corners,
                            onChanged: (value) => setState(() => _corners = value),
                          ),
                  ),
                  if (_working) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Adjust crop'),
                  selected: !_showPreview,
                  onSelected: (_) => _setMode(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Preview'),
                  selected: _showPreview,
                  onSelected: (_) => _setMode(true),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Turn left',
                  onPressed: _working ? null : () => _rotate(false),
                  icon: const Icon(Icons.rotate_left_rounded),
                ),
                IconButton(
                  tooltip: 'Turn right',
                  onPressed: _working ? null : () => _rotate(true),
                  icon: const Icon(Icons.rotate_right_rounded),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final filter in ScanFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => _setFilter(filter),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottom: PrimaryButton(label: 'Done', icon: Icons.check_rounded, onPressed: _done),
    );
  }
}

/// The photo with four handles to drag onto the corners of the page.
class _CropArea extends StatefulWidget {
  const _CropArea({
    super.key,
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.corners,
    required this.onChanged,
  });

  final Uint8List bytes;
  final int imageWidth;
  final int imageHeight;
  final List<double> corners;
  final ValueChanged<List<double>> onChanged;

  @override
  State<_CropArea> createState() => _CropAreaState();
}

class _CropAreaState extends State<_CropArea> {
  static const double _grab = 48;

  int? _active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final scale = math.min(maxW / widget.imageWidth, maxH / widget.imageHeight);
        final w = widget.imageWidth * scale;
        final h = widget.imageHeight * scale;
        final left = (maxW - w) / 2;
        final top = (maxH - h) / 2;

        Offset screenPoint(int i) => Offset(left + widget.corners[i * 2] * w, top + widget.corners[i * 2 + 1] * h);
        final points = [for (var i = 0; i < 4; i++) screenPoint(i)];

        void moveTo(int index, Offset position) {
          final next = List<double>.of(widget.corners);
          next[index * 2] = ((position.dx - left) / w).clamp(0.0, 1.0);
          next[index * 2 + 1] = ((position.dy - top) / h).clamp(0.0, 1.0);
          widget.onChanged(next);
        }

        return SizedBox(
          width: maxW,
          height: maxH,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              int? best;
              var bestDistance = _grab;
              for (var i = 0; i < 4; i++) {
                final distance = (points[i] - details.localPosition).distance;
                if (distance < bestDistance) {
                  bestDistance = distance;
                  best = i;
                }
              }
              _active = best;
            },
            onPanUpdate: (details) {
              final active = _active;
              if (active != null) moveTo(active, details.localPosition);
            },
            onPanEnd: (_) => _active = null,
            onPanCancel: () => _active = null,
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: w,
                  height: h,
                  child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                ),
                Positioned.fill(child: CustomPaint(painter: _CropPainter(points))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path()..addPolygon(points, true);

    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      shape,
    );
    canvas.drawPath(outside, Paint()..color = const Color(0x66000000));

    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (final point in points) {
      canvas.drawCircle(point, 13, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        13,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}
