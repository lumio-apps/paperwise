import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../office/office_file.dart';
import '../office/sheet_reader.dart';
import '../office/zip_reader.dart';
import '../theme.dart';
import '../widgets.dart';

/// Picks an Excel or CSV file and opens it in [SheetViewerPage].
Future<void> openSheetFromPicker(BuildContext context) async {
  final path = await pickOfficeFile(context, const ['xlsx', 'csv', 'tsv']);
  if (path == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SheetViewerPage(path: path)));
}

/// Shows an Excel (.xlsx) or CSV file as a table, one tab per sheet. View only.
class SheetViewerPage extends StatefulWidget {
  const SheetViewerPage({super.key, required this.path});

  final String path;

  @override
  State<SheetViewerPage> createState() => _SheetViewerPageState();
}

class _SheetViewerPageState extends State<SheetViewerPage> {
  late final Future<WorkbookData> _book = readSheetFile(widget.path);
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            OfficeViewerHeader(path: widget.path),
            Expanded(
              child: FutureBuilder<WorkbookData>(
                future: _book,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _Opening();
                  }
                  final book = snapshot.data;
                  if (book == null) {
                    final error = snapshot.error;
                    return Center(
                      child: SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.table_chart_outlined,
                          palette: TilePalette.orange,
                          title: 'Could not open this file',
                          message: error is OfficeFileException
                              ? error.message
                              : 'This file could not be read. It may be damaged.',
                        ),
                      ),
                    );
                  }
                  final index = _selected < book.sheets.length ? _selected : 0;
                  final sheet = book.sheets[index];
                  return Column(
                    children: [
                      _SheetSummary(sheet: sheet),
                      Expanded(
                        child: sheet.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  child: EmptyState(
                                    icon: Icons.grid_off_rounded,
                                    palette: TilePalette.slate,
                                    title: 'Nothing to show',
                                    message: sheet.note ?? 'This sheet is empty.',
                                  ),
                                ),
                              )
                            : _SheetGrid(key: ValueKey(index), sheet: sheet),
                      ),
                      if (book.sheets.length > 1)
                        _SheetTabs(
                          names: [for (final s in book.sheets) s.name],
                          selected: index,
                          onSelect: (i) => setState(() => _selected = i),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 16),
          Text('Opening the file…', style: TextStyle(fontSize: 15, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Size of the sheet, and a note when it was cut short.
class _SheetSummary extends StatelessWidget {
  const _SheetSummary({required this.sheet});

  final SheetData sheet;

  @override
  Widget build(BuildContext context) {
    final note = sheet.note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!sheet.isEmpty)
            Text(
              '${sheet.rows.length} ${sheet.rows.length == 1 ? 'row' : 'rows'} · '
              '${sheet.columnCount} ${sheet.columnCount == 1 ? 'column' : 'columns'} · Tap a cell to see all of it',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          if (note != null && !sheet.isEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note, style: TextStyle(fontSize: 13, color: AppColors.ink))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The table: column letters stay at the top and row numbers stay at the left.
class _SheetGrid extends StatefulWidget {
  const _SheetGrid({super.key, required this.sheet});

  final SheetData sheet;

  @override
  State<_SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends State<_SheetGrid> {
  static const double _rowHeight = 36;
  static const double _headerHeight = 32;
  static final RegExp _numberLike = RegExp(r'^[-+(]?[$€£₹¥֏]?\s?[\d][\d.,\s]*%?\)?$');

  final _bodyVertical = ScrollController();
  final _numbersVertical = ScrollController();
  final _bodyHorizontal = ScrollController();
  final _headerHorizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyVertical.addListener(() {
      if (_numbersVertical.hasClients) _numbersVertical.jumpTo(_bodyVertical.offset);
    });
    _bodyHorizontal.addListener(() {
      if (_headerHorizontal.hasClients) _headerHorizontal.jumpTo(_bodyHorizontal.offset);
    });
  }

  @override
  void dispose() {
    _bodyVertical.dispose();
    _numbersVertical.dispose();
    _bodyHorizontal.dispose();
    _headerHorizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final widths = sheet.columnWidths;
    final totalWidth = widths.fold<double>(0, (sum, w) => sum + w);
    final numberWidth = (sheet.rows.length.toString().length * 9.0 + 22).clamp(40.0, 90.0).toDouble();
    final line = BorderSide(color: AppColors.line);
    final headerStyle = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                Container(
                  width: numberWidth,
                  decoration: BoxDecoration(color: AppColors.track, border: Border(right: line, bottom: line)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerHorizontal,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        for (var c = 0; c < sheet.columnCount; c++)
                          Container(
                            width: widths[c],
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.track, border: Border(right: line, bottom: line)),
                            child: Text(columnName(c), style: headerStyle),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: numberWidth,
                  child: ListView.builder(
                    controller: _numbersVertical,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemExtent: _rowHeight,
                    itemCount: sheet.rows.length,
                    itemBuilder: (context, r) => Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.track, border: Border(right: line, bottom: line)),
                      child: Text('${r + 1}', style: headerStyle),
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _bodyHorizontal,
                    child: SingleChildScrollView(
                      controller: _bodyHorizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: totalWidth,
                        child: ListView.builder(
                          controller: _bodyVertical,
                          padding: EdgeInsets.zero,
                          itemExtent: _rowHeight,
                          itemCount: sheet.rows.length,
                          itemBuilder: (context, r) => _row(r, line),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(int r, BorderSide line) {
    final sheet = widget.sheet;
    final cells = sheet.rows[r];
    final style = TextStyle(fontSize: 13.5, color: AppColors.ink);
    return Row(
      children: [
        for (var c = 0; c < sheet.columnCount; c++)
          _cell(r, c, c < cells.length ? cells[c] : '', line, style),
      ],
    );
  }

  Widget _cell(int r, int c, String value, BorderSide line, TextStyle style) {
    final box = Container(
      width: widget.sheet.columnWidths[c],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: _numberLike.hasMatch(value) ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(right: line, bottom: line)),
      child: value.isEmpty
          ? null
          : Text(value.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
    if (value.isEmpty) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showCell(r, c, value),
      child: box,
    );
  }

  void _showCell(int r, int c, String value) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cell ${columnName(c)}${r + 1}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.45),
                child: SingleChildScrollView(
                  child: SelectableText(value, style: TextStyle(fontSize: 17, height: 1.4, color: AppColors.ink)),
                ),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  Navigator.of(sheetContext).pop();
                  showMessage(context, 'Copied.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet names at the bottom, like the tabs in Excel.
class _SheetTabs extends StatelessWidget {
  const _SheetTabs({required this.names, required this.selected, required this.onSelect});

  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        itemCount: names.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chosen = i == selected;
          return Material(
            color: chosen ? AppColors.track : AppColors.surface,
            shape: StadiumBorder(side: BorderSide(color: chosen ? AppColors.accent : AppColors.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    names[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: chosen ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
