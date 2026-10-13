/// Shared UI widgets: currency pills, room cards, upgrade buttons.
library;

import 'package:flutter/material.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/ui/anim.dart';
import 'package:shelter/ui/theme.dart';

class CurrencyPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const CurrencyPill({
    super.key,
    required this.icon,
    required this.text,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          AnimatedNumber(text: text),
        ],
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  final RoomState room;
  final double incomePerSec;
  final double coins;
  final VoidCallback onUpgrade;

  const RoomCard({
    super.key,
    required this.room,
    required this.incomePerSec,
    required this.coins,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final def = room.def;
    final level = room.level;
    final isBuilt = room.isBuilt;
    final isMaxed = room.isMaxed;
    final cost = room.nextCost;
    final affordable = !isMaxed && coins >= cost;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.home_rounded,
                color: AppColors.primaryDark, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBuilt
                      ? 'Lv $level  •  ${formatCompact(incomePerSec)}/s'
                      : 'Not built yet',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSoft,
                  ),
                ),
                if (isBuilt && !isMaxed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: level / kMaxRoomLevel,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF3E5DC),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.teal),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _UpgradeButton(
            label: isMaxed ? 'MAX' : (isBuilt ? 'Lv ${level + 1}' : 'Build'),
            cost: isMaxed ? null : cost,
            affordable: affordable,
            onTap: onUpgrade,
          ),
        ],
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final String label;
  final double? cost;
  final bool affordable;
  final VoidCallback onTap;

  const _UpgradeButton({
    required this.label,
    required this.cost,
    required this.affordable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = affordable && cost != null;
    return BounceButton(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled || cost == null ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: enabled ? null : const Color(0xFFF3E5DC),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: enabled ? Colors.white : AppColors.textSoft,
                ),
              ),
              if (cost != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 12,
                      color: enabled ? Colors.white : AppColors.textSoft,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      formatCompact(cost!),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: enabled ? Colors.white : AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
