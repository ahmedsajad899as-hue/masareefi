import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9D97FF);
  static const primaryDark = Color(0xFF3D35CC);

  static const secondary = Color(0xFF03DAC6);
  static const accent = Color(0xFFFF6584);

  // Backgrounds
  static const bgLight = Color(0xFFF8F9FE);
  static const bgDark = Color(0xFF121212);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E2E);
  static const cardDark = Color(0xFF252535);

  // Text
  static const textPrimaryLight = Color(0xFF1A1A2E);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textPrimaryDark = Color(0xFFF0F0FF);
  static const textSecondaryDark = Color(0xFF9CA3AF);

  // Status
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const info = Color(0xFF2196F3);

  // Category colors
  static const food = Color(0xFFFF9800);
  static const transport = Color(0xFF2196F3);
  static const shopping = Color(0xFFE91E63);
  static const health = Color(0xFF4CAF50);
  static const entertainment = Color(0xFF9C27B0);
  static const educationColor = Color(0xFF00BCD4);
  static const bills = Color(0xFFFF5722);
  static const housing = Color(0xFF795548);
  static const other = Color(0xFF9E9E9E);

  // Chart palette
  static const chartColors = [
    primary,
    food,
    transport,
    shopping,
    health,
    entertainment,
    educationColor,
    bills,
    housing,
    other,
  ];

  // Alias used by statistics screen
  static const chartPalette = chartColors;

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
