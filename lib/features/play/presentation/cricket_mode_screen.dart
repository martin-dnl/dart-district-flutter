import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_routes.dart';

class CricketModeScreen extends StatelessWidget {
  const CricketModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mode Cricket')),
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
                  'Ferme 20 a 15 et le Bull avant ton adversaire.\n'
                  'Les points ne comptent que sur des numeros fermes chez toi et ouverts chez lui.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.gameSetup, extra: 'Cricket'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Configurer une partie Cricket'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
