import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/economy.dart';

RoomDef room(String id, int zone, double cost, double income) =>
    RoomDef(id: id, zoneIndex: zone, name: id, baseCost: cost, baseIncome: income);

/// 2 zones x 2 rooms + 3 pets (one per rarity).
ShelterState makeState() {
  final s = ShelterState();
  s.registerContent(
    [
      room('dog_house', 0, 50, 1),
      room('playground', 0, 200, 3),
      room('kitten_tower', 1, 2000, 12),
      room('milk_bar', 1, 8000, 30),
    ],
    [
      const PetDef(id: 'milo', name: 'Milo', rarity: Rarity.common),
      const PetDef(id: 'luna', name: 'Luna', rarity: Rarity.rare),
      const PetDef(id: 'rocky', name: 'Rocky', rarity: Rarity.epic),
    ],
  );
  return s;
}

void main() {
  group('room costs', () {
    test('build cost equals baseCost at level 0', () {
      final s = makeState();
      expect(s.rooms['dog_house']!.nextCost, equals(50.0));
    });

    test('cost grows as baseCost * 1.22^level', () {
      final s = makeState();
      final r = s.rooms['dog_house']!;
      r.level = 5;
      expect(r.nextCost, closeTo(50 * 1.22 * 1.22 * 1.22 * 1.22 * 1.22, 1e-6));
    });

    test('buyRoom deducts coins and raises level', () {
      final s = makeState()..coins = 1000;
      expect(ShelterEconomy.buyRoom(s, 'dog_house'), isTrue);
      expect(s.rooms['dog_house']!.level, equals(1));
      expect(s.coins, closeTo(950.0, 1e-6));
    });

    test('buyRoom fails when broke and changes nothing', () {
      final s = makeState()..coins = 10;
      expect(ShelterEconomy.buyRoom(s, 'dog_house'), isFalse);
      expect(s.rooms['dog_house']!.level, equals(0));
      expect(s.coins, equals(10.0));
    });

    test('buyRoom fails at max level', () {
      final s = makeState()..coins = 1e18;
      s.rooms['dog_house']!.level = kMaxRoomLevel;
      expect(ShelterEconomy.buyRoom(s, 'dog_house'), isFalse);
      expect(s.rooms['dog_house']!.level, equals(kMaxRoomLevel));
    });
  });

  group('room income', () {
    test('unbuilt room earns nothing', () {
      final s = makeState();
      expect(ShelterEconomy.roomIncome(s, 'dog_house'), equals(0.0));
      expect(ShelterEconomy.totalIncomePerSec(s), equals(0.0));
    });

    test('income at level 1 follows 1.18 growth', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      expect(ShelterEconomy.roomIncome(s, 'dog_house'), closeTo(1.18, 1e-6));
    });

    test('milestone doubles income at level 10', () {
      final s = makeState();
      final r = s.rooms['dog_house']!;
      r.level = 9;
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      r.level = 10;
      final after = ShelterEconomy.roomIncome(s, 'dog_house');
      // growth 1.18x plus milestone 2x
      expect(after / before, closeTo(1.18 * 2.0, 1e-6));
    });

    test('common pet (happiness 0) gives exactly 1.25x', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      s.pets['milo']!.happiness = 0;
      ShelterEconomy.assignPet(s, 'milo', 'dog_house');
      expect(ShelterEconomy.roomIncome(s, 'dog_house') / before,
          closeTo(1.25, 1e-9));
    });

    test('epic pet (happiness 0) gives exactly 2.0x', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      s.pets['rocky']!.happiness = 0;
      ShelterEconomy.assignPet(s, 'rocky', 'dog_house');
      expect(ShelterEconomy.roomIncome(s, 'dog_house') / before,
          closeTo(2.0, 1e-9));
    });

    test('unassigned pet has no effect', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      expect(ShelterEconomy.roomIncome(s, 'dog_house'), equals(before));
    });

    test('happiness adds up to +25% on top of rarity', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      s.pets['milo']!.happiness = 100;
      ShelterEconomy.assignPet(s, 'milo', 'dog_house');
      final withPet = ShelterEconomy.roomIncome(s, 'dog_house');
      s.pets['milo']!.happiness = 0;
      final noHappy = ShelterEconomy.roomIncome(s, 'dog_house');
      expect(withPet / noHappy, closeTo(1.25, 1e-9));
    });

    test('zone synergy +25% only when all rooms >= L10', () {
      final s = makeState();
      s.rooms['dog_house']!.level = 10;
      s.rooms['playground']!.level = 9;
      expect(ShelterEconomy.zoneSynergyActive(s, 0), isFalse);
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      s.rooms['playground']!.level = 10;
      expect(ShelterEconomy.zoneSynergyActive(s, 0), isTrue);
      expect(ShelterEconomy.roomIncome(s, 'dog_house') / before,
          closeTo(1.25, 1e-9));
    });

    test('each Golden Paw adds +2% income', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      final before = ShelterEconomy.roomIncome(s, 'dog_house');
      s.goldenPaws = 10;
      expect(ShelterEconomy.roomIncome(s, 'dog_house') / before,
          closeTo(1.2, 1e-9));
    });
  });

  group('tick and tap', () {
    test('tick adds income*dt to coins and lifetimeCoins', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house'); // income 1.18/s
      ShelterEconomy.tick(s, const Duration(seconds: 10));
      expect(s.coins, closeTo(1000 - 50 + 11.8, 1e-6));
      expect(s.lifetimeCoins, closeTo(11.8, 1e-6));
    });

    test('tap pays at least 1 coin with zero income', () {
      final s = makeState();
      final gained = ShelterEconomy.tap(s, DateTime(2026, 1, 1));
      expect(gained, equals(1.0));
      expect(s.coins, equals(1.0));
    });

    test('tap scales with income and combo grows payout', () {
      final s = makeState()..coins = 1e6;
      // build dog_house to L10: income = 1.18^10 * 2 (milestone)
      for (var i = 0; i < 10; i++) {
        ShelterEconomy.buyRoom(s, 'dog_house');
      }
      final t0 = DateTime(2026, 1, 1);
      final first = ShelterEconomy.tap(s, t0);
      final second = ShelterEconomy.tap(s, t0.add(const Duration(seconds: 1)));
      expect(second, closeTo(first * 1.1, 1e-6));
      // after the combo window the combo resets
      final third = ShelterEconomy.tap(s, t0.add(const Duration(seconds: 10)));
      expect(third, closeTo(first, 1e-6));
    });

    test('tap combo caps at 5x', () {
      final s = makeState();
      var t = DateTime(2026, 1, 1);
      double last = 0;
      for (var i = 0; i < 100; i++) {
        t = t.add(const Duration(milliseconds: 100));
        last = ShelterEconomy.tap(s, t);
      }
      expect(last, closeTo(1.0 * kTapComboCap, 1e-9));
    });
  });

  group('offline earnings', () {
    test('offline capped at 12h at 50% efficiency', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house'); // 1.18/s
      final now = DateTime(2026, 1, 2);
      s.lastSeen = now.subtract(const Duration(hours: 16));
      final gained = ShelterEconomy.collectOffline(s, now);
      expect(gained, closeTo(1.18 * 12 * 3600 * 0.5, 1e-3));
    });

    test('short absence earns proportionally', () {
      final s = makeState()..coins = 1000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      final now = DateTime(2026, 1, 2);
      s.lastSeen = now.subtract(const Duration(hours: 2));
      final gained = ShelterEconomy.collectOffline(s, now);
      expect(gained, closeTo(1.18 * 2 * 3600 * 0.5, 1e-3));
    });

    test('first ever collect returns 0 and stamps lastSeen', () {
      final s = makeState();
      final now = DateTime(2026, 1, 2);
      expect(ShelterEconomy.collectOffline(s, now), equals(0.0));
      expect(s.lastSeen, equals(now));
    });
  });

  group('pets', () {
    test('feedPet consumes a treat and raises happiness', () {
      final s = makeState()..treats = 3;
      s.pets['milo']!.happiness = 50;
      expect(ShelterEconomy.feedPet(s, 'milo'), isTrue);
      expect(s.treats, equals(2.0));
      expect(s.pets['milo']!.happiness, equals(75.0));
    });

    test('feedPet caps happiness at 100', () {
      final s = makeState()..treats = 5;
      s.pets['milo']!.happiness = 90;
      ShelterEconomy.feedPet(s, 'milo');
      expect(s.pets['milo']!.happiness, equals(100.0));
    });

    test('feedPet fails with no treats', () {
      final s = makeState();
      expect(ShelterEconomy.feedPet(s, 'milo'), isFalse);
    });
  });

  group('zones', () {
    test('unlockZone enforces coin cost and pet count', () {
      final s = makeState()..coins = 10000;
      const zone = ZoneDef(index: 1, name: 'Kitten Cove', coinCost: 5000, requiredPets: 5);
      expect(ShelterEconomy.unlockZone(s, zone), isFalse); // only 3 pets
      expect(s.unlockedZones.contains(1), isFalse);
      const easy = ZoneDef(index: 1, name: 'Kitten Cove', coinCost: 5000, requiredPets: 2);
      expect(ShelterEconomy.unlockZone(s, easy), isTrue);
      expect(s.coins, equals(5000.0));
      expect(s.unlockedZones.contains(1), isTrue);
      expect(ShelterEconomy.unlockZone(s, easy), isFalse); // already unlocked
    });
  });

  group('prestige', () {
    test('prestigeGain follows floor(10 * sqrt(lifetime / 1e9))', () {
      final s = makeState()..lifetimeCoins = 4e9;
      expect(ShelterEconomy.prestigeGain(s), equals(20));
    });

    test('no gain below the lifetime threshold', () {
      final s = makeState()..lifetimeCoins = 5e8;
      expect(ShelterEconomy.prestigeGain(s), equals(0));
    });

    test('canPrestige needs zone 5 and enough lifetime coins', () {
      final s = makeState()..lifetimeCoins = 4e9;
      expect(ShelterEconomy.canPrestige(s), isFalse);
      s.unlockedZones.add(4);
      expect(ShelterEconomy.canPrestige(s), isTrue);
    });

    test('doPrestige banks paws, resets rooms/coins/zones, keeps pets', () {
      final s = makeState()
        ..coins = 999
        ..treats = 5
        ..goldenPaws = 3
        ..lifetimeCoins = 4e9;
      s.unlockedZones.addAll([1, 4]);
      s.rooms['dog_house']!.level = 20;
      ShelterEconomy.assignPet(s, 'milo', 'dog_house');

      final gained = ShelterEconomy.doPrestige(s);
      expect(gained, equals(20));
      expect(s.goldenPaws, equals(23.0));
      expect(s.coins, equals(0.0));
      expect(s.lifetimeCoins, equals(0.0));
      expect(s.rooms['dog_house']!.level, equals(0));
      expect(s.unlockedZones, equals({0}));
      expect(s.pets.length, equals(3)); // pets kept
      expect(s.pets['milo']!.assignedRoomId, equals('dog_house'));
      expect(s.treats, equals(5.0)); // treats kept
    });

    test('doPrestige returns 0 when not eligible', () {
      final s = makeState();
      expect(ShelterEconomy.doPrestige(s), equals(0));
      expect(s.goldenPaws, equals(0.0));
    });
  });

  group('save / load', () {
    test('roundtrip preserves full state', () {
      final s = makeState()
        ..coins = 1234.5
        ..treats = 7
        ..goldenPaws = 3
        ..lifetimeCoins = 9e8;
      s.coins = 2000;
      ShelterEconomy.buyRoom(s, 'dog_house');
      ShelterEconomy.buyRoom(s, 'dog_house');
      s.pets['luna']!.happiness = 80;
      ShelterEconomy.assignPet(s, 'luna', 'kitten_tower');
      s.unlockedZones.add(1);
      s.lastSeen = DateTime(2026, 5, 5, 12);

      final roomDefs = {for (final r in s.rooms.values) r.def.id: r.def};
      final petDefs = {for (final p in s.pets.values) p.def.id: p.def};
      final loaded = ShelterState.fromJson(s.toJson(), roomDefs, petDefs);

      expect(loaded.coins, closeTo(s.coins, 1e-9));
      expect(loaded.treats, equals(7.0));
      expect(loaded.goldenPaws, equals(3.0));
      expect(loaded.lifetimeCoins, equals(9e8));
      expect(loaded.rooms['dog_house']!.level, equals(2));
      expect(loaded.pets['luna']!.assignedRoomId, equals('kitten_tower'));
      expect(loaded.pets['luna']!.happiness, equals(80.0));
      expect(loaded.unlockedZones, equals({0, 1}));
      expect(loaded.lastSeen, equals(DateTime(2026, 5, 5, 12)));
      // economy still works after load
      expect(
        ShelterEconomy.totalIncomePerSec(loaded),
        closeTo(ShelterEconomy.totalIncomePerSec(s), 1e-9),
      );
    });
  });
}
