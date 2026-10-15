import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../image_tools.dart';
import '../pdf_editor.dart';
import '../pdf_stamper.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pdf_to_image_page.dart' show PickedPdfCard;

enum _Tool {
  highlight('Highlight', Icons.highlight_rounded),
  pen('Pen', Icons.edit_rounded),
  rectangle('Box', Icons.crop_square_rounded),
  ellipse('Oval', Icons.circle_outlined),
  line('Line', Icons.horizontal_rule_rounded),
  arrow('Arrow', Icons.arrow_right_alt_rounded);

  const _Tool(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum _Thickness {
  thin('Thin', 1.5),
  medium('Medium', 3),
  thick('Thick', 6);

  const _Thickness(this.label, this.points);
  final String label;
  final double points;
}

class _Ink {
  const _Ink(this.name, this.color);
  final String name;
  final StampColor color;
}

const _inks = <_Ink>[
  _Ink('Yellow', StampColor(1, 0.9, 0.1)),
  _Ink('Green', StampColor(0.35, 0.85, 0.35)),
  _Ink('Pink', StampColor(1, 0.45, 0.72)),
  _Ink('Blue', StampColor(0.2, 0.55, 1)),
  _Ink('Red', StampColor(0.85, 0.12, 0.12)),
  _Ink('Black', StampColor(0, 0, 0)),
];

/// One drawn mark. Points are fractions of the page.
class _Mark {
  _Mark({required this.page, required this.tool, required this.color, required this.width, required this.points});

  final int page;
  final _Tool tool;
  final StampColor color;
  final double width;

  /// Pen: every point of the stroke. Shapes: the start and the end.
  final List<Offset> points;
}

/// Highlight, draw and add shapes on a PDF, then save a copy.
class MarkupPage extends StatefulWidget {
  const MarkupPage({super.key});

  @override
  State<MarkupPage> createState() => _MarkupPageState();
}

class _MarkupPageState extends State<MarkupPage> {
  PickedPdf? _file;
  PdfDocument? _document;
  bool _opening = false;
  int _pageIndex = 0;
  Uint8List? _pageImage;
  int _renderToken = 0;

  _Tool _tool = _Tool.highlight;
  _Ink _ink = _inks.first;
  _Thickness _thickness = _Thickness.medium;

  final List<_Mark> _marks = [];
  _Mark? _drawing;
  bool _busy = false;

  int get _pageCount => _document?.pages.length ?? 0;

  @override
  void dispose() {
    _document?.dispose();
    super.dispose();
  }

  Future<void> _chooseFile() async {
    final List<PickedPdf> picked;
    try {
      picked = await pickPdfFiles(multiple: false);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the file picker.');
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final file = picked.first;
    setState(() {
      _file = file;
      _opening = true;
      _marks.clear();
      _drawing = null;
      _pageIndex = 0;
      _pageImage = null;
    });
    final old = _document;
    _document = null;
    await old?.dispose();
    await file.load();
    if (!mounted || _file != file) return;
    if (!file.isReady) {
      setState(() => _opening = false);
      return;
    }
    try {
      final document = await PdfTools.openDocument(file.path, file.name);
      if (!mounted || _file != file) {
        await document.dispose();
        return;
      }
      setState(() {
        _document = document;
        _opening = false;
      });
      await _renderPage();
    } catch (_) {
      if (mounted) {
        setState(() => _opening = false);
        showMessage(context, 'This PDF could not be opened.');
      }
    }
  }

  Future<void> _renderPage() async {
    final document = _document;
    if (document == null) return;
    final token = ++_renderToken;
    setState(() => _pageImage = null);
    try {
      final page = document.pages[_pageIndex];
      const targetWidth = 1100.0;
      final height = page.height * targetWidth / page.width;
      final rendered = await page.render(
        width: targetWidth.round(),
        height: height.round(),
        fullWidth: targetWidth,
        fullHeight: height,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) throw const PdfToolException('A page could not be drawn.');
      final Uint8List bytes;
      try {
        bytes = await encodeBgraPixels(rendered.pixels, rendered.width, rendered.height, png: false, quality: 82);
      } finally {
        rendered.dispose();
      }
      if (!mounted || token != _renderToken) return;
      setState(() => _pageImage = bytes);
    } catch (_) {
      if (mounted && token == _renderToken) showMessage(context, 'Could not show this page.');
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= _pageCount || index == _pageIndex) return;
    setState(() {
      _pageIndex = index;
      _drawing = null;
    });
    _renderPage();
  }

  Offset _unit(Offset local, Size size) {
    return Offset(
      (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
  }

  void _start(Offset local, Size size) {
    final p = _unit(local, size);
    setState(() {
      _drawing = _Mark(
        page: _pageIndex,
        tool: _tool,
        color: _ink.color,
        width: _thickness.points,
        points: _tool == _Tool.pen ? [p] : [p, p],
      );
    });
  }

  void _update(Offset local, Size size) {
    final mark = _drawing;
    if (mark == null) return;
    final p = _unit(local, size);
    setState(() {
      if (mark.tool == _Tool.pen) {
        mark.points.add(p);
      } else {
        mark.points[1] = p;
      }
    });
  }

  void _end() {
    final mark = _drawing;
    if (mark == null) return;
    setState(() {
      _drawing = null;
      // Ignore taps and tiny accidental drags.
      final a = mark.points.first;
      final b = mark.points.last;
      final moved = (a - b).distance > 0.012;
      if (mark.tool == _Tool.pen ? mark.points.length > 2 : moved) _marks.add(mark);
    });
  }

  Future<void> _save() async {
    final document = _document;
    final file = _file;
    if (document == null || file == null || _marks.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final byPage = <int, List<Stamp>>{};
      for (final mark in _marks) {
        final list = byPage.putIfAbsent(mark.page, () => []);
        final a = mark.points.first;
        final b = mark.points.last;
        final left = math.min(a.dx, b.dx);
        final right = math.max(a.dx, b.dx);
        final top = math.min(a.dy, b.dy);
        final bottom = math.max(a.dy, b.dy);
        switch (mark.tool) {
          case _Tool.highlight:
            list.add(
              RectStamp(left: left, top: top, right: right, bottom: bottom, color: mark.color, filled: true, opacity: 0.4),
            );
          case _Tool.pen:
            list.add(
              InkStamp(
                strokes: [
                  [
                    for (final p in mark.points) ...[p.dx, p.dy],
                  ],
                ],
                width: mark.width,
                color: mark.color,
              ),
            );
          case _Tool.rectangle:
            list.add(
              RectStamp(left: left, top: top, right: right, bottom: bottom, color: mark.color, width: mark.width),
            );
          case _Tool.ellipse:
            list.add(
              EllipseStamp(left: left, top: top, right: right, bottom: bottom, color: mark.color, width: mark.width),
            );
          case _Tool.line:
          case _Tool.arrow:
            list.add(
              LineStamp(
                fromLeft: a.dx,
                fromTop: a.dy,
                toLeft: b.dx,
                toTop: b.dy,
                color: mark.color,
                width: mark.width,
                arrow: mark.tool == _Tool.arrow,
              ),
            );
        }
      }
      final bytes = await PdfEditor.apply(document, StampPlan(byPage: byPage));
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_marked', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final document = _document;
    final count = _marks.length;
    return ToolPage(
      title: 'Markup',
      icon: Icons.highlight_rounded,
      palette: TilePalette.pink,
      body: file == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                SectionCard(
                  child: EmptyState(
                    icon: Icons.highlight_rounded,
                    palette: TilePalette.pink,
                    title: 'Choose a PDF',
                    message: 'Highlight, draw and add boxes, ovals and arrows. Everything happens on your phone.',
                    action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
                  ),
                ),
              ],
            )
          : (document == null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    PickedPdfCard(file: file, onChange: (_opening || _busy) ? null : _chooseFile),
                    if (_opening) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  ],
                )
              : _buildEditor(document)),
      bottom: document == null
          ? null
          : PrimaryButton(
              label: count == 0 ? 'Save a copy' : 'Save a copy · $count ${count == 1 ? 'mark' : 'marks'}',
              icon: Icons.check_rounded,
              onPressed: count == 0 ? null : _save,
              busy: _busy,
            ),
    );
  }

  Widget _buildEditor(PdfDocument document) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _pageIndex > 0 ? () => _goTo(_pageIndex - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  'Page ${_pageIndex + 1} of $_pageCount',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              IconButton(
                tooltip: 'Undo',
                onPressed: _marks.isEmpty || _busy ? null : () => setState(_marks.removeLast),
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                onPressed: _pageIndex < _pageCount - 1 ? () => _goTo(_pageIndex + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPage(document)),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final tool in _Tool.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(tool.icon, size: 18),
                    label: Text(tool.label),
                    selected: _tool == tool,
                    onSelected: (_) => setState(() => _tool = tool),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final ink in _inks)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Tooltip(
                    message: ink.name,
                    child: GestureDetector(
                      onTap: () => setState(() => _ink = ink),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _toColor(ink.color),
                          border: Border.all(
                            color: identical(_ink, ink) ? AppColors.accent : AppColors.line,
                            width: identical(_ink, ink) ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_tool != _Tool.highlight) ...[
                const SizedBox(width: 6),
                for (final thickness in _Thickness.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(thickness.label),
                      selected: _thickness == thickness,
                      onSelected: (_) => setState(() => _thickness = thickness),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  static Color _toColor(StampColor c) => Color.from(alpha: 1, red: c.red, green: c.green, blue: c.blue);

  Widget _buildPage(PdfDocument document) {
    final page = document.pages[_pageIndex];
    final image = _pageImage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min((constraints.maxWidth - 24) / page.width, (constraints.maxHeight - 8) / page.height);
        final size = Size(page.width * scale, page.height * scale);
        final marks = [..._marks.where((m) => m.page == _pageIndex), ?_drawing];
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _start(d.localPosition, size),
              onPanUpdate: (d) => _update(d.localPosition, size),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8)],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      Image.memory(image, fit: BoxFit.fill, gaplessPlayback: true),
                    CustomPaint(painter: _MarkPainter(marks, scale)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.marks, this.scale);

  final List<_Mark> marks;

  /// Screen pixels per PDF point.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      final color = _MarkupPageState._toColor(mark.color);
      final points = [for (final p in mark.points) Offset(p.dx * size.width, p.dy * size.height)];
      final a = points.first;
      final b = points.last;
      final stroke = Paint()
        ..color = color
        ..strokeWidth = math.max(mark.width * scale, 1)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      switch (mark.tool) {
        case _Tool.highlight:
          canvas.drawRect(Rect.fromPoints(a, b), Paint()..color = color.withValues(alpha: 0.4));
        case _Tool.pen:
          final path = Path()..moveTo(a.dx, a.dy);
          for (final p in points.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, stroke);
        case _Tool.rectangle:
          canvas.drawRect(Rect.fromPoints(a, b), stroke);
        case _Tool.ellipse:
          canvas.drawOval(Rect.fromPoints(a, b), stroke);
        case _Tool.line:
          canvas.drawLine(a, b, stroke);
        case _Tool.arrow:
          canvas.drawLine(a, b, stroke);
          final length = (b - a).distance;
          if (length > 1) {
            final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
            final head = math.max(8.0, mark.width * 5) * scale;
            for (final turn in const [0.45, -0.45]) {
              canvas.drawLine(
                b,
                Offset(b.dx - head * math.cos(angle + turn), b.dy - head * math.sin(angle + turn)),
                stroke,
              );
            }
          }
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => true;
}
