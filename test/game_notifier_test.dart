// Riverpod integration: boots the notifier with real content, plays the
// FTUE loop, and verifies save/load roundtrips through Hive.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/content.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/state/save.dart';

ContentBundle loadTestBundle() {
  final raw = File('assets/content/content.json').readAsStringSync();
  return ContentBundle.fromJsonString(raw);
}

void main() {
  late Directory tmp;
  late SaveService save;
  late ContentBundle bundle;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('shelter_notifier_test');
    save = await SaveService.open(tmp.path);
    bundle = loadTestBundle();
  });

  tearDownAll(() async {
    await save.close();
    await tmp.delete(recursive: true);
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        contentProvider.overrideWith((ref) => Future.value(bundle)),
        saveServiceProvider.overrideWithValue(save),
      ],
    );
  }

  Future<GameNotifier> pumpReady(ProviderContainer container) async {
    expect(container.read(gameProvider).ready, isFalse);
    await container.read(contentProvider.future);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final notifier = container.read(gameProvider.notifier);
    expect(container.read(gameProvider).ready, isTrue);
    return notifier;
  }

  test('notifier boots and plays the FTUE loop', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = await pumpReady(container);

    var data = container.read(gameProvider);
    // starter coins (a tick may have added a little)
    expect(data.shelter!.coins, inInclusiveRange(100, 200));

    // build the first room (Dog House, 50 coins)
    expect(notifier.buyRoom('z0r0'), isTrue);
    data = container.read(gameProvider);
    expect(data.shelter!.rooms['z0r0']!.level, equals(1));

    // tap earns coins
    final before = data.shelter!.coins;
    final gained = notifier.tap();
    expect(gained, greaterThan(0));
    data = container.read(gameProvider);
    expect(data.shelter!.coins, greaterThan(before));

    // tutorial mission: milo is a 60s mission on a fresh board
    expect(notifier.startMission('puppy_milo'), isTrue);
    expect(notifier.startMission('puppy_coco'), isTrue);
    expect(notifier.startMission('puppy_biscuit'), isTrue);
    expect(notifier.startMission('puppy_buddy'), isFalse); // 3 max
    // not ready yet
    expect(notifier.claimMission('puppy_milo'), isFalse);

    // treats: instant finish + feed
    data.shelter!.treats = 4;
    expect(notifier.instantFinish('puppy_coco'), isTrue);
    data = container.read(gameProvider);
    expect(data.missions!.rescued, contains('puppy_coco'));

    // assign + feed the rescued pet
    notifier.assignPet('puppy_coco', 'z0r0');
    data = container.read(gameProvider);
    expect(data.shelter!.pets['puppy_coco']!.assignedRoomId, equals('z0r0'));
    expect(notifier.feedPet('puppy_coco'), isTrue);

    // auto-tapper + settings toggles
    notifier.startAutoTapper();
    data = container.read(gameProvider);
    expect(data.autoTapperActive, isTrue);
    notifier.setMusicOn(false);
    notifier.setSfxOn(false);
    data = container.read(gameProvider);
    expect(data.musicOn, isFalse);
    expect(data.sfxOn, isFalse);
    notifier.setMusicOn(true);
    notifier.setSfxOn(true);

    // daily reward claimable on a fresh save
    final reward = notifier.claimDailyReward();
    expect(reward, isNotNull);
    expect(reward!.day, equals(1));

    // zone select + unlock guard (zone 1 needs 5000 coins + 2 pets)
    notifier.selectZone(0);
    data = container.read(gameProvider);
    expect(data.selectedZone, equals(0));
    expect(notifier.unlockZone(1), isFalse);
  });

  test('save/load roundtrip restores progress', () async {
    await save.clear(); // self-contained: ignore test 1's save
    final container = makeContainer();
    addTearDown(container.dispose);
    final notifier = await pumpReady(container);

    // play a little (grant coins: two upgrades cost 50 + 61)
    container.read(gameProvider).shelter!.coins = 10000;
    notifier.buyRoom('z0r0');
    notifier.buyRoom('z0r0');
    notifier.startAutoTapper();
    notifier.saveNow();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final coinsBefore = container.read(gameProvider).shelter!.coins;

    // fresh container, same save box
    final container2 = makeContainer();
    addTearDown(container2.dispose);
    final notifier2 = await pumpReady(container2);
    final data2 = container2.read(gameProvider);
    expect(data2.shelter!.rooms['z0r0']!.level, equals(2));
    expect(data2.autoTapperActive, isTrue);
    // coins: restored + tiny offline earnings for the elapsed moment
    expect(data2.shelter!.coins, greaterThanOrEqualTo(coinsBefore - 1));
    // daily not claimed yet in this fresh save → pending daily available
    expect(notifier2.takePendingDaily(), isNotNull);
  });
}
