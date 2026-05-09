import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

class HabitoLoadingShimmer extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double? itemWidth;
  final Axis direction;
  final int columns;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool shrinkWrap;

  const HabitoLoadingShimmer({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 96,
    this.itemWidth,
    this.direction = Axis.vertical,
    this.columns = 1,
    this.spacing = AppSpacing.md,
    this.padding = EdgeInsets.zero,
    this.borderRadius = AppRadius.card,
    this.shrinkWrap = true,
  });

  const HabitoLoadingShimmer.horizontal({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 220,
    this.itemWidth = 210,
    this.spacing = AppSpacing.md,
    this.padding = EdgeInsets.zero,
    this.borderRadius = AppRadius.panel,
  })  : direction = Axis.horizontal,
        columns = 1,
        shrinkWrap = true;

  const HabitoLoadingShimmer.grid({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 220,
    this.columns = 2,
    this.spacing = AppSpacing.formNotice,
    this.padding = EdgeInsets.zero,
    this.borderRadius = AppRadius.panel,
  })  : direction = Axis.vertical,
        itemWidth = null,
        shrinkWrap = true;

  @override
  Widget build(BuildContext context) {
    if (columns > 1) {
      return GridView.builder(
        itemCount: itemCount,
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: itemHeight,
        ),
        itemBuilder: (_, index) => _ShimmerCard(
          borderRadius: borderRadius,
          delay: index,
        ),
      );
    }

    if (direction == Axis.horizontal) {
      return SizedBox(
        height: itemHeight,
        child: ListView.separated(
          padding: padding,
          scrollDirection: Axis.horizontal,
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemBuilder: (_, index) => SizedBox(
            width: itemWidth,
            child: _ShimmerCard(
              borderRadius: borderRadius,
              delay: index,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (_, index) => SizedBox(
        height: itemHeight,
        width: itemWidth,
        child: _ShimmerCard(
          borderRadius: borderRadius,
          delay: index,
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final BorderRadius borderRadius;
  final int delay;

  const _ShimmerCard({
    required this.borderRadius,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1),
      duration: Duration(milliseconds: 850 + (delay * 90)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      onEnd: () {},
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.cardSoft,
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.72,
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.large,
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceMuted,
                  AppColors.goldMuted.withValues(alpha: 0.55),
                  AppColors.surfaceMuted,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
