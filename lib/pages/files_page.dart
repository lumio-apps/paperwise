import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../file_actions.dart';
import '../file_store.dart';
import '../file_tile.dart';
import '../library.dart';
import '../picked_pdf.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// Every PDF made with Paperwise, newest first, plus a way to read any PDF.
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  bool _onlyFavorites = false;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _sortLabel(FileSort sort) => switch (sort) {
        FileSort.newest => 'Newest first',
        FileSort.oldest => 'Oldest first',
        FileSort.nameAZ => 'Name A to Z',
        FileSort.nameZA => 'Name Z to A',
        FileSort.largest => 'Largest first',
        FileSort.smallest => 'Smallest first',
      };

  static List<OutputFile> _sorted(List<OutputFile> files, FileSort sort) {
    final list = [...files];
    int byName(OutputFile a, OutputFile b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (sort) {
      case FileSort.newest:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case FileSort.oldest:
        list.sort((a, b) => a.modified.compareTo(b.modified));
      case FileSort.nameAZ:
        list.sort(byName);
      case FileSort.nameZA:
        list.sort((a, b) => byName(b, a));
      case FileSort.largest:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case FileSort.smallest:
        list.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    }
    return list;
  }

  Future<void> _openFromPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await pickPdfFiles(multiple: false);
      if (picked.isEmpty || !mounted) return;
      await openPdf(context, picked.first.path);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open that file. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([FileStore.instance, ReadingLibrary.instance, AppSettings.instance]),
      builder: (context, _) {
        final all = FileStore.instance.files;
        final sort = AppSettings.instance.fileSort;
        final needle = _query.trim().toLowerCase();
        var files = _onlyFavorites ? all.where((f) => ReadingLibrary.instance.isFavorite(f.path)).toList() : all;
        if (needle.isNotEmpty) files = files.where((f) => f.name.toLowerCase().contains(needle)).toList();
        files = _sorted(files, sort);
        final resume = ReadingLibrary.instance.recent();
        return RefreshIndicator(
          onRefresh: FileStore.instance.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Your files'.tr,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'PDFs made with Paperwise. They stay on this phone.'.tr,
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              if (resume.isNotEmpty) ...[
                _ContinueReadingCard(info: resume.first),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  ChoiceChip(
                    label: Text('All'.tr),
                    selected: !_onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.star_rounded, size: 18),
                    label: Text('Favorites'.tr),
                    selected: _onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = true),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openFromPhone,
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    label: Text('Open a PDF'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (all.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (value) => setState(() => _query = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search your files'.tr,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() {
                                    _search.clear();
                                    _query = '';
                                  }),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<FileSort>(
                      tooltip: 'Sort'.tr,
                      icon: Icon(Icons.sort_rounded, color: AppColors.ink),
                      onSelected: AppSettings.instance.setFileSort,
                      itemBuilder: (context) => [
                        for (final option in FileSort.values)
                          CheckedPopupMenuItem(
                            value: option,
                            checked: option == sort,
                            child: Text(_sortLabel(option).tr),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (files.isEmpty)
                SectionCard(
                  child: needle.isNotEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          palette: TilePalette.slate,
                          title: 'No matching files',
                          message: 'Try another word.',
                        )
                      : _onlyFavorites
                      ? EmptyState(
                          icon: Icons.star_outline_rounded,
                          palette: TilePalette.yellow,
                          title: 'No favorites yet',
                          message: 'Tap the star when you read a PDF, and it will wait for you here.',
                        )
                      : EmptyState(
                          icon: Icons.folder_open_rounded,
                          palette: TilePalette.blue,
                          title: 'No files yet',
                          message: 'Merge, split or turn photos into a PDF, and it will show up here.',
                        ),
                )
              else
                for (final file in files)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FileTile(file: file),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows the PDF you read last, with how far you got.
class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.info});

  final ReadingInfo info;

  @override
  Widget build(BuildContext context) {
    final name = info.path.split(RegExp(r'[\\/]')).last;
    return Material(
      color: TilePalette.blue.tint,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openPdf(context, info.path),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.menu_book_rounded, color: TilePalette.blue.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue reading'.tr,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TilePalette.blue.color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: info.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surface,
                        color: TilePalette.blue.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${info.page} of ${info.pageCount}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
