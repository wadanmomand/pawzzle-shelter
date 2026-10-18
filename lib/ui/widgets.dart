/// Shared UI widgets: currency pills, room cards, upgrade buttons.
library;

import 'package:flutter/material.dart';
import 'package:shelter/core/economy.dart';
import 'package:shelter/core/format.dart';
import 'package:shelter/ui/anim.dart';
import 'package:shelter/ui/theme.dart';

class CurrencyPill extends StatelessWidget {
  final IconData? icon;
  final String? asset;
  final String text;
  final Color iconColor;

  const CurrencyPill({
    super.key,
    this.icon,
    this.asset,
    required this.text,
    required this.iconColor,
  }) : assert(icon != null || asset != null);

  @override
  Widget build(BuildContext context) {
    final big = asset != null;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: big ? 14 : 10, vertical: big ? 10 : 6),
      decoration: BoxDecoration(
        color: big ? const Color(0xFFFFF3D6) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: big ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (asset != null)
            Image.asset(asset!, width: 32, height: 32, fit: BoxFit.contain)
          else
            Icon(icon, size: 16, color: iconColor),
          SizedBox(width: big ? 8 : 4),
          AnimatedNumber(
            text: text,
            style: big
                ? const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    color: AppColors.textDark,
                  )
                : null,
          ),
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
        borderRadius: BorderRadius.circular(20),
        border: isBuilt
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/zones/zone-${def.zoneIndex}.png',
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 62,
                height: 62,
                color: const Color(0xFFFFF1E6),
                child: const Icon(Icons.home_rounded,
                    color: AppColors.primaryDark, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isBuilt
                      ? 'Level $level  •  ${formatCompact(incomePerSec)}/s'
                      : 'Not built yet',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
                if (isBuilt)
                  Text(
                    '+${formatCompact(incomePerSec)} gold/sec',
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
            label: isMaxed ? 'MAX' : (isBuilt ? 'UPGRADE Lv${level + 1}' : 'BUILD'),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFF8A65), Color(0xFFF46B45)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: enabled ? null : const Color(0xFFF3E5DC),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 6,
                  offset: Offset(0, 3))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: enabled ? Colors.white : AppColors.textSoft,
                ),
              ),
              if (cost != null) ...[
                const SizedBox(width: 6),
                Image.asset(
                  'assets/zones/gold-coin.png',
                  width: 16,
                  height: 16,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.monetization_on_rounded,
                    size: 12,
                    color: enabled ? Colors.white : AppColors.textSoft,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  formatCompact(cost!),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: enabled ? Colors.white : AppColors.textSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
