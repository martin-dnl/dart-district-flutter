import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class TournamentDetailScreen extends StatelessWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail tournoi'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Tournoi: $tournamentId',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
