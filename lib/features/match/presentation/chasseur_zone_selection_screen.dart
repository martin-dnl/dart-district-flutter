import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';
import '../controller/chasseur_match_controller.dart';
import '../models/chasseur_match_state.dart';

class ChasseurZoneSelectionScreen extends ConsumerWidget {
  const ChasseurZoneSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChasseurMatchState>(chasseurMatchControllerProvider, (prev, next) {
      if (prev?.phase != ChasseurPhase.playing &&
          next.phase == ChasseurPhase.playing &&
          context.mounted) {
        context.go(AppRoutes.matchChasseur);
      }
    });

    final state = ref.watch(chasseurMatchControllerProvider);
    final controller = ref.read(chasseurMatchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Selection des zones'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Chaque joueur doit choisir sa zone cible (1-20 ou Bull).',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...state.players.asMap().entries.map((entry) {
              final index = entry.key;
              final player = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlayerZoneSelector(
                  playerName: player.name,
                  selectedZone: player.zone,
                  isZoneTaken: (zone) {
                    return state.players.asMap().entries.any(
                          (other) => other.key != index && other.value.zone == zone,
                        );
                  },
                  onZoneSelected: (zone) {
                    controller.assignZone(index, zone);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PlayerZoneSelector extends StatelessWidget {
  const _PlayerZoneSelector({
    required this.playerName,
    required this.selectedZone,
    required this.isZoneTaken,
    required this.onZoneSelected,
  });

  final String playerName;
  final int? selectedZone;
  final bool Function(int zone) isZoneTaken;
  final ValueChanged<int> onZoneSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: selectedZone,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
            ),
            dropdownColor: AppColors.surface,
            items: [
              for (var i = 1; i <= 20; i++)
                DropdownMenuItem<int>(
                  value: i,
                  enabled: !isZoneTaken(i),
                  child: Text('Zone $i'),
                ),
              DropdownMenuItem<int>(
                value: 25,
                enabled: !isZoneTaken(25),
                child: const Text('Bull'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onZoneSelected(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
