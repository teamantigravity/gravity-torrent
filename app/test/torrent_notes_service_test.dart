import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/torrent_notes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TorrentNotesService.instance.reset();
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    TorrentNotesService.instance.reset();
  });

  group('TorrentNotesService', () {
    test('returns empty note by default', () async {
      final note = await TorrentNotesService.instance.getNote(42);
      expect(note, '');
    });

    test('stores and retrieves a note', () async {
      await TorrentNotesService.instance.setNote(42, 'Keep this one private');
      final note = await TorrentNotesService.instance.getNote(42);
      expect(note, 'Keep this one private');
    });

    test('updates an existing note', () async {
      await TorrentNotesService.instance.setNote(1, 'first');
      await TorrentNotesService.instance.setNote(1, 'second');
      final note = await TorrentNotesService.instance.getNote(1);
      expect(note, 'second');
    });

    test('trims whitespace and removes empty notes', () async {
      await TorrentNotesService.instance.setNote(1, '  ');
      final note = await TorrentNotesService.instance.getNote(1);
      expect(note, '');
    });

    test('removes a note explicitly', () async {
      await TorrentNotesService.instance.setNote(1, 'to be removed');
      await TorrentNotesService.instance.removeNote(1);
      final note = await TorrentNotesService.instance.getNote(1);
      expect(note, '');
    });

    test('clears all notes', () async {
      await TorrentNotesService.instance.setNote(1, 'a');
      await TorrentNotesService.instance.setNote(2, 'b');
      await TorrentNotesService.instance.clear();
      expect(await TorrentNotesService.instance.getNote(1), '');
      expect(await TorrentNotesService.instance.getNote(2), '');
    });

    test('persists across instances after load', () async {
      await TorrentNotesService.instance.setNote(7, 'persistent');
      TorrentNotesService.instance.reset();
      final note = await TorrentNotesService.instance.getNote(7);
      expect(note, 'persistent');
    });
  });
}
