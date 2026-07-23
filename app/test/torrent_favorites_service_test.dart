import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/torrent_favorites_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TorrentFavoritesService.instance.reset();
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    TorrentFavoritesService.instance.reset();
  });

  group('TorrentFavoritesService', () {
    test('is not favorite by default', () {
      expect(TorrentFavoritesService.instance.isFavorite(42), false);
    });

    test('favorites and unfavorites a torrent', () async {
      await TorrentFavoritesService.instance.setFavorite(42, true);
      expect(TorrentFavoritesService.instance.isFavorite(42), true);

      await TorrentFavoritesService.instance.setFavorite(42, false);
      expect(TorrentFavoritesService.instance.isFavorite(42), false);
    });

    test('toggle switches favorite state', () async {
      expect(await TorrentFavoritesService.instance.toggle(1), true);
      expect(TorrentFavoritesService.instance.isFavorite(1), true);

      expect(await TorrentFavoritesService.instance.toggle(1), false);
      expect(TorrentFavoritesService.instance.isFavorite(1), false);
    });

    test('persists across instances after load', () async {
      await TorrentFavoritesService.instance.toggle(7);
      TorrentFavoritesService.instance.reset();
      await TorrentFavoritesService.instance.load();
      expect(TorrentFavoritesService.instance.isFavorite(7), true);
    });

    test('clears all favorites', () async {
      await TorrentFavoritesService.instance.toggle(1);
      await TorrentFavoritesService.instance.toggle(2);
      await TorrentFavoritesService.instance.clear();
      expect(TorrentFavoritesService.instance.isFavorite(1), false);
      expect(TorrentFavoritesService.instance.isFavorite(2), false);
    });
  });
}
