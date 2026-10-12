/// Riverpod game state: loads content, owns the mutable [ShelterState] and
/// [MissionBoard], ticks the economy, persists to Hive, and exposes player
/// actions.
///
/// The engine objects stay mutable internally; every action finishes with
/// [GameData.bump] so widgets rebuild on a fresh identity.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/ads/ad_service.dart';
import 'package:shelter/audio/sfx.dart';
import 'package:shelter/core/content.dart';
import 'package:shelter/core/daily.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/missions.dart';
import 'package:shelter/state/save.dart';

/// The tutorial pet gets a 60-second first mission instead of 2 hours.
const String kTutorialPetId = 'puppy_milo';
const Duration kTutorialMission = Duration(seconds: 60);

/// Auto-tapper booster length granted by a rewarded ad.
const Duration kAutoTapperLength = Duration(hours: 4);

/// Save to disk every N ticks (tick = 500ms).
const int kSaveEveryTicks = 20;

final contentProvider = FutureProvider<ContentBundle>((ref) async {
  final raw = await rootBundle.loadString('assets/content/content.json');
  return ContentBundle.fromJsonString(raw);
});

/// Overridden in main() with the opened Hive box; tests inject a temp-dir one.
final saveServiceProvider =
    Provider<SaveService>((ref) => throw UnimplementedError(
        'saveServiceProvider must be overridden'));

class GameData {
  final ContentBundle? content;
  final ShelterState? shelter;
  final MissionBoard? missions;
  final int selectedZone;
  final DailyState daily;
  final bool musicOn;
  final bool sfxOn;
  final DateTime? autoTapperUntil;

  GameData._({
    this.content,
    this.shelter,
    this.missions,
    this.selectedZone = 0,
    DailyState? daily,
    this.musicOn = true,
    this.sfxOn = true,
    this.autoTapperUntil,
  }) : daily = daily ?? DailyState();

  factory GameData.loading() => GameData._();

  factory GameData.ready(ContentBundle c) {
    final shelter = ShelterState()
      ..registerContent(c.rooms.values, c.pets.values)
      // starter coins so the FTUE can build the first room immediately
      ..coins = 100;
    return GameData._(content: c, shelter: shelter, missions: MissionBoard());
  }

  bool get ready => content != null && shelter != null && missions != null;

  bool get autoTapperActive =>
      autoTapperUntil != null && DateTime.now().isBefore(autoTapperUntil!);

  GameData bump() => GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: selectedZone,
        daily: daily,
        musicOn: musicOn,
        sfxOn: sfxOn,
        autoTapperUntil: autoTapperUntil,
      );

  GameData withZone(int z) => GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: z,
        daily: daily,
        musicOn: musicOn,
        sfxOn: sfxOn,
        autoTapperUntil: autoTapperUntil,
      );

  GameData withSettings(
          {bool? musicOn, bool? sfxOn, DateTime? autoTapperUntil}) =>
      GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: selectedZone,
        daily: daily,
        musicOn: musicOn ?? this.musicOn,
        sfxOn: sfxOn ?? this.sfxOn,
        autoTapperUntil: autoTapperUntil ?? this.autoTapperUntil,
      );

  GameData clearAutoTapper() => GameData._(
        content: content,
        shelter: shelter,
        missions: missions,
        selectedZone: selectedZone,
        daily: daily,
        musicOn: musicOn,
        sfxOn: sfxOn,
      );
}

class GameNotifier extends Notifier<GameData> {
  Timer? _timer;
  int _ticksSinceSave = 0;

  /// Transient: offline earnings collected at startup (welcome-back dialog).
  double? pendingOffline;

  /// Transient: today's daily reward (daily dialog).
  DailyReward? pendingDaily;

  @override
  GameData build() {
    // NOTE: onDispose must not touch state/ref (Riverpod forbids it).
    // Persistence is covered by the throttled tick-save + saveNow() on
    // app pause (MainScaffold lifecycle observer).
    ref.onDispose(() => _timer?.cancel());
    ref.listen<AsyncValue<ContentBundle>>(contentProvider, (_, next) {
      next.whenData(_onContentReady);
    });
    return GameData.loading();
  }

  GameData? get _d => state.ready ? state : null;

  void _onContentReady(ContentBundle c) {
    _timer?.cancel();
    pendingOffline = null;
    pendingDaily = null;

    GameData data = GameData.ready(c);
    final raw = ref.read(saveServiceProvider).read();
    if (raw != null) {
      try {
        data = _restore(c, raw);
      } catch (_) {
        data = GameData.ready(c); // corrupted save -> fresh start
      }
    }

    // offline earnings since last seen
    final gained =
        ShelterEconomy.collectOffline(data.shelter!, DateTime.now());
    if (gained > 1) pendingOffline = gained;

    // today's daily reward
    if (dailyClaimable(data.daily, DateTime.now())) {
      pendingDaily = previewDaily(data.daily, DateTime.now());
    }

    // apply saved audio prefs
    Sfx.musicEnabled = data.musicOn;
    Sfx.sfxEnabled = data.sfxOn;

    state = data;
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _onTick(),
    );
    if (data.musicOn) Sfx.startMusic();
  }

  GameData _restore(ContentBundle c, String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final roomDefs = {for (final e in c.rooms.entries) e.key: e.value};
    final petDefs = {for (final e in c.pets.entries) e.key: e.value};
    final shelter = ShelterState.fromJson(
      (j['shelter'] as Map).cast<String, dynamic>(),
      roomDefs,
      petDefs,
    );
    final missions = MissionBoard.fromJson(
      (j['missions'] as Map).cast<String, dynamic>(),
    );
    final dj = (j['daily'] as Map?)?.cast<String, dynamic>();
    final daily = DailyState(
      lastClaim: dj?['lastClaim'] as String?,
      streak: (dj?['streak'] as num?)?.toInt() ?? 0,
    );
    DateTime? autoTapperUntil;
    final atu = j['autoTapperUntil'] as String?;
    if (atu != null) {
      final parsed = DateTime.tryParse(atu);
      if (parsed != null && parsed.isAfter(DateTime.now())) {
        autoTapperUntil = parsed;
      }
    }
    return GameData._(
      content: c,
      shelter: shelter,
      missions: missions,
      daily: daily,
      musicOn: (j['musicOn'] as bool?) ?? true,
      sfxOn: (j['sfxOn'] as bool?) ?? true,
      autoTapperUntil: autoTapperUntil,
    );
  }

  void _onTick() {
    var d = _d;
    if (d == null) return;
    ShelterEconomy.tick(d.shelter!, const Duration(milliseconds: 500));
    // auto-tapper: silent tap-value every tick while active
    if (d.autoTapperUntil != null) {
      if (DateTime.now().isBefore(d.autoTapperUntil!)) {
        final v = max(
            1.0, ShelterEconomy.totalIncomePerSec(d.shelter!) * kTapIncomeFraction);
        d.shelter!.coins += v;
        d.shelter!.lifetimeCoins += v;
      } else {
        d = d.clearAutoTapper();
      }
    }
    _ticksSinceSave++;
    if (_ticksSinceSave >= kSaveEveryTicks) {
      _ticksSinceSave = 0;
      saveNow();
    }
    state = d.bump();
  }

  // -- persistence -------------------------------------------------------

  void saveNow() {
    final d = _d;
    if (d == null) return;
    final j = {
      'shelter': d.shelter!.toJson(),
      'missions': d.missions!.toJson(),
      'daily': {
        'lastClaim': d.daily.lastClaim,
        'streak': d.daily.streak,
      },
      'musicOn': d.musicOn,
      'sfxOn': d.sfxOn,
      'autoTapperUntil': d.autoTapperUntil?.toIso8601String(),
    };
    ref.read(saveServiceProvider).write(jsonEncode(j));
  }

  Future<void> resetProgress() async {
    final d = _d;
    if (d == null) return;
    await ref.read(saveServiceProvider).clear();
    pendingOffline = null;
    pendingDaily = null;
    state = GameData.ready(d.content!);
    saveNow();
  }

  // -- transient dialogs ---------------------------------------------------

  /// Returns pending offline earnings and clears them.
  double? takePendingOffline() {
    final v = pendingOffline;
    pendingOffline = null;
    return v;
  }

  /// Grants another [amount] coins (welcome-back "double" rewarded ad).
  void grantOfflineBonus(double amount) {
    final d = _d;
    if (d == null) return;
    d.shelter!.coins += amount;
    d.shelter!.lifetimeCoins += amount;
    Sfx.milestone();
    state = d.bump();
    saveNow();
  }

  DailyReward? takePendingDaily() {
    final r = pendingDaily;
    pendingDaily = null;
    return r;
  }

  /// Claims today's daily reward. Returns it, or null when already claimed.
  DailyReward? claimDailyReward() {
    final d = _d;
    if (d == null) return null;
    final reward = claimDaily(d.daily, DateTime.now());
    if (reward == null) return null;
    if (reward.kind == 'coins') {
      d.shelter!.coins += reward.amount;
      d.shelter!.lifetimeCoins += reward.amount;
    } else {
      d.shelter!.treats += reward.amount;
    }
    Sfx.milestone();
    saveNow();
    state = d.bump();
    return reward;
  }

  // -- settings ----------------------------------------------------------

  void setMusicOn(bool v) {
    final d = _d;
    if (d == null) return;
    Sfx.musicEnabled = v;
    if (v) {
      Sfx.startMusic();
    } else {
      Sfx.stopMusic();
    }
    state = d.withSettings(musicOn: v);
    saveNow();
  }

  void setSfxOn(bool v) {
    final d = _d;
    if (d == null) return;
    Sfx.sfxEnabled = v;
    state = d.withSettings(sfxOn: v);
    saveNow();
  }

  /// Granted after a rewarded ad: 4h of auto-tapping.
  void startAutoTapper() {
    final d = _d;
    if (d == null) return;
    state = d.withSettings(
        autoTapperUntil: DateTime.now().add(kAutoTapperLength));
    Sfx.upgrade();
    saveNow();
  }

  // -- core actions ---------------------------------------------------------

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
      AdService.instance.maybeShowInterstitial();
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
    final ok = d.missions!
        .start(petId, pet.rarity, DateTime.now(), duration: duration);
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

  /// Granted after a rewarded ad (e.g. "+5 treats").
  void grantTreats(double amount) {
    final d = _d;
    if (d == null) return;
    d.shelter!.treats += amount;
    Sfx.milestone();
    state = d.bump();
    saveNow();
  }

  /// Mission instant-finish paid by a rewarded ad instead of treats.
  bool instantFinishFree(String petId) {
    final d = _d;
    if (d == null) return false;
    final ok = d.missions!.finishNow(petId);
    if (ok) {
      Sfx.rescue();
      state = d.bump();
      saveNow();
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
      AdService.instance.maybeShowInterstitial();
    }
    return gained;
  }
}

final gameProvider =
    NotifierProvider<GameNotifier, GameData>(GameNotifier.new);
