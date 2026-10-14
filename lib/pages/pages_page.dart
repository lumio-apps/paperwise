import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_store.dart';
import '../format.dart';
import '../pdf_tools.dart';
import '../picked_pdf.dart';
import '../result_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

/// One page on the grid. [id] stays the same while the page moves around.
class _PageItem {
  _PageItem(this.id, this.source);

  final int id;

  /// Index in the original PDF, starting at 0.
  final int source;

  /// Extra clockwise quarter turns added by the user.
  int turns = 0;
  bool selected = false;
}

/// Reorder, rotate, delete and extract pages of one PDF on a visual grid.
class PagesPage extends StatefulWidget {
  const PagesPage({super.key});

  @override
  State<PagesPage> createState() => _PagesPageState();
}

class _PagesPageState extends State<PagesPage> {
  PickedPdf? _file;
  PdfDocument? _document;
  List<_PageItem> _items = [];
  bool _loading = false;
  bool _busy = false;

  @override
  void dispose() {
    _document?.dispose();
    super.dispose();
  }

  List<_PageItem> get _selected => [for (final item in _items) if (item.selected) item];

  /// True when the pages differ from the original PDF.
  bool get _changed {
    final doc = _document;
    if (doc == null) return false;
    if (_items.length != doc.pages.length) return true;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].source != i || _items[i].turns != 0) return true;
    }
    return false;
  }

  List<_PageItem> _originalItems(PdfDocument doc) => [
        for (var i = 0; i < doc.pages.length; i++) _PageItem(i, i),
      ];

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

    setState(() => _loading = true);
    try {
      final doc = await PdfTools.openDocument(file.path, file.name);
      if (!mounted) {
        await doc.dispose();
        return;
      }
      final old = _document;
      setState(() {
        _document = doc;
        _file = file;
        _items = _originalItems(doc);
        _loading = false;
      });
      await old?.dispose();
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('This PDF could not be opened.');
    }
  }

  void _failed(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _busy = false;
    });
    showMessage(context, message);
  }

  void _toggle(_PageItem item) => setState(() => item.selected = !item.selected);

  void _selectAll(bool value) => setState(() {
        for (final item in _items) {
          item.selected = value;
        }
      });

  void _rotateSelected(int turns) => setState(() {
        for (final item in _items) {
          if (item.selected) item.turns = (item.turns + turns) & 3;
        }
      });

  void _deleteSelected() {
    final selected = _selected;
    if (selected.isEmpty) return;
    if (selected.length == _items.length) {
      showMessage(context, 'A PDF needs at least one page. Keep one page.');
      return;
    }
    setState(() => _items = [for (final item in _items) if (!item.selected) item]);
  }

  /// Moves the selected pages one step earlier (-1) or later (+1).
  void _moveSelected(int direction) {
    setState(() {
      final list = _items;
      if (direction < 0) {
        for (var i = 1; i < list.length; i++) {
          if (list[i].selected && !list[i - 1].selected) {
            final tmp = list[i - 1];
            list[i - 1] = list[i];
            list[i] = tmp;
          }
        }
      } else {
        for (var i = list.length - 2; i >= 0; i--) {
          if (list[i].selected && !list[i + 1].selected) {
            final tmp = list[i + 1];
            list[i + 1] = list[i];
            list[i] = tmp;
          }
        }
      }
    });
  }

  void _moveTo(int from, int to) {
    if (from == to || from < 0 || from >= _items.length || to < 0 || to >= _items.length) return;
    setState(() {
      final item = _items.removeAt(from);
      _items.insert(to, item);
    });
  }

  void _reset() {
    final doc = _document;
    if (doc == null) return;
    setState(() => _items = _originalItems(doc));
  }

  Future<void> _save(List<_PageItem> pages, String suffix) async {
    final doc = _document;
    final file = _file;
    if (doc == null || file == null || pages.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await PdfTools.arrange(doc, [for (final p in pages) PageEdit(p.source, turns: p.turns)]);
      final saved = await FileStore.instance.save('${FileStore.cleanName(file.name)}_$suffix', bytes);
      await FileStore.instance.load();
      if (!mounted) return;
      setState(() => _busy = false);
      await showResultSheet(context, [saved]);
    } on PdfToolException catch (e) {
      _failed(e.message);
    } catch (_) {
      _failed('Could not save the PDF. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    final doc = _document;

    return ToolPage(
      title: 'Page tools',
      icon: Icons.view_module_outlined,
      palette: TilePalette.slate,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (file == null || doc == null)
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    SectionCard(
                      child: EmptyState(
                        icon: Icons.view_module_outlined,
                        palette: TilePalette.slate,
                        title: 'Choose a PDF',
                        message: 'Reorder, rotate, delete or extract pages. Everything happens on your phone.',
                        action: PrimaryButton(label: 'Choose PDF', icon: Icons.add_rounded, onPressed: _chooseFile),
                      ),
                    ),
                  ],
                )
              : _buildGrid(file, doc),
      bottom: (file == null || doc == null || _loading) ? null : _buildBottom(),
    );
  }

  Widget _buildGrid(PickedPdf file, PdfDocument doc) {
    final columns = MediaQuery.sizeOf(context).width >= 600 ? 5 : 3;
    final selectedCount = _selected.length;
    final allSelected = _items.isNotEmpty && selectedCount == _items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              TextButton(onPressed: _busy ? null : _chooseFile, child: const Text('Change')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedCount == 0
                      ? '${pageCountLabel(_items.length)} · tap to select, hold and drag to move'
                      : '${pageCountLabel(_items.length)} · $selectedCount selected',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              TextButton(
                onPressed: () => _selectAll(!allSelected),
                child: Text(allSelected ? 'Clear' : 'Select all'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return DragTarget<int>(
                key: ValueKey(item.id),
                onWillAcceptWithDetails: (details) => details.data != index,
                onAcceptWithDetails: (details) => _moveTo(details.data, index),
                builder: (context, candidates, rejected) {
                  final card = _PageCard(
                    document: doc,
                    item: item,
                    number: index + 1,
                    highlight: candidates.isNotEmpty,
                    onTap: _busy ? null : () => _toggle(item),
                  );
                  return LongPressDraggable<int>(
                    data: index,
                    maxSimultaneousDrags: _busy ? 0 : 1,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 104,
                        height: 150,
                        child: Opacity(
                          opacity: 0.92,
                          child: _PageCard(document: doc, item: item, number: index + 1, compact: true),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: card),
                    child: card,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottom() {
    final selected = _selected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ToolAction(icon: Icons.arrow_back_rounded, label: 'Earlier', onTap: _busy ? null : () => _moveSelected(-1)),
              _ToolAction(icon: Icons.arrow_forward_rounded, label: 'Later', onTap: _busy ? null : () => _moveSelected(1)),
              _ToolAction(icon: Icons.rotate_left_rounded, label: 'Left', onTap: _busy ? null : () => _rotateSelected(3)),
              _ToolAction(icon: Icons.rotate_right_rounded, label: 'Right', onTap: _busy ? null : () => _rotateSelected(1)),
              _ToolAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppColors.danger,
                onTap: _busy ? null : _deleteSelected,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Extract ${pageCountLabel(selected.length)}',
            icon: Icons.content_cut_rounded,
            onPressed: _busy ? null : () => _save(selected, 'extract'),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            if (_changed) ...[
              TextButton(onPressed: _busy ? null : _reset, child: const Text('Reset')),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: PrimaryButton(
                label: 'Save PDF',
                icon: Icons.check_rounded,
                busy: _busy,
                onPressed: _changed ? () => _save(_items, 'edited') : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A round icon with a small label, used in the action row.
class _ToolAction extends StatelessWidget {
  const _ToolAction({required this.icon, required this.label, required this.onTap, this.color = AppColors.ink});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: onTap == null ? AppColors.muted : color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

/// A page preview with its number and a selection mark.
class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.document,
    required this.item,
    required this.number,
    this.onTap,
    this.highlight = false,
    this.compact = false,
  });

  final PdfDocument document;
  final _PageItem item;
  final int number;
  final VoidCallback? onTap;
  final bool highlight;

  /// Used while dragging: no selection mark, just the page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final page = document.pages[item.source];
    final rotation = PdfPageRotation.values[(page.rotation.index + item.turns) & 3];
    final borderColor = highlight
        ? TilePalette.orange.color
        : item.selected
            ? AppColors.accent
            : AppColors.line;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: item.selected || highlight ? 3 : 1),
                    ),
                    child: PdfPageView(
                      document: document,
                      pageNumber: item.source + 1,
                      rotationOverride: rotation,
                      maximumDpi: 100,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                if (!compact)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Icon(
                      item.selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 24,
                      color: item.selected ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                if (!compact && item.turns != 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Icon(Icons.screen_rotation_alt_rounded, size: 18, color: TilePalette.orange.color),
                  ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              '$number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: item.selected ? FontWeight.w800 : FontWeight.w600,
                color: item.selected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
