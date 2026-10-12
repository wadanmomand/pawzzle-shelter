/// Pawzzle Shelter — Phase 4: persistence, ads, daily rewards, hub.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelter/ads/ad_service.dart';
import 'package:shelter/ads/banner_ad_widget.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/state/save.dart';
import 'package:shelter/ui/home_screen.dart';
import 'package:shelter/ui/missions_screen.dart';
import 'package:shelter/ui/pets_screen.dart';
import 'package:shelter/ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final save = await SaveService.open(docs.path);
  runApp(
    ProviderScope(
      overrides: [
        saveServiceProvider.overrideWithValue(save),
      ],
      child: const PawzzleShelterApp(),
    ),
  );
  // Ads init is async and safe to start after the first frame.
  AdService.instance.init();
}

class PawzzleShelterApp extends StatelessWidget {
  const PawzzleShelterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pawzzle Shelter',
      theme: shelterTheme(),
      debugShowCheckedModeBanner: false,
      home: const GameRoot(),
    );
  }
}

class GameRoot extends ConsumerWidget {
  const GameRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameProvider);
    if (!data.ready) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_rounded, size: 72, color: AppColors.primaryDark),
              SizedBox(height: 12),
              Text('Pawzzle Shelter',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              SizedBox(height: 8),
              CircularProgressIndicator(color: AppColors.primaryDark),
            ],
          ),
        ),
      );
    }
    return const MainScaffold();
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  int _tab = 0;
  bool _dialogsShown = false;

  static const _screens = [
    HomeScreen(),
    PetsScreen(),
    MissionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartupDialogs());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(gameProvider.notifier).saveNow();
    } else if (state == AppLifecycleState.resumed) {
      AdService.instance.showAppOpenIfReady();
    }
  }

  Future<void> _showStartupDialogs() async {
    if (_dialogsShown || !mounted) return;
    _dialogsShown = true;
    final notifier = ref.read(gameProvider.notifier);

    final offline = notifier.takePendingOffline();
    if (offline != null && offline > 1 && mounted) {
      await _welcomeBackDialog(notifier, offline);
    }
    if (mounted) await _dailyDialog(notifier);
  }

  Future<void> _welcomeBackDialog(GameNotifier notifier, double amount) async {
    var doubled = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Welcome back!',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          'While you were away your shelter earned\n${formatCompact(amount)} coins.',
          style: const TextStyle(color: AppColors.textSoft),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Collect',
                style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              final earned = await AdService.instance.showRewarded();
              if (earned) doubled = true;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: const Text('2x with ad'),
          ),
        ],
      ),
    );
    if (doubled) {
      notifier.grantOfflineBonus(amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Doubled! +${formatCompact(amount)} bonus coins')),
        );
      }
    }
  }

  Future<void> _dailyDialog(GameNotifier notifier) async {
    final reward = notifier.takePendingDaily();
    if (reward == null) return;
    final claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Day ${reward.day} reward',
            style: const TextStyle(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reward.kind == 'coins'
                  ? Icons.monetization_on_rounded
                  : Icons.cookie_rounded,
              size: 56,
              color: reward.kind == 'coins'
                  ? AppColors.gold
                  : AppColors.primaryDark,
            ),
            const SizedBox(height: 8),
            Text(
              '+${formatCompact(reward.amount)} ${reward.kind}',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (claimed == true) {
      final r = notifier.claimDailyReward();
      if (r != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Day ${r.day} claimed: +${formatCompact(r.amount)} ${r.kind}!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: _screens),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BannerAdWidget(),
          NavigationBar(            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: AppColors.surface,
            indicatorColor: const Color(0xFFFFE3D3),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: 'Shelter',
              ),
              NavigationDestination(
                icon: Icon(Icons.pets_rounded),
                label: 'Pets',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Rescue',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
