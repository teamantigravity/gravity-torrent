import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/accessibility_service.dart';
import 'package:gravity_torrent/services/onboarding_service.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _totalPages = 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextWithAccessibility(bool reducedMotion) {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: reducedMotion ? Curves.linear : Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    await OnboardingService.markComplete();
    if (mounted) context.go('/torrents');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityService>();
    final reducedMotion = a11y.reducedMotion;

    final pages = <_OnboardingPage>[
      _OnboardingPage(
        icon: Icons.downloading_rounded,
        title: l.onboardingWelcomeTitle,
        body: l.onboardingWelcomeBody,
      ),
      _OnboardingPage(
        icon: Icons.add_link_rounded,
        title: l.onboardingAddTorrentTitle,
        body: l.onboardingAddTorrentBody,
      ),
      _OnboardingPage(
        icon: Icons.filter_list_rounded,
        title: l.onboardingFiltersTitle,
        body: l.onboardingFiltersBody,
      ),
      _OnboardingPage(
        icon: Icons.play_circle_outline_rounded,
        title: l.onboardingPlayerTitle,
        body: l.onboardingPlayerBody,
      ),
      _OnboardingPage(
        icon: Icons.lock_outline_rounded,
        title: l.onboardingPrivacyTitle,
        body: l.onboardingPrivacyBody,
      ),
      _OnboardingPage(
        icon: Icons.gavel_rounded,
        title: l.onboardingLegalTitle,
        body: l.onboardingLegalBody,
        isLegal: true,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            if (_currentPage != _totalPages - 1)
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(onPressed: _skip, child: Text(l.skip)),
                ),
              ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _totalPages,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final p = pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            p.icon,
                            size: 96,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 32),
                          Text(
                            p.title,
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.body,
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (p.isLegal) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l.onboardingLegalDisclaimer,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Dots + Next/Finish
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                children: [
                  // Page indicators
                  Expanded(
                    child: Row(
                      children: List.generate(
                        _totalPages,
                        (i) => AnimatedContainer(
                          duration: reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withAlpha(89),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => _nextWithAccessibility(reducedMotion),
                    child: Text(
                      _currentPage == _totalPages - 1
                          ? l.onboardingGetStarted
                          : l.next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final bool isLegal;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.isLegal = false,
  });
}
