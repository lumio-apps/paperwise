import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfrx/pdfrx.dart';

import '../file_actions.dart';
import '../file_store.dart';
import '../library.dart';
import '../theme.dart';
import '../widgets.dart';

enum _ViewerMenu { share, save, otherApp }

/// Reads a PDF inside Paperwise: zoom, jump to a page, thumbnails, and it
/// remembers where you stopped.
class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.path, this.startWithSearch = false});

  final String path;

  /// Opens with the search box ready, for the Search tool.
  final bool startWithSearch;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  final PdfViewerController _controller = PdfViewerController();
  final ReadingLibrary _library = ReadingLibrary.instance;
  // Made only after the viewer has opened the PDF. Creating it earlier fails
  // because the searcher needs the document to exist.
  PdfTextSearcher? _searcher;
  final TextEditingController _query = TextEditingController();
  bool _searchMode = false;
  String _searched = '';

  late final int _startPage;
  late final String _fileName;
  late final bool _canFavorite;

  PdfDocument? _document;
  int _page = 1;
  int _pageCount = 0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _searchMode = widget.startWithSearch;
    _startPage = _library.infoFor(widget.path)?.page ?? 1;
    _page = _startPage;
    _fileName = File(widget.path).uri.pathSegments.last;
    // Only PDFs kept inside Paperwise can be favorites. Others come from a
    // temporary copy that may be cleaned up.
    _canFavorite = FileStore.instance.files.any((f) => f.path == widget.path);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savePosition();
    _searcher?.removeListener(_onSearchChanged);
    _searcher?.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _runSearch() {
    final text = _query.text.trim();
    final searcher = _searcher;
    if (text.isEmpty || searcher == null || !_controller.isReady) return;
    FocusScope.of(context).unfocus();
    setState(() => _searched = text);
    searcher.startTextSearch(text);
  }

  void _closeSearch() {
    _searcher?.resetTextSearch();
    setState(() {
      _searchMode = false;
      _searched = '';
      _query.clear();
    });
  }

  /// A short line about the search: progress, the match you are on, or none found.
  String get _searchStatus {
    if (_searched.isEmpty) return 'Type a word and tap search.';
    final searcher = _searcher;
    if (searcher == null) return 'Opening the PDF…';
    final total = searcher.matches.length;
    if (searcher.isSearching) {
      return total == 0 ? 'Searching…' : 'Searching… $total found so far';
    }
    if (total == 0) {
      return 'No matches. If this PDF is a scan, run Text from scans first.';
    }
    final current = (searcher.currentIndex ?? 0) + 1;
    return 'Match $current of $total';
  }

  void _savePosition() {
    if (_pageCount > 0) _library.setPage(widget.path, _page, _pageCount);
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    // Wait for the current frame so listeners are not told during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _searcher ??= (PdfTextSearcher(controller)..addListener(_onSearchChanged));
        _document = document;
        _pageCount = document.pages.length;
      });
      _library.recordOpened(widget.path, _pageCount);
    });
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _page) return;
    setState(() => _page = pageNumber);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _savePosition);
  }

  Future<String?> _askPassword() async {
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PasswordDialog(),
    );
  }

  Future<void> _jumpToPage() async {
    if (_pageCount <= 0) return;
    final target = await showDialog<int>(
      context: context,
      builder: (context) => _GoToPageDialog(current: _page, pageCount: _pageCount),
    );
    if (target != null && _controller.isReady) {
      await _controller.goToPage(pageNumber: target);
    }
  }

  Future<void> _showThumbnails() async {
    final document = _document;
    if (document == null) return;
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => _ThumbnailSheet(document: document, current: _page),
    );
    if (target != null && _controller.isReady) {
      await _controller.goToPage(pageNumber: target, duration: Duration.zero);
    }
  }

  Future<void> _onMenu(_ViewerMenu action) async {
    switch (action) {
      case _ViewerMenu.share:
        await sharePdfs([widget.path]);
      case _ViewerMenu.save:
        await savePdfToDevice(context, widget.path, _fileName);
      case _ViewerMenu.otherApp:
        final messenger = ScaffoldMessenger.of(context);
        final result = await OpenFilex.open(widget.path, type: 'application/pdf');
        if (result.type != ResultType.done) {
          messenger.showSnackBar(const SnackBar(content: Text('No other PDF app found on this phone.')));
        }
    }
  }

  void _zoom(bool zoomIn) {
    if (!_controller.isReady) return;
    if (zoomIn) {
      _controller.zoomUp();
    } else {
      _controller.zoomDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searcher = _searcher;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _searchMode
                        ? TextField(
                            controller: _query,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _runSearch(),
                            decoration: InputDecoration(
                              hintText: 'Search in this PDF',
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                onPressed: _runSearch,
                                icon: const Icon(Icons.search_rounded),
                              ),
                            ),
                          )
                        : Text(
                            _fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppColors.ink,
                            ),
                          ),
                  ),
                  if (_searchMode)
                    IconButton(
                      tooltip: 'Close search',
                      onPressed: _closeSearch,
                      icon: Icon(Icons.close_rounded, color: AppColors.muted),
                    )
                  else
                    IconButton(
                      tooltip: 'Search in this PDF',
                      onPressed: () => setState(() => _searchMode = true),
                      icon: Icon(Icons.search_rounded, color: AppColors.muted),
                    ),
                  if (_canFavorite && !_searchMode)
                    ListenableBuilder(
                      listenable: _library,
                      builder: (context, _) {
                        final favorite = _library.isFavorite(widget.path);
                        return IconButton(
                          tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                          onPressed: () => _library.toggleFavorite(widget.path),
                          icon: Icon(
                            favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: favorite ? TilePalette.yellow.color : AppColors.muted,
                          ),
                        );
                      },
                    ),
                  PopupMenuButton<_ViewerMenu>(
                    tooltip: 'More options',
                    icon: Icon(Icons.more_vert_rounded, color: AppColors.muted),
                    onSelected: _onMenu,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ViewerMenu.share,
                        child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Share')),
                      ),
                      PopupMenuItem(
                        value: _ViewerMenu.save,
                        child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Save to phone')),
                      ),
                      PopupMenuItem(
                        value: _ViewerMenu.otherApp,
                        child: ListTile(leading: Icon(Icons.open_in_new_rounded), title: Text('Open in another app')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_searchMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _searchStatus,
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous match',
                      onPressed: searcher == null || searcher.matches.isEmpty ? null : searcher.goToPrevMatch,
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      tooltip: 'Next match',
                      onPressed: searcher == null || searcher.matches.isEmpty ? null : searcher.goToNextMatch,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PdfViewer.file(
                widget.path,
                controller: _controller,
                passwordProvider: _askPassword,
                initialPageNumber: _startPage,
                params: PdfViewerParams(
                  backgroundColor: const Color(0xFFE4E1F3),
                  margin: 8,
                  onViewerReady: _onViewerReady,
                  onPageChanged: _onPageChanged,
                  pagePaintCallbacks: [if (searcher != null) searcher.pageTextMatchPaintCallback],
                  viewerOverlayBuilder: (context, size, handleLinkTap) => [
                    PdfViewerScrollThumb(controller: _controller, orientation: ScrollbarOrientation.right),
                  ],
                ),
              ),
            ),
            _BottomBar(
              page: _page,
              pageCount: _pageCount,
              onThumbnails: _document == null ? null : _showThumbnails,
              onJump: _pageCount == 0 ? null : _jumpToPage,
              onZoomOut: () => _zoom(false),
              onZoomIn: () => _zoom(true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnails button, page counter and zoom buttons under the PDF.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.pageCount,
    required this.onThumbnails,
    required this.onJump,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onThumbnails;
  final VoidCallback? onJump;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Page thumbnails',
              onPressed: onThumbnails,
              icon: const Icon(Icons.grid_view_rounded),
              color: Colors.white,
              disabledColor: Colors.white38,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onJump,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    pageCount > 0 ? 'Page $page of $pageCount' : 'Loading…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove_rounded),
              color: Colors.white,
            ),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: onZoomIn,
              icon: const Icon(Icons.add_rounded),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of small page previews. Tapping one closes the sheet with that page number.
class _ThumbnailSheet extends StatelessWidget {
  const _ThumbnailSheet({required this.document, required this.current});

  final PdfDocument document;
  final int current;

  @override
  Widget build(BuildContext context) {
    final count = document.pages.length;
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          final number = index + 1;
          final selected = number == current;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context, number),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.line,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: PdfPageView(
                      document: document,
                      pageNumber: number,
                      maximumDpi: 100,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.accent : AppColors.muted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Asks for a page number and returns it, or null when cancelled.
class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.current, required this.pageCount});

  final int current;
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.current}')
      ..selection = TextSelection(baseOffset: 0, extentOffset: '${widget.current}'.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > widget.pageCount) {
      setState(() => _error = 'Enter a number from 1 to ${widget.pageCount}.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Page number',
          suffixText: 'of ${widget.pageCount}',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Go')),
      ],
    );
  }
}

/// Asks for the password of a locked PDF. Returns null when cancelled.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('This PDF is locked'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _hidden,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Password',
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Open')),
      ],
    );
  }
}
