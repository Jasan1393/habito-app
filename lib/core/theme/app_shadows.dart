import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  static final List<BoxShadow> light = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
  ];

  static final List<BoxShadow> cardSoft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> panel = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  static final List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, -8),
    ),
  ];

  static final List<BoxShadow> strong = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.16),
      blurRadius: 28,
      offset: const Offset(0, 16),
    ),
  ];

  static final List<BoxShadow> authPanel = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 28,
      offset: const Offset(0, 16),
    ),
  ];

  static final List<BoxShadow> goldGlow = [
    BoxShadow(
      color: AppColors.secondary.withValues(alpha: 0.28),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}
