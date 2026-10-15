import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../image_tools.dart';
import '../pdf_editor.dart';
import '../pdf_fonts.dart';
import '../pdf_stamper.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../signature_store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'signature_pad_page.dart';

/// Something placed on a page. [left] and [top] are fractions of the page.
abstract class _Item {
  _Item({required this.page, required this.left, required this.top});

  final int page;
  double left;
  double top;
}

class _TextItem extends _Item {
  _TextItem({
    required super.page,
    required super.left,
    required super.top,
    required this.text,
    required this.font,
    required this.size,
    required this.color,
  });

  String text;
  PdfFont font;
  double size;
  StampColor color;
}

class _SignatureItem extends _Item {
  _SignatureItem({
    required super.page,
    required super.left,
    required super.top,
    required this.data,
  });

  final SignatureData data;

  /// Width as a fraction of the page width.
  double widthFraction = 0.3;
}

/// Add text and a signature to the pages of a PDF, then save a copy.
class PlacePage extends StatefulWidget {
  const PlacePage({super.key, required this.file});

  final PickedPdf file;

  @override
  State<PlacePage> createState() => _PlacePageState();
}

class _PlacePageState extends State<PlacePage> {
  PdfDocument? _document;
  bool _failed = false;
  int _pageIndex = 0;
  Uint8List? _pageImage;
  int _renderToken = 0;

  final List<_Item> _items = [];
  _Item? _selected;
  bool _busy = false;

  int get _pageCount => _document?.pages.length ?? 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _document?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final document = await PdfTools.openDocument(widget.file.path, widget.file.name);
      if (!mounted) {
        await document.dispose();
        return;
      }
      setState(() => _document = document);
      await _renderPage();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
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
      final scale = targetWidth / page.width;
      final width = targetWidth;
      final height = page.height * scale;
      final rendered = await page.render(
        width: width.round(),
        height: height.round(),
        fullWidth: width,
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
      _selected = null;
    });
    _renderPage();
  }

  Future<void> _addText() async {
    final item = await showDialog<_TextItem>(
      context: context,
      builder: (context) => _TextDialog(page: _pageIndex),
    );
    if (item == null || !mounted) return;
    setState(() {
      _items.add(item);
      _selected = item;
    });
  }

  Future<void> _editText(_TextItem item) async {
    final edited = await showDialog<_TextItem>(
      context: context,
      builder: (context) => _TextDialog(page: item.page, initial: item),
    );
    if (edited == null || !mounted) return;
    setState(() {
      item
        ..text = edited.text
        ..font = edited.font
        ..size = edited.size
        ..color = edited.color;
    });
  }

  Future<void> _addSignature() async {
    final saved = await SignatureStore.load();
    if (!mounted) return;
    SignatureData? data;
    if (saved != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Use my saved signature'),
                onTap: () => Navigator.pop(context, 'saved'),
              ),
              ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: const Text('Draw a new one'),
                onTap: () => Navigator.pop(context, 'new'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Forget my saved signature'),
                onTap: () => Navigator.pop(context, 'forget'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == 'forget') {
        await SignatureStore.remove();
        if (mounted) showMessage(context, 'Your saved signature was removed.');
        return;
      }
      if (choice == 'saved') data = saved;
    }
    data ??= await Navigator.of(context).push<SignatureData>(
      MaterialPageRoute(builder: (_) => const SignaturePadPage()),
    );
    if (data == null || !mounted) return;
    final item = _SignatureItem(page: _pageIndex, left: 0.3, top: 0.45, data: data);
    setState(() {
      _items.add(item);
      _selected = item;
    });
  }

  void _resize(double direction) {
    final item = _selected;
    if (item is _TextItem) {
      setState(() => item.size = (item.size + 2 * direction).clamp(6.0, 96.0).toDouble());
    } else if (item is _SignatureItem) {
      setState(() => item.widthFraction = (item.widthFraction + 0.05 * direction).clamp(0.1, 0.9).toDouble());
    }
  }

  void _delete() {
    final item = _selected;
    if (item == null) return;
    setState(() {
      _items.remove(item);
      _selected = null;
    });
  }

  Future<void> _save() async {
    final document = _document;
    if (document == null || _items.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final byPage = <int, List<Stamp>>{};
      for (final item in _items) {
        final page = document.pages[item.page];
        final list = byPage.putIfAbsent(item.page, () => []);
        if (item is _TextItem) {
          list.add(
            TextStamp(
              left: item.left,
              top: item.top,
              text: item.text,
              font: item.font,
              size: item.size,
              color: item.color,
            ),
          );
        } else if (item is _SignatureItem) {
          final widthPt = item.widthFraction * page.width;
          final heightPt = widthPt / item.data.aspect;
          final w = item.widthFraction;
          final h = heightPt / page.height;
          list.add(
            InkStamp(
              strokes: [
                for (final stroke in item.data.strokes)
                  [
                    for (var i = 0; i + 1 < stroke.length; i += 2) ...[
                      item.left + stroke[i] * w,
                      item.top + stroke[i + 1] * h,
                    ],
                  ],
              ],
              width: (widthPt * 0.014).clamp(1.0, 4.0).toDouble(),
              color: const StampColor(0.08, 0.2, 0.62),
            ),
          );
        }
      }
      final bytes = await PdfEditor.apply(document, StampPlan(byPage: byPage));
      final saved = await FileStore.instance.save('${FileStore.cleanName(widget.file.name)}_edited', bytes);
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
    final document = _document;
    final selected = _selected;
    final count = _items.length;
    return ToolPage(
      title: 'Text and signature',
      icon: Icons.draw_outlined,
      palette: TilePalette.yellow,
      body: _failed
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This PDF could not be opened.')))
          : document == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                            onPressed: _pageIndex < _pageCount - 1 ? () => _goTo(_pageIndex + 1) : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildPage(document)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Add text',
                              icon: Icons.text_fields_rounded,
                              onPressed: _busy ? null : _addText,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SecondaryButton(
                              label: 'Signature',
                              icon: Icons.draw_outlined,
                              onPressed: _busy ? null : _addSignature,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: selected == null
                          ? Center(
                              child: Text(
                                'Drag to move. Tap an item to change it.',
                                style: TextStyle(fontSize: 13, color: AppColors.muted),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Smaller',
                                  onPressed: () => _resize(-1),
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Bigger',
                                  onPressed: () => _resize(1),
                                  icon: const Icon(Icons.add_circle_outline_rounded),
                                ),
                                if (selected is _TextItem)
                                  IconButton(
                                    tooltip: 'Change text',
                                    onPressed: () => _editText(selected),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: _delete,
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
      bottom: PrimaryButton(
        label: count == 0 ? 'Save a copy' : 'Save a copy · $count ${count == 1 ? 'item' : 'items'}',
        icon: Icons.check_rounded,
        onPressed: count == 0 ? null : _save,
        busy: _busy,
      ),
    );
  }

  Widget _buildPage(PdfDocument document) {
    final page = document.pages[_pageIndex];
    final image = _pageImage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min((constraints.maxWidth - 24) / page.width, (constraints.maxHeight - 8) / page.height);
        final width = page.width * scale;
        final height = page.height * scale;
        final items = _items.where((i) => i.page == _pageIndex).toList();
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8)],
                      ),
                      child: image == null
                          ? const Center(child: CircularProgressIndicator())
                          : Image.memory(image, fit: BoxFit.fill, gaplessPlayback: true),
                    ),
                  ),
                ),
                for (final item in items) _buildItem(item, width, height, scale),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(_Item item, double width, double height, double scale) {
    final isSelected = identical(item, _selected);
    final Widget child;
    final double boxWidth;
    final double boxHeight;
    if (item is _TextItem) {
      boxWidth = math.max(item.font.width(item.text, item.size) * scale, 8);
      boxHeight = item.size * scale * 1.2;
      child = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          item.text,
          softWrap: false,
          style: TextStyle(
            fontSize: item.size * scale,
            height: 1.2,
            color: Color.from(alpha: 1, red: item.color.red, green: item.color.green, blue: item.color.blue),
            fontWeight: item.font.bold ? FontWeight.w700 : FontWeight.w400,
            fontFamily: item.font.label.startsWith('Serif')
                ? 'serif'
                : (item.font.label.startsWith('Mono') ? 'monospace' : null),
          ),
        ),
      );
    } else {
      final sig = item as _SignatureItem;
      boxWidth = sig.widthFraction * width;
      boxHeight = boxWidth / sig.data.aspect;
      child = CustomPaint(painter: _SignaturePainter(sig.data, boxWidth * 0.014));
    }
    return Positioned(
      left: item.left * width,
      top: item.top * height,
      width: boxWidth,
      height: boxHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = item),
        onPanStart: (_) => setState(() => _selected = item),
        onPanUpdate: (details) {
          setState(() {
            item.left = (item.left + details.delta.dx / width).clamp(0.0, 1.0 - boxWidth / width).toDouble();
            item.top = (item.top + details.delta.dy / height).clamp(0.0, 1.0 - boxHeight / height).toDouble();
          });
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.data, this.penWidth);

  final SignatureData data;
  final double penWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14339F)
      ..strokeWidth = math.max(penWidth, 1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in data.strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0] * size.width, stroke[1] * size.height);
      if (stroke.length == 2) path.lineTo(stroke[0] * size.width + 0.1, stroke[1] * size.height);
      for (var i = 2; i + 1 < stroke.length; i += 2) {
        path.lineTo(stroke[i] * size.width, stroke[i + 1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => oldDelegate.data != data || oldDelegate.penWidth != penWidth;
}

/// Asks for the text, its look and its size.
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.page, this.initial});

  final int page;
  final _TextItem? initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _controller;
  late PdfFont _font;
  late double _size;
  late StampColor _color;

  static const _sizes = <(String, double)>[('Small', 12), ('Medium', 18), ('Large', 28)];
  static const _colors = <(String, StampColor)>[
    ('Black', StampColor.black),
    ('Blue', StampColor.blue1),
    ('Red', StampColor.red1),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _controller = TextEditingController(text: initial?.text ?? '');
    _font = initial?.font ?? PdfFont.sans;
    _size = initial?.size ?? 18;
    _color = initial?.color ?? StampColor.black;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty && PdfFont.canWrite(_controller.text);

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    final bad = text.isNotEmpty && !PdfFont.canWrite(text);
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add text' : 'Change text'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type here',
                errorText: bad ? 'Use letters, numbers and keyboard symbols only.' : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final family in const [PdfFont.sans, PdfFont.serif, PdfFont.mono])
                  ChoiceChip(
                    label: Text(family.label),
                    selected: _font.withBold(false) == family,
                    onSelected: (_) => setState(() => _font = family.withBold(_font.bold)),
                  ),
                FilterChip(
                  label: const Text('Bold'),
                  selected: _font.bold,
                  onSelected: (v) => setState(() => _font = _font.withBold(v)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in _sizes)
                  ChoiceChip(
                    label: Text(option.$1),
                    selected: _size == option.$2,
                    onSelected: (_) => setState(() => _size = option.$2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in _colors)
                  ChoiceChip(
                    label: Text(option.$1),
                    selected: _color == option.$2,
                    onSelected: (_) => setState(() => _color = option.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    _TextItem(
                      page: widget.page,
                      left: widget.initial?.left ?? 0.2,
                      top: widget.initial?.top ?? 0.3,
                      text: _controller.text.trim(),
                      font: _font,
                      size: _size,
                      color: _color,
                    ),
                  )
              : null,
          child: const Text('Done'),
        ),
      ],
    );
  }
}
