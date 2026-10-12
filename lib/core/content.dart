/// Loads content.json into engine defs. Pure Dart (string in, bundle out) —
/// the Riverpod layer feeds it `rootBundle.loadString`.
library;

import 'dart:convert';

import 'package:shelter/core/economy.dart';

class ContentBundle {
  final List<ZoneDef> zones;
  final Map<String, RoomDef> rooms;
  final Map<String, PetDef> pets;

  const ContentBundle({
    required this.zones,
    required this.rooms,
    required this.pets,
  });

  factory ContentBundle.fromJsonString(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final zones = [
      for (final z in (j['zones'] as List).cast<Map<String, dynamic>>())
        ZoneDef(
          index: (z['index'] as num).toInt(),
          name: z['name'] as String,
          coinCost: (z['coinCost'] as num).toDouble(),
          requiredPets: (z['requiredPets'] as num).toInt(),
        )
    ];
    final rooms = {
      for (final r in (j['rooms'] as List).cast<Map<String, dynamic>>())
        r['id'] as String: RoomDef.fromJson(r)
    };
    final pets = {
      for (final p in (j['pets'] as List).cast<Map<String, dynamic>>())
        p['id'] as String: PetDef.fromJson(p)
    };
    return ContentBundle(zones: zones, rooms: rooms, pets: pets);
  }

  List<RoomDef> roomsInZone(int zoneIndex) =>
      rooms.values.where((r) => r.zoneIndex == zoneIndex).toList();
}
