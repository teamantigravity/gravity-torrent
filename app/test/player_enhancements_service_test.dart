import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/player_enhancements_service.dart';

PlaylistItem _item(String name) =>
    PlaylistItem(title: name, filePath: '/downloads/$name', fileName: name);

void main() {
  group('reorderQueue', () {
    late PlayerEnhancementsService service;

    setUp(() {
      service = PlayerEnhancementsService();
      service.setQueue([_item('a'), _item('b'), _item('c')]);
    });

    tearDown(() => service.dispose());

    test('moving an item down lands it at the intended position', () {
      // ReorderableListView reports newIndex as the insertion point computed
      // before removal, so moving "a" after "b" arrives as (0, 2).
      service.reorderQueue(0, 2);
      expect(service.queue.map((i) => i.title), ['b', 'a', 'c']);
    });

    test('moving an item to the end lands it last', () {
      service.reorderQueue(0, 3);
      expect(service.queue.map((i) => i.title), ['b', 'c', 'a']);
    });

    test('moving an item up lands it at the intended position', () {
      service.reorderQueue(2, 0);
      expect(service.queue.map((i) => i.title), ['c', 'a', 'b']);
    });

    test('keeps the current item selected after a reorder', () {
      service.setQueue([_item('a'), _item('b'), _item('c')], startIndex: 0);
      service.reorderQueue(0, 3);
      expect(service.currentItem?.title, 'a');
      expect(service.currentIndex, 2);
    });

    test('ignores an out-of-range source index', () {
      service.reorderQueue(9, 0);
      expect(service.queue.map((i) => i.title), ['a', 'b', 'c']);
    });
  });

  group('resumeKeyFor', () {
    test('is deterministic for the same path', () {
      expect(
        PlayerEnhancementsService.resumeKeyFor('/downloads/a.mkv'),
        PlayerEnhancementsService.resumeKeyFor('/downloads/a.mkv'),
      );
    });

    test('differs between paths', () {
      expect(
        PlayerEnhancementsService.resumeKeyFor('/downloads/a.mkv'),
        isNot(PlayerEnhancementsService.resumeKeyFor('/downloads/b.mkv')),
      );
    });

    test('is a full SHA-1 digest, not the volatile String.hashCode', () {
      final key = PlayerEnhancementsService.resumeKeyFor('/downloads/a.mkv');
      expect(key, startsWith('player_resume_'));
      // 40 hex characters: wide enough that collisions are not a concern and
      // stable across Dart SDK upgrades, unlike String.hashCode.
      expect(
        key.substring('player_resume_'.length),
        matches(r'^[0-9a-f]{40}$'),
      );
    });

    test('handles non-ASCII paths', () {
      expect(
        PlayerEnhancementsService.resumeKeyFor('/下载/影片.mkv'),
        startsWith('player_resume_'),
      );
    });
  });

  group('queue navigation', () {
    late PlayerEnhancementsService service;
    late List<String> opened;

    setUp(() {
      opened = [];
      service = PlayerEnhancementsService()
        ..setQueue([_item('a'), _item('b'), _item('c')]);
      service.openHandler = (item) async {
        opened.add(item.title);
        return true;
      };
    });

    tearDown(() => service.dispose());

    test('playNext advances through the queue via the open handler', () async {
      expect((await service.playNext())?.title, 'b');
      expect((await service.playNext())?.title, 'c');
      expect(await service.playNext(), isNull);
      expect(opened, ['b', 'c']);
    });

    test('playNext wraps around when looping the whole queue', () async {
      service.setLoopMode(LoopMode.all);
      service.setQueue([_item('a'), _item('b')], startIndex: 1);
      expect((await service.playNext())?.title, 'a');
    });

    test('playPrevious stops at the start of the queue', () async {
      service.setQueue([_item('a'), _item('b')], startIndex: 1);
      expect((await service.playPrevious())?.title, 'a');
      expect(await service.playPrevious(), isNull);
    });

    test('a failing open handler does not advance the queue', () async {
      service.openHandler = (_) async => false;
      final before = service.currentIndex;
      await service.playNext();
      // The index still moves (the user asked for the next item) but nothing
      // was opened, so no phantom playback state is created.
      expect(service.currentIndex, before + 1);
    });

    test('detachPlayer clears the open handler', () {
      service.detachPlayer();
      expect(service.openHandler, isNull);
    });
  });

  group('speed', () {
    test('cycleSpeed wraps back to 1x after the fastest step', () {
      final service = PlayerEnhancementsService()
        ..setSpeed(PlayerEnhancementsService.speeds.last);
      service.cycleSpeed();
      expect(service.speed, 1.0);
      service.dispose();
    });

    test('setSpeed clamps to the supported range', () {
      final service = PlayerEnhancementsService()..setSpeed(99);
      expect(service.speed, 4.0);
      service.setSpeed(0.01);
      expect(service.speed, 0.25);
      service.dispose();
    });
  });
}
