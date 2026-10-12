// Phase 2: validates the generated content.json (also re-checked by the
// generator itself at build time — this test guards regressions).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/economy.dart';

Map<String, dynamic> loadContent() {
  final file = File('assets/content/content.json');
  expect(file.existsSync(), isTrue,
      reason: 'run dart run tool/generate_content.dart first');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> content;
  late List<Map<String, dynamic>> zones;
  late List<Map<String, dynamic>> rooms;
  late List<Map<String, dynamic>> pets;

  setUpAll(() {
    content = loadContent();
    zones = (content['zones'] as List).cast<Map<String, dynamic>>();
    rooms = (content['rooms'] as List).cast<Map<String, dynamic>>();
    pets = (content['pets'] as List).cast<Map<String, dynamic>>();
  });

  test('counts: 10 zones, 60 rooms, 30 pets', () {
    expect(zones.length, equals(10));
    expect(rooms.length, equals(60));
    expect(pets.length, equals(30));
  });

  test('ids unique across rooms and pets', () {
    expect(rooms.map((r) => r['id']).toSet().length, equals(60));
    expect(pets.map((p) => p['id']).toSet().length, equals(30));
  });

  test('zone unlock costs strictly increasing, pet reqs sane', () {
    for (var i = 1; i < zones.length; i++) {
      expect(zones[i]['coinCost'] as num,
          greaterThan(zones[i - 1]['coinCost'] as num));
    }
    for (final z in zones) {
      expect(z['requiredPets'], inInclusiveRange(0, 30));
    }
    expect(zones.first['coinCost'], equals(0));
  });

  test('6 rooms per zone, costs and income increasing within zone', () {
    for (var z = 0; z < 10; z++) {
      final zr = rooms.where((r) => r['zoneIndex'] == z).toList();
      expect(zr.length, equals(6), reason: 'zone $z');
      for (var i = 1; i < zr.length; i++) {
        expect(zr[i]['baseCost'] as num, greaterThan(zr[i - 1]['baseCost'] as num));
        expect(zr[i]['baseIncome'] as num,
            greaterThan(zr[i - 1]['baseIncome'] as num));
      }
    }
  });

  test('payback within sane bounds for every room', () {
    for (final r in rooms) {
      final payback = (r['baseCost'] as num) / (r['baseIncome'] as num);
      expect(payback, inInclusiveRange(20, 10800), reason: '${r['id']}');
    }
  });

  test('pet rarity mix is 15 common / 10 rare / 5 epic', () {
    final counts = <String, int>{};
    for (final p in pets) {
      final rar = p['rarity'] as String;
      counts[rar] = (counts[rar] ?? 0) + 1;
    }
    expect(counts['common'], equals(15));
    expect(counts['rare'], equals(10));
    expect(counts['epic'], equals(5));
  });

  test('pet ids follow the art naming convention', () {
    for (final p in pets) {
      final parts = (p['id'] as String).split('_');
      expect(parts.length, equals(2));
      expect(['puppy', 'kitten', 'golden'], contains(parts[0]));
    }
  });

  test('content loads into the engine and earns', () {
    final roomDefs = {
      for (final r in rooms) r['id'] as String: RoomDef.fromJson(r)
    };
    final petDefs = {
      for (final p in pets) p['id'] as String: PetDef.fromJson(p)
    };
    final s = ShelterState()..registerContent(roomDefs.values, petDefs.values);
    expect(s.rooms.length, equals(60));
    expect(s.pets.length, equals(30));

    // first room of every zone is buyable in sequence and earns
    s.coins = 1e15;
    for (var z = 0; z < 10; z++) {
      expect(ShelterEconomy.buyRoom(s, 'z${z}r0'), isTrue);
    }
    expect(ShelterEconomy.totalIncomePerSec(s), greaterThan(0));
  });
}
