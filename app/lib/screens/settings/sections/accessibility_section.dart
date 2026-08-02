import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/accessibility_service.dart';
import 'package:provider/provider.dart';

class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Consumer<AccessibilityService>(
      builder: (context, a11y, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l.accessibility,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.contrast),
              title: Text(l.highContrastMode),
              subtitle: Text(l.highContrastModeSubtitle),
              value: a11y.highContrast,
              onChanged: a11y.setHighContrast,
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.animation),
              title: Text(l.reducedMotion),
              subtitle: Text(l.reducedMotionSubtitle),
              value: a11y.reducedMotion,
              onChanged: a11y.setReducedMotion,
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.text_increase),
              title: Text(l.largeText),
              subtitle: Text(l.largeTextSubtitle),
              value: a11y.largeText,
              onChanged: a11y.setLargeText,
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.format_bold),
              title: Text(l.boldText),
              subtitle: Text(l.boldTextSubtitle),
              value: a11y.boldText,
              onChanged: a11y.setBoldText,
            ),
          ],
        );
      },
    );
  }
}
