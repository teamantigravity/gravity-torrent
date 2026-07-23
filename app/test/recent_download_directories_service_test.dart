import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/recent_download_directories_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    RecentDownloadDirectoriesService.instance.reset();
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    RecentDownloadDirectoriesService.instance.reset();
  });

  group('RecentDownloadDirectoriesService', () {
    test('is empty by default', () {
      expect(RecentDownloadDirectoriesService.instance.directories, isEmpty);
    });

    test('adds directories and moves most recent to front', () async {
      await RecentDownloadDirectoriesService.instance.add('/a');
      await RecentDownloadDirectoriesService.instance.add('/b');
      await RecentDownloadDirectoriesService.instance.add('/a');
      expect(RecentDownloadDirectoriesService.instance.directories,
          equals(['/a', '/b']));
    });

    test('removes the oldest entry when max is exceeded', () async {
      await RecentDownloadDirectoriesService.instance.add('/1');
      await RecentDownloadDirectoriesService.instance.add('/2');
      await RecentDownloadDirectoriesService.instance.add('/3');
      await RecentDownloadDirectoriesService.instance.add('/4');
      await RecentDownloadDirectoriesService.instance.add('/5');
      await RecentDownloadDirectoriesService.instance.add('/6');
      expect(RecentDownloadDirectoriesService.instance.directories,
          equals(['/6', '/5', '/4', '/3', '/2']));
    });

    test('persists across instances after load', () async {
      await RecentDownloadDirectoriesService.instance.add('/persist');
      RecentDownloadDirectoriesService.instance.reset();
      await RecentDownloadDirectoriesService.instance.load();
      expect(RecentDownloadDirectoriesService.instance.directories,
          contains('/persist'));
    });

    test('remove drops a directory', () async {
      await RecentDownloadDirectoriesService.instance.add('/keep');
      await RecentDownloadDirectoriesService.instance.add('/drop');
      await RecentDownloadDirectoriesService.instance.remove('/drop');
      expect(RecentDownloadDirectoriesService.instance.directories,
          equals(['/keep']));
    });

    test('clear removes all directories', () async {
      await RecentDownloadDirectoriesService.instance.add('/a');
      await RecentDownloadDirectoriesService.instance.add('/b');
      await RecentDownloadDirectoriesService.instance.clear();
      expect(RecentDownloadDirectoriesService.instance.directories, isEmpty);
    });
  });
}
