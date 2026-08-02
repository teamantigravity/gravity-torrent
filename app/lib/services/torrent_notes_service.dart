import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Stores user-written notes per torrent.
///
/// Notes are kept in local shared preferences and are never uploaded.
/// This works everywhere the app runs, including Linux, Windows, macOS,
/// Android, iOS and the web build.
class TorrentNotesService {
  TorrentNotesService._();
  static final TorrentNotesService instance = TorrentNotesService._();

  static const _storageKey = 'gravity_torrent_notes_v1';

  final Map<String, String> _notes = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await SharedPrefsStorage.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _notes.clear();
          decoded.forEach((key, value) {
            if (value is String) {
              _notes[key.toString()] = value;
            }
          });
        }
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('TorrentNotesService failed to load: $e\n$s');
        }
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    await SharedPrefsStorage.setString(_storageKey, jsonEncode(_notes));
  }

  /// Returns the note for [torrentId], or an empty string if none.
  Future<String> getNote(int torrentId) async {
    await load();
    return _notes[torrentId.toString()] ?? '';
  }

  /// Sets [note] as the user note for [torrentId].
  Future<void> setNote(int torrentId, String note) async {
    await load();
    if (note.trim().isEmpty) {
      _notes.remove(torrentId.toString());
    } else {
      _notes[torrentId.toString()] = note.trim();
    }
    await _save();
  }

  /// Removes the note for [torrentId].
  Future<void> removeNote(int torrentId) async {
    await load();
    _notes.remove(torrentId.toString());
    await _save();
  }

  /// Clears all stored notes.
  Future<void> clear() async {
    _notes.clear();
    await _save();
  }

  /// For tests.
  void reset() {
    _notes.clear();
    _loaded = false;
  }
}
