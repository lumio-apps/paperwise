import 'package:flutter/material.dart';

import '../file_actions.dart';
import '../file_store.dart';
import '../file_tile.dart';
import '../library.dart';
import '../picked_pdf.dart';
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
      listenable: Listenable.merge([FileStore.instance, ReadingLibrary.instance]),
      builder: (context, _) {
        final all = FileStore.instance.files;
        final files = _onlyFavorites ? all.where((f) => ReadingLibrary.instance.isFavorite(f.path)).toList() : all;
        final resume = ReadingLibrary.instance.recent();
        return RefreshIndicator(
          onRefresh: FileStore.instance.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text(
                'Your files',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'PDFs made with Paperwise. They stay on this phone.',
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
                    label: const Text('All'),
                    selected: !_onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Favorites'),
                    selected: _onlyFavorites,
                    onSelected: (_) => setState(() => _onlyFavorites = true),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openFromPhone,
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    label: const Text('Open a PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (files.isEmpty)
                SectionCard(
                  child: _onlyFavorites
                      ? const EmptyState(
                          icon: Icons.star_outline_rounded,
                          palette: TilePalette.yellow,
                          title: 'No favorites yet',
                          message: 'Tap the star when you read a PDF, and it will wait for you here.',
                        )
                      : const EmptyState(
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
                      'Continue reading',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TilePalette.blue.color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
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
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
