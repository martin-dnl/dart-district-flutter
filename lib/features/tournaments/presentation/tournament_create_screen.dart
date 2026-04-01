import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class TournamentCreateScreen extends StatelessWidget {
  const TournamentCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creer un tournoi'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'Creation de tournoi - A venir',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
