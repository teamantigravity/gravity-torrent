import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pretty_bytes/pretty_bytes.dart';
import 'package:gravity_torrent/dialogs/add_torrent.dart';
import 'package:gravity_torrent/dialogs/create_torrent_dialog.dart';
import 'package:gravity_torrent/dialogs/remove_torrent.dart';
import 'package:gravity_torrent/dialogs/remove_torrents.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/file_type_filter_service.dart';
import 'package:gravity_torrent/widgets/file_type_filter_chips.dart';
import 'package:gravity_torrent/utils/permissions.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/screens/torrents/filter_labels_button.dart';
import 'package:gravity_torrent/services/recent_search_queries_service.dart';
import 'package:gravity_torrent/screens/torrents/sheets/torrent_details/torrent_details.dart';
import 'package:gravity_torrent/screens/torrents/sort_button.dart';
import 'package:gravity_torrent/screens/torrents/text_search.dart';
import 'package:gravity_torrent/screens/torrents/torrent_list_tile/torrent_list_tile.dart';
import 'package:gravity_torrent/utils/app_links.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/ad_banner_slot.dart';
import 'package:provider/provider.dart';

enum _MultiSelectAction {
  copyMagnetLinks,
  copyInfoHashes,
  copyTorrentNames,
  share
}

const String assetName = 'assets/undraw_download.svg';
final Widget downloadSvg = SvgPicture.asset(
  assetName,
  semanticsLabel: 'Download',
  height: 164,
);

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class TorrentsScreen extends StatefulWidget {
  const TorrentsScreen({super.key});

  @override
  State<TorrentsScreen> createState() => _TorrentScreen();
}

class _TorrentScreen extends State<TorrentsScreen> {
  final Set<int> _selectedTorrentIds = {};
  bool _isSelectionMode = false;
  final _searchController = TextSearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildActionDivider() {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outline.withAlpha(51),
    );
  }

  void _toggleSelection(int torrentId) {
    setState(() {
      if (_selectedTorrentIds.contains(torrentId)) {
        _selectedTorrentIds.remove(torrentId);
        if (_selectedTorrentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTorrentIds.add(torrentId);
      }
    });
  }

  void _enterSelectionMode(int torrentId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTorrentIds.add(torrentId);
    });
  }

  void _toggleSelectAllVisible(List<int> visibleIds) {
    setState(() {
      if (visibleIds.every(_selectedTorrentIds.contains)) {
        for (final id in visibleIds) {
          _selectedTorrentIds.remove(id);
        }
      } else {
        _selectedTorrentIds.addAll(visibleIds);
      }
      if (_selectedTorrentIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedTorrentIds.clear();
    });
  }

  Future<void> _showAddTorrentDialog() async {
    if (!await checkAndRequestStoragePermissions(context)) return;
    if (!mounted) return;

    AdServiceProvider.instance.showInterstitialIfReady();
    await showDialog(
      context: context,
      builder: (BuildContext context) => const AddTorrentDialog(),
    );
  }

  Future<void> _showCreateTorrentDialog() async {
    if (!await checkAndRequestStoragePermissions(context)) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) => const CreateTorrentDialog(),
    );
  }

  Future<void> _handleRefreshTorrents() async {
    if (!mounted) return;
    await context.read<TorrentsModel>().fetchTorrents();
  }

  void _handleSelectAllVisible() {
    if (!mounted) return;
    final torrentsModel = context.read<TorrentsModel>();
    _toggleSelectAllVisible(
      torrentsModel.displayedTorrents.map((t) => t.id).toList(),
    );
  }

  Future<void> _handleDeleteSelected() async {
    if (!_isSelectionMode || _selectedTorrentIds.isEmpty) return;
    final torrentsModel = context.read<TorrentsModel>();
    final selectedTorrents = torrentsModel.torrents
        .where((t) => _selectedTorrentIds.contains(t.id))
        .toList();
    await _removeSelectedTorrents(selectedTorrents);
  }

  Future<void> _removeSelectedTorrents(List<Torrent> selectedTorrents) async {
    if (selectedTorrents.isEmpty) return;
    if (selectedTorrents.length == 1) {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return RemoveTorrentDialog(torrent: selectedTorrents.first);
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return RemoveTorrentsDialog(torrents: selectedTorrents);
        },
      );
    }
    if (!mounted) return;
    _exitSelectionMode();
  }

  List<MapEntry<TorrentStatus?, String>> _statusFilterOptions(
    AppLocalizations localizations,
    TorrentsModel torrentsModel,
  ) {
    int count(TorrentStatus? status) {
      if (status == null) return torrentsModel.torrents.length;
      return torrentsModel.torrents.where((t) => t.status == status).length;
    }

    return [
      MapEntry(null, '${localizations.allItems} (${count(null)})'),
      MapEntry(
        TorrentStatus.downloading,
        '${localizations.downloading} (${count(TorrentStatus.downloading)})',
      ),
      MapEntry(
        TorrentStatus.seeding,
        '${localizations.seeding} (${count(TorrentStatus.seeding)})',
      ),
      MapEntry(
        TorrentStatus.stopped,
        '${localizations.stopped} (${count(TorrentStatus.stopped)})',
      ),
      MapEntry(
        TorrentStatus.checking,
        '${localizations.checking} (${count(TorrentStatus.checking)})',
      ),
      MapEntry(
          TorrentStatus.queuedToDownload,
          '${localizations.queuedToDownload} '
          '(${count(TorrentStatus.queuedToDownload)})'),
      MapEntry(
          TorrentStatus.queuedToSeed,
          '${localizations.queuedToSeed} '
          '(${count(TorrentStatus.queuedToSeed)})'),
      MapEntry(
          TorrentStatus.queuedToCheck,
          '${localizations.queuedToCheck} '
          '(${count(TorrentStatus.queuedToCheck)})'),
    ];
  }

  Widget _buildTorrentListView(
    TorrentsModel torrentsModel,
    BuildContext context,
  ) {
    final compact = context.watch<AppModel>().compactList;
    final listView = ListView.builder(
      itemCount: torrentsModel.displayedTorrents.length,
      prototypeItem: SizedBox(height: compact ? 56 : 72),
      itemBuilder: (context, index) {
        final Torrent torrent = torrentsModel.displayedTorrents[index];
        final percent = (torrent.progress) * 100;

        if (isMobileSize(context)) {
          // Disable slidable in selection mode
          if (_isSelectionMode) {
            return TorrentListTile(
              torrent: torrent,
              percent: percent,
              compact: compact,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedTorrentIds.contains(torrent.id),
              onLongPress: () => _enterSelectionMode(torrent.id),
              onSelectionChanged: () => _toggleSelection(torrent.id),
            );
          }

          return Slidable(
            key: Key(torrent.id.toString()),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.8,
              children: [
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: (_) => showDeviceSheet(
                    context,
                    torrent.name,
                    TorrentDetailsModalSheet(
                      id: torrent.id,
                      initialTab: 0,
                      showOnlyPlayableFiles: true,
                    ),
                  ),
                  icon: Icons.play_circle_outlined,
                ),
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: (_) => shareLink(context, torrent.magnetLink),
                  icon: Icons.share,
                ),
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: (_) async {
                    final l10n = AppLocalizations.of(context);
                    await Clipboard.setData(
                      ClipboardData(text: torrent.magnetLink),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.magnetLinkCopied),
                          backgroundColor: Colors.lightGreen,
                        ),
                      );
                    }
                  },
                  icon: Icons.copy,
                  label: AppLocalizations.of(context).copyMagnetLink,
                ),
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: torrent.hash == null
                      ? null
                      : (_) async {
                          final l10n = AppLocalizations.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: torrent.hash!),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.hashCopied),
                                backgroundColor: Colors.lightGreen,
                              ),
                            );
                          }
                        },
                  icon: Icons.tag,
                  label: AppLocalizations.of(context).hash,
                ),
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: (_) => torrent.openFolder(context),
                  icon: Icons.folder_outlined,
                ),
                _buildActionDivider(),
                SlidableAction(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                  onPressed: (_) => showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return RemoveTorrentDialog(torrent: torrent);
                    },
                  ),
                  icon: Icons.delete_outline,
                ),
              ],
            ),
            child: TorrentListTile(
              torrent: torrent,
              percent: percent,
              compact: compact,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedTorrentIds.contains(torrent.id),
              onLongPress: () => _enterSelectionMode(torrent.id),
              onSelectionChanged: () => _toggleSelection(torrent.id),
            ),
          );
        }

        // Desktop
        return TorrentListTile(
          torrent: torrent,
          percent: percent,
          compact: compact,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedTorrentIds.contains(torrent.id),
          onLongPress: () => _enterSelectionMode(torrent.id),
          onSelectionChanged: () => _toggleSelection(torrent.id),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () => torrentsModel.fetchTorrents(),
      child: listView,
    );
  }

  Widget _buildStatsHeader(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    if (!app.showLiveSpeedHeader) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _StatChip(
                icon: Icons.arrow_circle_down,
                label: l.download,
                value:
                    '${prettyBytes(model.totalDownloadRate.toDouble(), locale: l.localeName)}/s',
              ),
              _StatChip(
                icon: Icons.arrow_circle_up,
                label: l.upload,
                value:
                    '${prettyBytes(model.totalUploadRate.toDouble(), locale: l.localeName)}/s',
              ),
              _StatChip(
                icon: Icons.download_done,
                label: l.downloaded,
                value: prettyBytes(
                  model.totalDownloadedEver.toDouble(),
                  locale: l.localeName,
                ),
              ),
              _StatChip(
                icon: Icons.upload,
                label: l.uploaded,
                value: prettyBytes(
                  model.totalUploadedEver.toDouble(),
                  locale: l.localeName,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Wrap(
        spacing: 0,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SortButton(),
          const FilterLabelsButton(),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'Create torrent',
            onPressed: _showCreateTorrentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: l.pauseAllTorrents,
            onPressed:
                model.torrents.any((t) => t.status != TorrentStatus.stopped)
                    ? () async => model.pauseAllTorrents()
                    : null,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: l.resumeAllTorrents,
            onPressed:
                model.torrents.any((t) => t.status == TorrentStatus.stopped)
                    ? () async => model.resumeAllTorrents()
                    : null,
          ),
          IconButton(
            icon: Icon(
              model.showFavoritesOnly ? Icons.star : Icons.star_border,
              color: model.showFavoritesOnly ? Colors.amber : null,
            ),
            tooltip: model.showFavoritesOnly
                ? l.showAllTorrents
                : l.showFavoritesOnly,
            onPressed: () async => model.toggleShowFavoritesOnly(),
          ),
          TextSearch(
            controller: _searchController,
            onChange: model.setFilterText,
            onSubmitted: (text) async {
              await RecentSearchQueriesService.instance.add(text);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    final selectedTorrents = model.torrents
        .where((t) => _selectedTorrentIds.contains(t.id))
        .toList();
    final canPause =
        selectedTorrents.any((t) => t.status != TorrentStatus.stopped);
    final canResume =
        selectedTorrents.any((t) => t.status == TorrentStatus.stopped);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _exitSelectionMode,
            tooltip: l.cancel,
          ),
          Checkbox(
            value: model.displayedTorrents.isNotEmpty &&
                model.displayedTorrents.every(
                  (t) => _selectedTorrentIds.contains(t.id),
                ),
            onChanged: model.displayedTorrents.isEmpty
                ? null
                : (_) => _toggleSelectAllVisible(
                      model.displayedTorrents.map((t) => t.id).toList(),
                    ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedTorrentIds.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: l.pause,
            onPressed: canPause
                ? () async => model.pauseSelected(_selectedTorrentIds)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: l.resume,
            onPressed: canResume
                ? () async => model.resumeSelected(_selectedTorrentIds)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _selectedTorrentIds.isEmpty
                ? null
                : () async => _removeSelectedTorrents(selectedTorrents),
            tooltip: l.remove,
          ),
          PopupMenuButton<_MultiSelectAction>(
            enabled: _selectedTorrentIds.isNotEmpty,
            icon: const Icon(Icons.more_vert),
            onSelected: (action) async {
              if (action == _MultiSelectAction.share) {
                if (mounted) {
                  await shareLinks(
                    context,
                    selectedTorrents.map((t) => t.magnetLink).toList(),
                  );
                }
                return;
              }
              if (!mounted) return;
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final text = switch (action) {
                _MultiSelectAction.copyMagnetLinks =>
                  selectedTorrents.map((t) => t.magnetLink).join('\n'),
                _MultiSelectAction.copyInfoHashes =>
                  selectedTorrents.map((t) => t.hash ?? '-').join('\n'),
                _MultiSelectAction.copyTorrentNames =>
                  selectedTorrents.map((t) => t.name).join('\n'),
                _MultiSelectAction.share => '',
              };
              await Clipboard.setData(ClipboardData(text: text));
              if (!scaffoldMessenger.mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(l.copiedToClipboard),
                  backgroundColor: Colors.lightGreen,
                ),
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MultiSelectAction.copyMagnetLinks,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.copy),
                  title: Text(l.copyMagnetLinks),
                ),
              ),
              PopupMenuItem(
                value: _MultiSelectAction.copyInfoHashes,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.tag),
                  title: Text(l.copyInfoHashes),
                ),
              ),
              PopupMenuItem(
                value: _MultiSelectAction.copyTorrentNames,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.text_snippet),
                  title: Text(l.copyTorrentNames),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _MultiSelectAction.share,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.share),
                  title: Text(l.shareSelectedTorrents),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    if (!app.showStatusFilterChips) return const SizedBox.shrink();
    final options = _statusFilterOptions(l, model);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TorrentStatus?>(
                isExpanded: true,
                value: model.statusFilter,
                icon: const Icon(Icons.filter_list),
                items: options
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (status) => model.setStatusFilter(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTypeFilterChips(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    if (model.torrents.isEmpty) return const SizedBox.shrink();
    return FileTypeFilterChips(
      selected: model.fileTypeFilter,
      onSelected: model.setFileTypeFilter,
      counts: FileTypeFilterService.getCategoryCounts(
        model.torrents,
        getFiles: (t) => t.files,
      ),
    );
  }

  Widget _buildRecentQueries(
    BuildContext context,
    AppModel app,
    TorrentsModel model,
    AppLocalizations l,
  ) {
    final queries = RecentSearchQueriesService.instance.queries;
    if (!app.showRecentSearchQueries ||
        model.filterText.isNotEmpty ||
        queries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...queries.map(
              (query) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    query,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => model.setFilterText(query),
                ),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.clear_all, size: 18),
              label: Text(l.clearRecentSearches),
              onPressed: () async {
                await RecentSearchQueriesService.instance.clear();
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          _showAddTorrentDialog();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          _showAddTorrentDialog();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          _handleRefreshTorrents();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          _handleRefreshTorrents();
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          _handleSelectAllVisible();
        },
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () {
          _handleSelectAllVisible();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchController.expand();
          _searchController.focus();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          _searchController.expand();
          _searchController.focus();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            SortButton.showSortDialog(context),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            SortButton.showSortDialog(context),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
          if (context.mounted) context.go('/settings');
        },
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () {
          if (context.mounted) context.go('/settings');
        },
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchController.clear();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchController.clear();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSelectionMode) _exitSelectionMode();
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          _handleDeleteSelected();
        },
      },
      child: Consumer<TorrentsModel>(
        builder: (context, torrentsModel, child) {
          final app = context.watch<AppModel>();
          if (torrentsModel.hasLoaded && torrentsModel.torrents.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        downloadSvg,
                        const SizedBox(height: 16),
                        Text(
                          localizations.noDownloadsYet,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddTorrentDialog,
                          icon: const Icon(Icons.add),
                          label: Text(localizations.addTorrentTitle),
                        ),
                      ],
                    ),
                  ),
                ),
                const AdBannerSlot(),
              ],
            );
          }

          return Column(
            children: [
              if (_isSelectionMode)
                _buildSelectionBar(
                  context,
                  app,
                  torrentsModel,
                  localizations,
                )
              else
                _buildActionBar(
                  context,
                  app,
                  torrentsModel,
                  localizations,
                ),
              _buildStatsHeader(
                context,
                app,
                torrentsModel,
                localizations,
              ),
              _buildStatusFilter(
                context,
                app,
                torrentsModel,
                localizations,
              ),
              _buildFileTypeFilterChips(
                context,
                app,
                torrentsModel,
                localizations,
              ),
              if (app.showVisibleTorrentCount ||
                  torrentsModel.filterText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    localizations.showingTorrents(
                      torrentsModel.displayedTorrents.length,
                      torrentsModel.torrents.length,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              _buildRecentQueries(
                context,
                app,
                torrentsModel,
                localizations,
              ),
              Expanded(
                child: _buildTorrentListView(torrentsModel, context),
              ),
              const AdBannerSlot(),
            ],
          );
        },
      ),
    );
  }
}
