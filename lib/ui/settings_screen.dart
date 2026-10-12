/// Settings: audio toggles, cross-promo hub link, reset progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelter/state/game.dart';
import 'package:shelter/ui/nav.dart';
import 'package:shelter/ui/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gameProvider);
    final notifier = ref.read(gameProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            SwitchListTile(
              title: const Text('Music',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              value: data.musicOn,
              activeThumbColor: AppColors.primaryDark,
              onChanged: notifier.setMusicOn,
            ),
            SwitchListTile(
              title: const Text('Sound effects',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              value: data.sfxOn,
              activeThumbColor: AppColors.primaryDark,
              onChanged: notifier.setSfxOn,
            ),
          ]),
          const SizedBox(height: 12),
          _card([
            ListTile(
              leading: const Icon(Icons.videogame_asset_rounded,
                  color: AppColors.primaryDark),
              title: const Text('More Pawzzle Games',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Bubble Pop, Smash and more'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => openHub(context),
            ),
          ]),
          const SizedBox(height: 12),
          _card([
            ListTile(
              leading:
                  const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Reset progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.red)),
              subtitle: const Text('Deletes your shelter forever'),
              onTap: () => _confirmReset(context, notifier),
            ),
          ]),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Pawzzle Shelter • ads in this build are test ads',
              style: TextStyle(color: AppColors.textSoft, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  void _confirmReset(BuildContext context, GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset everything?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
          'Coins, rooms, pets and progress will be gone forever.',
          style: TextStyle(color: AppColors.textSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSoft)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.resetProgress();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
