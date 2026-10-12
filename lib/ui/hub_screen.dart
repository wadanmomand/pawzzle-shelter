/// Cross-promo hub: the Pawzzle portfolio. Sibling games are not on the
/// Play Store yet, so cards honestly show "Coming soon" instead of dead
/// store links.
library;

import 'package:flutter/material.dart';
import 'package:shelter/ui/theme.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('More Pawzzle Games')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GameCard(
            name: 'Pawzzle Rescue: Bubble Pop',
            tagline: 'Pop bubbles, rescue pets — 2000 levels',
            icon: Icons.bubble_chart_rounded,
            color: AppColors.teal,
          ),
          SizedBox(height: 12),
          _GameCard(
            name: 'Pawzzle Smash',
            tagline: 'Slingshot physics arcade — 1000 levels',
            icon: Icons.rocket_launch_rounded,
            color: AppColors.primaryDark,
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;

  const _GameCard({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(tagline,
                    style: const TextStyle(
                        color: AppColors.textSoft, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Coming soon',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
