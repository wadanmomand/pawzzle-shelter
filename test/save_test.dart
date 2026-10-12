import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/state/save.dart';

void main() {
  group('SaveService', () {
    late Directory tmp;
    late SaveService save;

    setUpAll(() async {
      tmp = await Directory.systemTemp.createTemp('shelter_save_test');
      save = await SaveService.open(tmp.path);
    });

    tearDownAll(() async {
      await save.close();
      await tmp.delete(recursive: true);
    });

    test('read empty at first', () {
      expect(save.read(), isNull);
    });

    test('write/read roundtrip', () async {
      const json = '{"shelter":{"coins":123},"missions":{}}';
      await save.write(json);
      expect(save.read(), equals(json));
    });

    test('overwrite works', () async {
      await save.write('{"v":1}');
      await save.write('{"v":2}');
      expect(save.read(), equals('{"v":2}'));
    });

    test('clear removes the save', () async {
      await save.write('{"v":1}');
      await save.clear();
      expect(save.read(), isNull);
    });
  });
}
