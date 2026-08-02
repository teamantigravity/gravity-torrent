import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/recent_search_queries_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPrefsStorage.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await (await SharedPreferences.getInstance()).reload();
    RecentSearchQueriesService.instance.reset();
  });

  tearDown(() async {
    SharedPrefsStorage.resetForTest();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    RecentSearchQueriesService.instance.reset();
  });

  group('RecentSearchQueriesService', () {
    test('is empty by default', () {
      expect(RecentSearchQueriesService.instance.queries, isEmpty);
    });

    test('adds queries and moves most recent to front', () async {
      await RecentSearchQueriesService.instance.add('ubuntu');
      await RecentSearchQueriesService.instance.add('arch');
      await RecentSearchQueriesService.instance.add('ubuntu');
      expect(
        RecentSearchQueriesService.instance.queries,
        equals(['ubuntu', 'arch']),
      );
    });

    test('ignores whitespace-only queries', () async {
      await RecentSearchQueriesService.instance.add('   ');
      expect(RecentSearchQueriesService.instance.queries, isEmpty);
    });

    test('removes the oldest entry when max is exceeded', () async {
      for (var i = 1; i <= 9; i++) {
        await RecentSearchQueriesService.instance.add('query $i');
      }
      expect(RecentSearchQueriesService.instance.queries.length, equals(8));
      expect(
        RecentSearchQueriesService.instance.queries,
        equals(List.generate(8, (i) => 'query ${9 - i}')),
      );
    });

    test('persists across instances after load', () async {
      await RecentSearchQueriesService.instance.add('persist');
      RecentSearchQueriesService.instance.reset();
      await RecentSearchQueriesService.instance.load();
      expect(RecentSearchQueriesService.instance.queries, contains('persist'));
    });

    test('remove drops a query', () async {
      await RecentSearchQueriesService.instance.add('keep');
      await RecentSearchQueriesService.instance.add('drop');
      await RecentSearchQueriesService.instance.remove('drop');
      expect(RecentSearchQueriesService.instance.queries, equals(['keep']));
    });

    test('clear removes all queries', () async {
      await RecentSearchQueriesService.instance.add('a');
      await RecentSearchQueriesService.instance.add('b');
      await RecentSearchQueriesService.instance.clear();
      expect(RecentSearchQueriesService.instance.queries, isEmpty);
    });
  });
}
