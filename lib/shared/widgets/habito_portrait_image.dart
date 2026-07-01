import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'habito_cached_network_image.dart';

class HabitoPortraitImage extends StatelessWidget {
  final String imageUrl;
  final Alignment alignment;
  final Widget fallback;

  const HabitoPortraitImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();

    return ColoredBox(
      color: AppColors.primary,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primarySoft,
              AppColors.primary,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: normalizedUrl.isNotEmpty
            ? HabitoCachedNetworkImage(
                imageUrl: normalizedUrl,
                fit: BoxFit.contain,
                alignment: alignment,
                errorWidget: fallback,
              )
            : fallback,
      ),
    );
  }
}
