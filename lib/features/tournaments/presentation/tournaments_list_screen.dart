import 'package:flutter/material.dart';

import '../../../core/config/app_colors.dart';

class TournamentsListScreen extends StatelessWidget {
  const TournamentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Text(
            'Tournois - A venir',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
          ),
        ),
      ),
    );
  }
}
