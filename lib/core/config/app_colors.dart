import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette inspired by the reference UI
  static const Color primary = Color(0xFFC8FF00); // Neon lime
  static const Color primaryDark = Color(0xFF8FB900);
  static const Color primaryLight = Color(0xFFD8FF52);

  static const Color secondary = Color(0xFF6A6FFF); // Electric indigo
  static const Color secondaryDark = Color(0xFF4549CC);

  static const Color accent = Color(0xFFFFC70A); // Gold/yellow highlights

  // Background surfaces
  static const Color background = Color(0xFF060A14);
  static const Color surface = Color(0xFF101728);
  static const Color surfaceLight = Color(0xFF1A2338);
  static const Color card = Color(0xFF161F33);
  static const Color stroke = Color(0xFF2A3350);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA9B3CC);
  static const Color textHint = Color(0xFF687393);

  // Status
  static const Color success = Color(0xFF29D97D);
  static const Color warning = Color(0xFFFFC70A);
  static const Color error = Color(0xFFFF4A55);
  static const Color info = Color(0xFF39C3FF);

  // Territory
  static const Color territoryAvailable = Color(0xFF29D97D);
  static const Color territoryConquered = Color(0xFF6A6FFF);
  static const Color territoryConflict = Color(0xFFFF4A55);

  // Game
  static const Color bullseye = Color(0xFFFF4A55);
  static const Color tripleRing = Color(0xFF29D97D);
  static const Color doubleRing = Color(0xFF6A6FFF);

  // Reusable gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, card],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFF060A14), Color(0xFF0A1120), Color(0xFF060A14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFFCEFF1A), Color(0xFFB9F100)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
