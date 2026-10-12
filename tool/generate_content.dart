/// Pawzzle Shelter — Phase 2 content generator.
///
/// Builds zones.json/rooms.json/pets.json from the game-plan tables, validates
/// every tuning invariant, and writes assets/content/content.json.
///
/// Run: dart run tool/generate_content.dart   (from app/)
/// Validation failures throw with a clear message — the build must not ship
/// content that fails these checks.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelter/core/economy.dart';

// ---------------------------------------------------------------------------
// Source tables (from GAME_PLAN.md §6 + Appendix A)
// ---------------------------------------------------------------------------

const List<String> _zoneNames = [
  'Puppy Park',
  'Kitten Cove',
  'Flower Garden',
  'Bird Barn',
  'Bunny Meadow',
  'Pond Paradise',
  'Sunset Hill',
  'Starlight Camp',
  'Rainbow Falls',
  'Golden Palace',
];

/// coinCost + requiredPets per zone (zone 0 is free).
const List<List<num>> _zoneUnlock = [
  [0, 0],
  [5000, 2],
  [50000, 5],
  [400000, 9],
  [3000000, 13],
  [20000000, 17],
  [150000000, 21],
  [1000000000, 24],
  [8000000000, 27],
  [60000000000, 30],
];

const List<List<String>> _roomNames = [
  ['Dog House', 'Puppy Playground', 'Fetch Field', 'Bone Statue', 'Puppy Pool', 'Treat Truck'],
  ['Kitten Tower', 'Yarn Garden', 'Milk Bar', 'Nap Corner', 'Scratching Plaza', 'Fish Dock'],
  ['Flower Beds', 'Butterfly Dome', 'Fountain', 'Picnic Spot', 'Hedge Corner', 'Sunflower Field'],
  ['Birdhouse Row', 'Seed Silo', 'Aviary', 'Windmill', 'Perch Plaza', 'Nest Tower'],
  ['Burrow Homes', 'Carrot Patch', 'Hop Track', 'Clover Field', 'Bunny Barn', 'Meadow Swing'],
  ['Duck Deck', 'Lily Stage', 'Waterfall', 'Reed Boats', 'Frog Corner', 'Splash Pool'],
  ['Sunset Deck', 'Star Tent', 'Campfire Circle', 'Hill Slide', 'Lantern Path', 'Vista Point'],
  ['Tent Village', 'Bonfire Stage', 'Night Garden', 'Telescope Deck', 'Firefly Grove', 'Moon Bridge'],
  ['Rainbow Bridge', 'Falls Overlook', 'Mist Garden', 'Crystal Cave', 'Prism Plaza', 'Cloud Steps'],
  ['Golden Statue', 'Trophy Hall', 'Royal Kennel', 'Crown Garden', 'VIP Lounge', 'Hall of Fame'],
];

/// (baseCost, baseIncome) per zone. Room-0 payback ≈ 240s everywhere
/// (zone 0 is 50s for a fast FTUE); later rooms in a zone lengthen payback
/// by design (cost step 3.0 > income step 2.2).
const List<List<double>> _tiers = [
  [50, 1], // zone 0 — Puppy Park
  [500, 2], // zone 1 — Kitten Cove
  [5000, 20], // zone 2 — Flower Garden
  [40000, 165], // zone 3 — Bird Barn
  [300000, 1250], // zone 4 — Bunny Meadow
  [2000000, 8300], // zone 5 — Pond Paradise
  [15000000, 62000], // zone 6 — Sunset Hill
  [100000000, 415000], // zone 7 — Starlight Camp
  [800000000, 3300000], // zone 8 — Rainbow Falls
  [6000000000, 25000000], // zone 9 — Golden Palace
];

/// Within a zone, room i scales cost by 3^i and income by 2.2^i.
const double _roomCostStep = 3.0;
const double _roomIncomeStep = 2.2;

/// 30 pets: id, display name, rarity. Art exists in
/// ~/workspace/pet-rescue-sort/art/pets/ for every id below.
const List<List<String>> _pets = [
  // puppies (12)
  ['puppy_milo', 'Milo', 'common'],
  ['puppy_coco', 'Coco', 'common'],
  ['puppy_biscuit', 'Biscuit', 'common'],
  ['puppy_buddy', 'Buddy', 'common'],
  ['puppy_daisy', 'Daisy', 'common'],
  ['puppy_lucky', 'Lucky', 'common'],
  ['puppy_pepper', 'Pepper', 'common'],
  ['puppy_snowy', 'Snowy', 'common'],
  ['puppy_teddy', 'Teddy', 'common'],
  ['puppy_rocky', 'Rocky', 'epic'],
  ['puppy_waffles', 'Waffles', 'rare'],
  ['puppy_max', 'Max', 'rare'],
  // kittens (12)
  ['kitten_luna', 'Luna', 'common'],
  ['kitten_bella', 'Bella', 'common'],
  ['kitten_chloe', 'Chloe', 'common'],
  ['kitten_lily', 'Lily', 'common'],
  ['kitten_misty', 'Misty', 'common'],
  ['kitten_oliver', 'Oliver', 'rare'],
  ['kitten_oreo', 'Oreo', 'rare'],
  ['kitten_poppy', 'Poppy', 'rare'],
  ['kitten_rosie', 'Rosie', 'rare'],
  ['kitten_smokey', 'Smokey', 'common'],
  ['kitten_tiger', 'Tiger', 'rare'],
  ['kitten_simba', 'Simba', 'epic'],
  // goldens (6)
  ['golden_max', 'Max', 'epic'],
  ['golden_luna', 'Luna', 'epic'],
  ['golden_bella', 'Bella', 'rare'],
  ['golden_oliver', 'Oliver', 'rare'],
  ['golden_coco', 'Coco', 'epic'],
  ['golden_biscuit', 'Biscuit', 'rare'],
];

String _roomId(int zone, int i) => 'z${zone}r$i';

void _fail(String msg) => throw StateError('CONTENT VALIDATION FAILED: $msg');

void main() {
  // ---- build defs ---------------------------------------------------------
  final zones = <ZoneDef>[];
  for (var z = 0; z < 10; z++) {
    zones.add(ZoneDef(
      index: z,
      name: _zoneNames[z],
      coinCost: _zoneUnlock[z][0].toDouble(),
      requiredPets: _zoneUnlock[z][1].toInt(),
    ));
  }

  final rooms = <RoomDef>[];
  for (var z = 0; z < 10; z++) {
    final tier = _tiers[z];
    for (var i = 0; i < 6; i++) {
      rooms.add(RoomDef(
        id: _roomId(z, i),
        zoneIndex: z,
        name: _roomNames[z][i],
        baseCost: tier[0] * _pow(_roomCostStep, i),
        baseIncome: tier[1] * _pow(_roomIncomeStep, i),
      ));
    }
  }

  final pets = <PetDef>[];
  for (final p in _pets) {
    pets.add(PetDef(id: p[0], name: p[1], rarity: Rarity.values.byName(p[2])));
  }

  // ---- validate -----------------------------------------------------------
  _validate(zones, rooms, pets);

  // ---- write --------------------------------------------------------------
  final out = {
    'zones': [
      for (final z in zones)
        {'index': z.index, 'name': z.name, 'coinCost': z.coinCost, 'requiredPets': z.requiredPets}
    ],
    'rooms': [for (final r in rooms) r.toJson()],
    'pets': [for (final p in pets) p.toJson()],
  };
  final file = File('assets/content/content.json');
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(out)}\n');

  print('OK: ${zones.length} zones, ${rooms.length} rooms, ${pets.length} pets '
      '-> ${file.path} (${file.lengthSync()} bytes)'); // ignore: avoid_print
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}

void _validate(List<ZoneDef> zones, List<RoomDef> rooms, List<PetDef> pets) {
  // counts
  if (zones.length != 10) _fail('expected 10 zones, got ${zones.length}');
  if (rooms.length != 60) _fail('expected 60 rooms, got ${rooms.length}');
  if (pets.length != 30) _fail('expected 30 pets, got ${pets.length}');

  // unique ids
  final roomIds = rooms.map((r) => r.id).toSet();
  if (roomIds.length != rooms.length) _fail('duplicate room ids');
  final petIds = pets.map((p) => p.id).toSet();
  if (petIds.length != pets.length) _fail('duplicate pet ids');

  // zones: unlock costs strictly increasing, pet reqs non-decreasing & <= 30
  for (var z = 1; z < zones.length; z++) {
    if (zones[z].coinCost <= zones[z - 1].coinCost) {
      _fail('zone $z coinCost not increasing');
    }
    if (zones[z].requiredPets < zones[z - 1].requiredPets) {
      _fail('zone $z requiredPets decreased');
    }
  }
  if (zones.last.requiredPets > 30) _fail('requiredPets exceeds pet count');

  // rooms: 6 per zone, costs & income strictly increasing, sane payback
  for (var z = 0; z < 10; z++) {
    final zr = rooms.where((r) => r.defZone(z)).toList();
    if (zr.length != 6) _fail('zone $z has ${zr.length} rooms, expected 6');
    for (var i = 1; i < zr.length; i++) {
      if (zr[i].baseCost <= zr[i - 1].baseCost) {
        _fail('zone $z room $i cost not increasing');
      }
      if (zr[i].baseIncome <= zr[i - 1].baseIncome) {
        _fail('zone $z room $i income not increasing');
      }
    }
    for (final r in zr) {
      // Payback lengthens within a zone by design (cost step 3.0 > income step
      // 2.2): late rooms are bought for progression + zone synergy, not ROI.
      // The bound only catches insane values.
      final payback = r.baseCost / r.baseIncome; // seconds at level 1
      if (payback < 20 || payback > 10800) {
        _fail('${r.id} payback ${payback.toStringAsFixed(0)}s out of [20, 10800]');
      }
    }
  }

  // pets: rarity mix 15 common / 10 rare / 5 epic
  final counts = <Rarity, int>{};
  for (final p in pets) {
    counts[p.rarity] = (counts[p.rarity] ?? 0) + 1;
  }
  if (counts[Rarity.common] != 15) _fail('common pets: ${counts[Rarity.common]}');
  if (counts[Rarity.rare] != 10) _fail('rare pets: ${counts[Rarity.rare]}');
  if (counts[Rarity.epic] != 5) _fail('epic pets: ${counts[Rarity.epic]}');

  // every pet id maps to real art (naming convention check)
  for (final p in pets) {
    final parts = p.id.split('_');
    if (parts.length != 2 || !['puppy', 'kitten', 'golden'].contains(parts[0])) {
      _fail('pet id ${p.id} breaks the art naming convention');
    }
  }

  // engine smoke: full-economy sanity — a maxed zone-0 shelter earns > 0 and
  // prestige math stays finite on endgame-scale numbers
  final s = ShelterState();
  s.registerContent(rooms, pets);
  s.coins = 1e15;
  for (final r in s.rooms.values) {
    r.level = kMaxRoomLevel;
  }
  s.goldenPaws = 100;
  final income = ShelterEconomy.totalIncomePerSec(s);
  if (!income.isFinite || income <= 0) _fail('endgame income insane: $income');
  s.lifetimeCoins = 1e15;
  final gain = ShelterEconomy.prestigeGain(s);
  if (gain <= 0 || gain > 1000000) _fail('prestige gain insane: $gain');
}

extension on RoomDef {
  bool defZone(int z) => zoneIndex == z;
}
