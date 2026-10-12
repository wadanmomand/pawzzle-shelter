/// Hive-backed save: the whole game state as one versioned JSON blob.
/// No adapters needed. Testable with a temp dir (Hive.init works on the VM).
library;

import 'package:hive/hive.dart';

class SaveService {
  static const _key = 'save_v1';

  late final Box<String> _box;
  bool _open = false;

  SaveService._();

  static Future<SaveService> open(String dir) async {
    final s = SaveService._();
    Hive.init(dir);
    s._box = await Hive.openBox<String>('pawzzle_shelter');
    s._open = true;
    return s;
  }

  /// Raw JSON string, or null when nothing was saved yet.
  String? read() => _open ? _box.get(_key) : null;

  Future<void> write(String json) async {
    if (_open) await _box.put(_key, json);
  }

  Future<void> clear() async {
    if (_open) await _box.delete(_key);
  }

  Future<void> close() async {
    if (_open) {
      await _box.close();
      _open = false;
    }
  }
}
