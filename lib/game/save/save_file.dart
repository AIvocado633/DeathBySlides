import 'package:flutter/foundation.dart';

import 'save_data.dart';
import 'save_store.dart';

/// The game's save: read once at startup, kept in memory, and written back
/// through a [SaveStore] whenever something worth keeping changes.
class SaveFile {
  SaveFile._(this._store, this._data);

  /// Reads the save from [store].
  ///
  /// Never throws. Nothing saved yet is a fresh start, and so is a save that
  /// cannot be read -- corrupt, or written by a newer build of the game --
  /// after one line in the log. That save is left alone until the game next
  /// saves, so merely opening an older build does not wipe a newer one's save.
  static Future<SaveFile> load(SaveStore store) async {
    try {
      final document = await store.read();
      return SaveFile._(
        store,
        document == null ? const SaveData() : SaveData.decode(document),
      );
    } on Exception catch (error) {
      debugPrint('SaveFile: cannot read the save ($error) - starting fresh.');
      return SaveFile._(store, const SaveData());
    }
  }

  final SaveStore _store;

  /// Everything saved, including changes still on their way to the store.
  SaveData get data => _data;
  SaveData _data;

  Future<void> _writes = Future<void>.value();

  /// Records that [slide] has been won, and saves.
  Future<void> recordWin(int slide) {
    if (_data.progress.hasBeaten(slide)) {
      return _writes;
    }
    return _save(_data.copyWith(progress: _data.progress.withBeaten(slide)));
  }

  /// Replaces the settings with [settings], and saves.
  Future<void> updateSettings(Settings settings) =>
      _save(_data.copyWith(settings: settings));

  Future<void> _save(SaveData data) {
    _data = data;
    final document = data.encode();
    // Chained, so writes land in the order they were made. A write that fails
    // costs that write -- the change is still known for this run -- and never
    // the game.
    return _writes = _writes.then((_) async {
      try {
        await _store.write(document);
      } on Exception catch (error) {
        debugPrint('SaveFile: cannot write the save ($error).');
      }
    });
  }
}
