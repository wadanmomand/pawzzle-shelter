/// Pawzzle Shelter visual tokens (from the v3 hybrid DESIGN.md).
library;

import 'package:flutter/material.dart';
import 'package:shelter/core/economy.dart';

class AppColors {
  static const bg = Color(0xFFFFF6EC);
  static const surface = Colors.white;
  static const primary = Color(0xFFFF8A65);
  static const primaryDark = Color(0xFFF46B45);
  static const teal = Color(0xFF4DB6AC);
  static const gold = Color(0xFFFFD54F);
  static const textDark = Color(0xFF4E342E);
  static const textSoft = Color(0xFFA1887F);
  static const cardShadow = Color(0x1A4E342E);
}

Color rarityColor(Rarity r) => switch (r) {
      Rarity.common => const Color(0xFF9E9E9E),
      Rarity.rare => const Color(0xFF42A5F5),
      Rarity.epic => const Color(0xFFAB47BC),
    };

String rarityLabel(Rarity r) => switch (r) {
      Rarity.common => 'Common',
      Rarity.rare => 'Rare',
      Rarity.epic => 'Epic',
    };

ThemeData shelterTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primaryDark,
      surface: AppColors.surface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      foregroundColor: AppColors.textDark,
    ),
  );
}
