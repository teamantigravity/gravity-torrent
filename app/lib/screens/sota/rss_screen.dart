import 'package:flutter/material.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class RssScreen extends StatefulWidget {
  const RssScreen({super.key});

  @override
  State<RssScreen> createState() => _RssScreenState();
}

class _RssScreenState extends State<RssScreen> {
  bool _loaded = false;
  List<RssFeed> _feeds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await RssService.instance.load();
    if (mounted) {
      setState(() {
        _feeds = List.from(RssService.instance.feeds);
        _loaded = true;
      });
    }
  }

  void _showAddDialog() {
    final urlController = TextEditingController();
    final keywordController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addRssFeed),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Feed URL',
                hintText: 'https://example.com/feed.rss',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.rss_feed),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(
                labelText: 'Keyword filter (optional)',
                hintText: 'e.g. "1080p" — leave blank for all',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              final uri = Uri.tryParse(url);
              if (uri == null ||
                  !uri.hasAbsolutePath ||
                  (!url.startsWith('http://') && !url.startsWith('https://'))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid HTTP/HTTPS URL')),
                );
                return;
              }
              final feed = RssFeed(
                url: url,
                keyword: keywordController.text.trim(),
              );
              await RssService.instance.addFeed(feed);
              if (ctx.mounted) Navigator.of(ctx).pop();
              await _load();
            },
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }

  Future<void> _pollNow() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Polling RSS feeds…')));
    await RssService.instance.pollNow();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Poll complete')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(
              title: const Text('RSS auto-download'),
              actions: [
                if (_loaded)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Poll now',
                    onPressed: _pollNow,
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Add RSS feed',
        child: const Icon(Icons.add),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RSS auto-download',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add RSS feed URLs and an optional keyword filter. '
                        'Matching magnet links and .torrent files are '
                        'automatically added every 30 minutes.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _feeds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rss_feed,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No feeds yet',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap the + button to add your first RSS feed.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _feeds.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final feed = _feeds[index];
                            return Dismissible(
                              key: Key(feed.url),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Theme.of(context).colorScheme.error,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) async {
                                if (index >= 0 && index < _feeds.length) {
                                  await RssService.instance.removeFeedAt(index);
                                }
                                await _load();
                              },
                              child: SwitchListTile(
                                secondary: const Icon(Icons.rss_feed),
                                title: Text(
                                  feed.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: feed.keyword.isNotEmpty
                                    ? Text('Filter: "${feed.keyword}"')
                                    : Text(
                                        AppLocalizations.of(context)!.allItems),
                                value: feed.enabled,
                                onChanged: (v) async {
                                  await RssService.instance.updateFeedAt(
                                    index,
                                    RssFeed(
                                      url: feed.url,
                                      keyword: feed.keyword,
                                      enabled: v,
                                    ),
                                  );
                                  await _load();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
