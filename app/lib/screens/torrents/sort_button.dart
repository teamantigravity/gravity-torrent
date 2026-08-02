import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/screens/torrents/dialogs/sort.dart';

class SortButton extends StatelessWidget {
  const SortButton({super.key});

  static void showSortDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return const SortDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).sort,
      onPressed: () => showSortDialog(context),
      icon: const Icon(Icons.sort),
    );
  }
}
