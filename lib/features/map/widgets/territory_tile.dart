import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';
import '../models/territory_model.dart';

class TerritoryTile extends StatelessWidget {
  final TerritoryModel territory;
  final bool isSelected;
  final VoidCallback? onTap;

  const TerritoryTile({
    super.key,
    required this.territory,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final statusLabel = _statusLabel;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? statusColor.withValues(alpha: 0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: statusColor, width: 1.5)
              : Border.all(color: AppColors.surfaceLight, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    territory.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (territory.ownerClubName != null)
                    Text(
                      territory.ownerClubName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (territory.status) {
      case TerritoryStatus.locked:
        return AppColors.warning;
      case TerritoryStatus.alert:
        return AppColors.error;
      case TerritoryStatus.conquered:
        return AppColors.territoryConquered;
      case TerritoryStatus.conflict:
        return AppColors.territoryConflict;
      case TerritoryStatus.available:
        return AppColors.territoryAvailable;
    }
  }

  String get _statusLabel {
    switch (territory.status) {
      case TerritoryStatus.locked:
        return 'Verrouillee';
      case TerritoryStatus.alert:
        return 'Alerte';
      case TerritoryStatus.conquered:
        return 'Conquise';
      case TerritoryStatus.conflict:
        return 'Conflit';
      case TerritoryStatus.available:
        return 'Disponible';
    }
  }

  IconData get _statusIcon {
    switch (territory.status) {
      case TerritoryStatus.locked:
        return Icons.lock_outline;
      case TerritoryStatus.alert:
        return Icons.warning_amber_rounded;
      case TerritoryStatus.conquered:
        return Icons.shield;
      case TerritoryStatus.conflict:
        return Icons.local_fire_department;
      case TerritoryStatus.available:
        return Icons.flag_outlined;
    }
  }
}
