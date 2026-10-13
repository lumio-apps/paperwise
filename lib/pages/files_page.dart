import 'package:flutter/material.dart';

import '../file_store.dart';
import '../file_tile.dart';
import '../theme.dart';
import '../widgets.dart';

/// Every PDF made with Paperwise, newest first.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FileStore.instance,
      builder: (context, _) {
        final files = FileStore.instance.files;
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
              const SizedBox(height: 18),
              if (files.isEmpty)
                const SectionCard(
                  child: EmptyState(
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
