// Riverpod integration: boots the notifier with real content and plays
// the FTUE loop (buy room, tap, rescue mission).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelter/core/content.dart';
import 'package:shelter/state/game.dart';

ContentBundle loadTestBundle() {
  final raw = File('assets/content/content.json').readAsStringSync();
  return ContentBundle.fromJsonString(raw);
}

void main() {
  test('notifier boots and plays the FTUE loop', () async {
    final bundle = loadTestBundle();
    final container = ProviderContainer(
      overrides: [
        contentProvider.overrideWith((ref) => Future.value(bundle)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(gameProvider).ready, isFalse);
    await container.read(contentProvider.future);
    // let the ref.listen callback run
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(gameProvider.notifier);
    var data = container.read(gameProvider);
    expect(data.ready, isTrue);
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

    // feed needs treats — grant some like rewarded ads would
    data.shelter!.treats = 4;
    expect(notifier.instantFinish('puppy_coco'), isTrue);
    data = container.read(gameProvider);
    expect(data.missions!.rescued, contains('puppy_coco'));

    // assign + feed the rescued pet
    notifier.assignPet('puppy_coco', 'z0r0');
    data = container.read(gameProvider);
    expect(data.shelter!.pets['puppy_coco']!.assignedRoomId, equals('z0r0'));
    expect(notifier.feedPet('puppy_coco'), isTrue);

    // zone select + unlock guard (zone 1 needs 5000 coins + 2 pets)
    notifier.selectZone(0);
    data = container.read(gameProvider);
    expect(data.selectedZone, equals(0));
    expect(notifier.unlockZone(1), isFalse);
  });
}
