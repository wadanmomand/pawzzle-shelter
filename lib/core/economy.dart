/// Pawzzle Shelter — idle/clicker economy engine (Phase 1).
///
/// Pure Dart: no Flutter imports, fully unit-testable. All tuning lives in the
/// constants below and in content JSON (Phase 2) — the engine itself never
/// hardcodes a room or pet.
library;

import 'dart:math';

/// Cost growth per room level: cost(level) = baseCost * kCostGrowth^level.
const double kCostGrowth = 1.22;

/// Income growth per room level: income(level) = baseIncome * kIncomeGrowth^level.
const double kIncomeGrowth = 1.18;

/// Highest level a room can reach.
const int kMaxRoomLevel = 50;

/// Levels at which a room's income doubles (each milestone multiplies by 2).
const List<int> kMilestoneLevels = [10, 25, 50];

/// Zone synergy: when every room in a zone is built and at least level 10,
/// each room in that zone earns this multiplier.
const double kZoneSynergyMult = 1.25;

/// Offline earnings: capped hours, at this efficiency of live income.
const double kOfflineCapHours = 8.0;
const double kOfflineEfficiency = 0.5;

/// Prestige ("Naya Season") requirements.
const int kPrestigeZoneIndex = 4; // 5th zone must be unlocked
const double kPrestigeMinLifetimeCoins = 1e9;

/// Golden Paws gained on prestige: floor(10 * sqrt(lifetimeCoins / 1e9)).
const double kPrestigeDivisor = 1e9;
const double kPrestigeFactor = 10.0;

/// Each Golden Paw adds this much permanent income (fraction, 0.02 = +2%).
const double kPrestigePawBonus = 0.02;

/// Tapping: each tap pays this fraction of income/sec (min 1 coin), times combo.
const double kTapIncomeFraction = 0.05;

/// Combo: +10% per consecutive tap (2s window), capped at this multiplier.
const double kTapComboStep = 0.1;
const double kTapComboCap = 5.0;
const Duration kTapComboWindow = Duration(seconds: 2);

/// Feeding a pet costs this many treats and adds this much happiness (0-100).
const double kFeedTreatCost = 1.0;
const double kFeedHappinessGain = 25.0;

/// Happiness bonus on the assigned room: 1 + (happiness/100) * this.
const double kHappinessBonus = 0.25;

enum Rarity { common, rare, epic }

extension RarityX on Rarity {
  /// Income multiplier a pet of this rarity grants its assigned room.
  double get roomMultiplier => switch (this) {
        Rarity.common => 1.25,
        Rarity.rare => 1.5,
        Rarity.epic => 2.0,
      };

  String get json => name;
  static Rarity fromJson(String s) => Rarity.values.byName(s);
}

/// Static definition of a money-generating room (from content JSON in Phase 2).
class RoomDef {
  final String id;
  final int zoneIndex;
  final String name;
  final double baseCost;
  final double baseIncome; // coins/sec at level 1, before multipliers

  const RoomDef({
    required this.id,
    required this.zoneIndex,
    required this.name,
    required this.baseCost,
    required this.baseIncome,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'zoneIndex': zoneIndex,
        'name': name,
        'baseCost': baseCost,
        'baseIncome': baseIncome,
      };

  factory RoomDef.fromJson(Map<String, dynamic> j) => RoomDef(
        id: j['id'] as String,
        zoneIndex: j['zoneIndex'] as int,
        name: j['name'] as String,
        baseCost: (j['baseCost'] as num).toDouble(),
        baseIncome: (j['baseIncome'] as num).toDouble(),
      );
}

/// Mutable state of one room. level 0 = not built yet.
class RoomState {
  final RoomDef def;
  int level;

  RoomState(this.def, [this.level = 0]);

  bool get isBuilt => level > 0;
  bool get isMaxed => level >= kMaxRoomLevel;

  /// Cost to build (level 0 -> 1) or upgrade (level -> level+1).
  double get nextCost => def.baseCost * pow(kCostGrowth, level).toDouble();

  /// Milestone multiplier: x2 at each of levels 10/25/50 (stacking).
  double get milestoneMult {
    var m = 1.0;
    for (final ms in kMilestoneLevels) {
      if (level >= ms) m *= 2.0;
    }
    return m;
  }

  Map<String, dynamic> toJson() => {'id': def.id, 'level': level};
}

/// Static definition of a rescueable pet.
class PetDef {
  final String id;
  final String name;
  final Rarity rarity;

  const PetDef({required this.id, required this.name, required this.rarity});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'rarity': rarity.json};

  factory PetDef.fromJson(Map<String, dynamic> j) => PetDef(
        id: j['id'] as String,
        name: j['name'] as String,
        rarity: RarityX.fromJson(j['rarity'] as String),
      );
}

/// Mutable state of one rescued pet.
class PetState {
  final PetDef def;
  String? assignedRoomId;
  double happiness; // 0..100

  PetState(this.def, {this.assignedRoomId, this.happiness = 50.0});

  /// Income multiplier this pet grants its assigned room (rarity + happiness).
  double get roomMultiplier =>
      def.rarity.roomMultiplier * (1.0 + (happiness / 100.0) * kHappinessBonus);

  Map<String, dynamic> toJson() => {
        'id': def.id,
        'assignedRoomId': assignedRoomId,
        'happiness': happiness,
      };
}

/// Zone unlock requirement (checked by UI/content layer; engine enforces payment).
class ZoneDef {
  final int index;
  final String name;
  final double coinCost;
  final int requiredPets;

  const ZoneDef({
    required this.index,
    required this.name,
    required this.coinCost,
    required this.requiredPets,
  });
}

/// The whole game state. Mutated only through [ShelterEconomy].
class ShelterState {
  double coins;
  double treats;
  double goldenPaws;
  double lifetimeCoins;
  final Map<String, RoomState> rooms; // roomId -> state
  final Map<String, PetState> pets; // petId -> state
  final Set<int> unlockedZones;
  DateTime? lastSeen;
  int tapCombo;
  DateTime? lastTapAt;

  ShelterState({
    this.coins = 0,
    this.treats = 0,
    this.goldenPaws = 0,
    this.lifetimeCoins = 0,
    Map<String, RoomState>? rooms,
    Map<String, PetState>? pets,
    Set<int>? unlockedZones,
    this.lastSeen,
    this.tapCombo = 0,
    this.lastTapAt,
  })  : rooms = rooms ?? {},
        pets = pets ?? {},
        unlockedZones = unlockedZones ?? {0};

  /// Registers room/pet defs (from content) so every id has a state object.
  void registerContent(Iterable<RoomDef> roomDefs, Iterable<PetDef> petDefs) {
    for (final d in roomDefs) {
      rooms.putIfAbsent(d.id, () => RoomState(d));
    }
    for (final d in petDefs) {
      pets.putIfAbsent(d.id, () => PetState(d));
    }
  }

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'treats': treats,
        'goldenPaws': goldenPaws,
        'lifetimeCoins': lifetimeCoins,
        'rooms': rooms.values.map((r) => r.toJson()).toList(),
        'pets': pets.values.map((p) => p.toJson()).toList(),
        'unlockedZones': unlockedZones.toList(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory ShelterState.fromJson(
    Map<String, dynamic> j,
    Map<String, RoomDef> roomDefs,
    Map<String, PetDef> petDefs,
  ) {
    final s = ShelterState(
      coins: (j['coins'] as num).toDouble(),
      treats: (j['treats'] as num).toDouble(),
      goldenPaws: (j['goldenPaws'] as num).toDouble(),
      lifetimeCoins: (j['lifetimeCoins'] as num).toDouble(),
      unlockedZones:
          (j['unlockedZones'] as List).map((e) => (e as num).toInt()).toSet(),
      lastSeen:
          j['lastSeen'] == null ? null : DateTime.parse(j['lastSeen'] as String),
    );
    for (final r in j['rooms'] as List) {
      final m = r as Map<String, dynamic>;
      final def = roomDefs[m['id'] as String];
      if (def != null) {
        s.rooms[def.id] = RoomState(def, (m['level'] as num).toInt());
      }
    }
    for (final p in j['pets'] as List) {
      final m = p as Map<String, dynamic>;
      final def = petDefs[m['id'] as String];
      if (def != null) {
        s.pets[def.id] = PetState(
          def,
          assignedRoomId: m['assignedRoomId'] as String?,
          happiness: (m['happiness'] as num).toDouble(),
        );
      }
    }
    return s;
  }
}

/// Pure-Dart idle economy. Every method is deterministic and unit-testable.
class ShelterEconomy {
  const ShelterEconomy._();

  /// Permanent income multiplier from Golden Paws.
  static double prestigeMultiplier(ShelterState s) =>
      1.0 + s.goldenPaws * kPrestigePawBonus;

  /// True when every room in [zoneIndex] is built and level >= 10.
  static bool zoneSynergyActive(ShelterState s, int zoneIndex) {
    final zoneRooms =
        s.rooms.values.where((r) => r.def.zoneIndex == zoneIndex).toList();
    if (zoneRooms.isEmpty) return false;
    return zoneRooms.every((r) => r.level >= 10);
  }

  static double _petMultiplierFor(ShelterState s, String roomId) {
    var m = 1.0;
    for (final p in s.pets.values) {
      if (p.assignedRoomId == roomId) m *= p.roomMultiplier;
    }
    return m;
  }

  /// Coins/sec earned by one room after all multipliers.
  static double roomIncome(ShelterState s, String roomId) {
    final room = s.rooms[roomId];
    if (room == null || !room.isBuilt) return 0.0;
    var income = room.def.baseIncome * pow(kIncomeGrowth, room.level).toDouble();
    income *= room.milestoneMult;
    income *= _petMultiplierFor(s, roomId);
    if (zoneSynergyActive(s, room.def.zoneIndex)) income *= kZoneSynergyMult;
    income *= prestigeMultiplier(s);
    return income;
  }

  /// Total coins/sec across all built rooms.
  static double totalIncomePerSec(ShelterState s) {
    var total = 0.0;
    for (final id in s.rooms.keys) {
      total += roomIncome(s, id);
    }
    return total;
  }

  /// Build (level 0 -> 1) or upgrade a room. Returns false if maxed or broke.
  static bool buyRoom(ShelterState s, String roomId) {
    final room = s.rooms[roomId];
    if (room == null || room.isMaxed) return false;
    final cost = room.nextCost;
    if (s.coins < cost) return false;
    s.coins -= cost;
    room.level += 1;
    return true;
  }

  /// Advance the simulation by [dt] (called every frame/tick while open).
  static void tick(ShelterState s, Duration dt) {
    final gained = totalIncomePerSec(s) * dt.inMilliseconds / 1000.0;
    s.coins += gained;
    s.lifetimeCoins += gained;
    s.lastSeen = DateTime.now();
  }

  /// Active tap. Returns coins gained (combo-aware).
  static double tap(ShelterState s, DateTime now) {
    if (s.lastTapAt == null ||
        now.difference(s.lastTapAt!) > kTapComboWindow) {
      s.tapCombo = 0;
    }
    s.tapCombo += 1;
    s.lastTapAt = now;
    final comboMult =
        (1.0 + (s.tapCombo - 1) * kTapComboStep).clamp(1.0, kTapComboCap);
    final gained =
        max(1.0, totalIncomePerSec(s) * kTapIncomeFraction) * comboMult;
    s.coins += gained;
    s.lifetimeCoins += gained;
    return gained;
  }

  /// Offline earnings since [now] vs lastSeen. Applies to state, returns gained.
  /// Zero when the game was never closed (lastSeen == null).
  static double collectOffline(ShelterState s, DateTime now) {
    final last = s.lastSeen;
    if (last == null) {
      s.lastSeen = now;
      return 0.0;
    }
    final elapsedHours =
        now.difference(last).inMilliseconds / (1000.0 * 3600.0);
    final capped = elapsedHours.clamp(0.0, kOfflineCapHours);
    final gained = totalIncomePerSec(s) * capped * 3600.0 * kOfflineEfficiency;
    s.coins += gained;
    s.lifetimeCoins += gained;
    s.lastSeen = now;
    return gained;
  }

  /// Feed a pet: costs treats, raises happiness (capped at 100).
  static bool feedPet(ShelterState s, String petId) {
    final pet = s.pets[petId];
    if (pet == null || s.treats < kFeedTreatCost) return false;
    s.treats -= kFeedTreatCost;
    pet.happiness = (pet.happiness + kFeedHappinessGain).clamp(0.0, 100.0);
    return true;
  }

  /// Assign a rescued pet to a room (null unassigns).
  static void assignPet(ShelterState s, String petId, String? roomId) {
    final pet = s.pets[petId];
    if (pet == null) return;
    if (roomId != null && !s.rooms.containsKey(roomId)) return;
    pet.assignedRoomId = roomId;
  }

  /// Unlock a zone if the player can pay coin cost and owns enough pets.
  static bool unlockZone(ShelterState s, ZoneDef zone) {
    if (s.unlockedZones.contains(zone.index)) return false;
    if (s.coins < zone.coinCost) return false;
    if (s.pets.length < zone.requiredPets) return false;
    s.coins -= zone.coinCost;
    s.unlockedZones.add(zone.index);
    return true;
  }

  /// Golden Paws the next prestige would grant.
  static int prestigeGain(ShelterState s) {
    if (s.lifetimeCoins < kPrestigeMinLifetimeCoins) return 0;
    return (kPrestigeFactor * sqrt(s.lifetimeCoins / kPrestigeDivisor)).floor();
  }

  static bool canPrestige(ShelterState s) =>
      s.unlockedZones.contains(kPrestigeZoneIndex) && prestigeGain(s) > 0;

  /// "Naya Season": bank Golden Paws, reset rooms/coins/zones. Pets are kept.
  /// Returns the Golden Paws gained (0 when not eligible).
  static int doPrestige(ShelterState s) {
    if (!canPrestige(s)) return 0;
    final gained = prestigeGain(s);
    s.goldenPaws += gained;
    s.coins = 0;
    s.lifetimeCoins = 0;
    for (final room in s.rooms.values) {
      room.level = 0;
    }
    s.unlockedZones
      ..clear()
      ..add(0);
    s.tapCombo = 0;
    s.lastTapAt = null;
    return gained;
  }
}
