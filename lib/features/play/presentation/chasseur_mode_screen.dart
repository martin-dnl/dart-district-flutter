import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';

class ChasseurModeScreen extends StatelessWidget {
  const ChasseurModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mode Chasseur')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: const Text(
                  'Chaque joueur defend sa zone.\n'
                  'Le chasseur peut cibler les zones des autres joueurs pour leur enlever des vies.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.gameSetup, extra: 'Chasseur'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Configurer une partie Chasseur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
