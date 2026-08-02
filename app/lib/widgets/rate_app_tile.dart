import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/in_app_review_service.dart';

/// A settings list-tile that lets the user open the store listing.
class RateAppTile extends StatelessWidget {
  const RateAppTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.star_rate_rounded),
      title: Text(l.rateApp),
      subtitle: Text(l.rateAppSubtitle),
      onTap: () => InAppReviewService.openStoreListing(),
    );
  }
}
