/// Riverpod game state: loads content, owns the mutable [ShelterState] and
/// [MissionBoard], ticks the economy, and exposes player actions.
///
/// The engine objects stay mutable internally; every action finishes with
/// [GameData.bump] so widgets rebuild on a fresh identity.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/audio/sfx.dart';
import 'package:shelter/core/content.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/missions.dart';

/// The tutorial pet gets a 60-second first mission instead of 2 hours.
const String kTutorialPetId = 'puppy_milo';
const Duration kTutorialMission = Duration(seconds: 60);

final contentProvider = FutureProvider<ContentBundle>((ref) async {
  final raw = await rootBundle.loadString('assets/content/content.json');
  return ContentBundle.fromJsonString(raw);
});

class GameData {
  final ContentBundle? content;
  final ShelterState? shelter;
  final MissionBoard? missions;
  final int selectedZone;

  const GameData._({this.content, this.shelter, this.missions, this.selectedZone = 0});

  factory GameData.loading() => const GameData._();

  factory GameData.ready(ContentBundle c) {
    final shelter = ShelterState()
      ..registerContent(c.rooms.values, c.pets.values)
      // starter coins so the FTUE can build the first room immediately
      ..coins = 100;
    return GameData._(content: c, shelter: shelter, missions: MissionBoard());
  }

  bool get ready => content != null && shelter != null && missions != null;

  GameData bump() => GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: selectedZone,
      );

  GameData withZone(int z) => GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: z,
      );
}

class GameNotifier extends Notifier<GameData> {
  Timer? _timer;

  @override
  GameData build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen<AsyncValue<ContentBundle>>(contentProvider, (_, next) {
      next.whenData((c) {
        _timer?.cancel();
        state = GameData.ready(c);
        _timer = Timer.periodic(
          const Duration(milliseconds: 500),
          (_) => _onTick(),
        );
        Sfx.startMusic();
      });
    });
    return GameData.loading();
  }

  GameData? get _d => state.ready ? state : null;

  void _onTick() {
    final d = _d;
    if (d == null) return;
    ShelterEconomy.tick(d.shelter!, const Duration(milliseconds: 500));
    state = d.bump();
  }

  // -- actions -----------------------------------------------------------

  bool buyRoom(String roomId) {
    final d = _d;
    if (d == null) return false;
    final ok = ShelterEconomy.buyRoom(d.shelter!, roomId);
    if (ok) {
      final level = d.shelter!.rooms[roomId]!.level;
      if (kMilestoneLevels.contains(level)) {
        Sfx.milestone();
      } else {
        Sfx.upgrade();
      }
      state = d.bump();
    }
    return ok;
  }

  /// Active tap. Returns coins gained (for the floating "+N" effect).
  double tap() {
    final d = _d;
    if (d == null) return 0;
    final gained = ShelterEconomy.tap(d.shelter!, DateTime.now());
    Sfx.coin();
    state = d.bump();
    return gained;
  }

  void selectZone(int z) {
    final d = _d;
    if (d == null) return;
    Sfx.click();
    state = d.withZone(z);
  }

  bool unlockZone(int z) {
    final d = _d;
    if (d == null || z < 0 || z >= d.content!.zones.length) return false;
    final ok = ShelterEconomy.unlockZone(d.shelter!, d.content!.zones[z]);
    if (ok) {
      Sfx.zoneUnlock();
      state = d.withZone(z);
    }
    return ok;
  }

  bool startMission(String petId) {
    final d = _d;
    if (d == null) return false;
    final pet = d.content!.pets[petId];
    if (pet == null) return false;
    final duration = (petId == kTutorialPetId && d.missions!.rescued.isEmpty)
        ? kTutorialMission
        : null;
    final ok = d.missions!.start(petId, pet.rarity, DateTime.now(),
        duration: duration);
    if (ok) {
      Sfx.click();
      state = d.bump();
    }
    return ok;
  }

  bool claimMission(String petId) {
    final d = _d;
    if (d == null) return false;
    final ok = d.missions!.claim(petId, DateTime.now());
    if (ok) {
      Sfx.rescue();
      state = d.bump();
    }
    return ok;
  }

  bool instantFinish(String petId) {
    final d = _d;
    if (d == null) return false;
    final pet = d.content!.pets[petId];
    if (pet == null) return false;
    final cost = instantFinishCost(pet.rarity);
    if (d.shelter!.treats < cost) return false;
    final ok = d.missions!.finishNow(petId);
    if (ok) {
      d.shelter!.treats -= cost;
      Sfx.rescue();
      state = d.bump();
    }
    return ok;
  }

  void assignPet(String petId, String? roomId) {
    final d = _d;
    if (d == null) return;
    ShelterEconomy.assignPet(d.shelter!, petId, roomId);
    Sfx.click();
    state = d.bump();
  }

  bool feedPet(String petId) {
    final d = _d;
    if (d == null) return false;
    final ok = ShelterEconomy.feedPet(d.shelter!, petId);
    if (ok) {
      Sfx.click();
      state = d.bump();
    }
    return ok;
  }

  /// Returns Golden Paws gained (0 when not eligible).
  int doPrestige() {
    final d = _d;
    if (d == null) return 0;
    final gained = ShelterEconomy.doPrestige(d.shelter!);
    if (gained > 0) {
      Sfx.prestige();
      state = d.withZone(0);
    }
    return gained;
  }
}

final gameProvider =
    NotifierProvider<GameNotifier, GameData>(GameNotifier.new);
