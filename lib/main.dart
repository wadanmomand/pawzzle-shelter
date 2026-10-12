/// Pawzzle Shelter — Phase 3: playable idle game shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/home_screen.dart';
import 'package:shelter/ui/missions_screen.dart';
import 'package:shelter/ui/pets_screen.dart';
import 'package:shelter/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PawzzleShelterApp()));
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
              Icon(Icons.pets_rounded,
                  size: 72, color: AppColors.primaryDark),
              SizedBox(height: 12),
              Text('Pawzzle Shelter',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
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

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    PetsScreen(),
    MissionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _tab, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
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
    );
  }
}
