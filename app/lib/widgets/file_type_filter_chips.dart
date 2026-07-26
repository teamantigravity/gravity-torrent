import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/file_type_filter_service.dart';

class FileTypeFilterChips extends StatelessWidget {
  final FileTypeCategory selected;
  final ValueChanged<FileTypeCategory> onSelected;
  final Map<FileTypeCategory, int>? counts;

  const FileTypeFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  String _label(FileTypeCategory cat, AppLocalizations l) {
    switch (cat) {
      case FileTypeCategory.all:
        return l.fileTypeAll;
      case FileTypeCategory.video:
        return l.fileTypeVideo;
      case FileTypeCategory.audio:
        return l.fileTypeAudio;
      case FileTypeCategory.image:
        return l.fileTypeImage;
      case FileTypeCategory.document:
        return l.fileTypeDocument;
      case FileTypeCategory.archive:
        return l.fileTypeArchive;
      case FileTypeCategory.executable:
        return l.fileTypeExecutable;
      case FileTypeCategory.other:
        return l.fileTypeOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: FileTypeCategory.values.map((cat) {
          final count = counts?[cat];
          final name = _label(cat, l);
          final label = count != null && cat != FileTypeCategory.all
              ? '$name ($count)'
              : name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(FileTypeFilterService.iconFor(cat), size: 18),
              label: Text(label),
              selected: selected == cat,
              onSelected: (_) => onSelected(cat),
            ),
          );
        }).toList(),
      ),
    );
  }
}
