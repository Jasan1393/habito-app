import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_size.dart';

class HabitoBookingProgressOverlay extends StatefulWidget {
  final String title;
  final String message;

  const HabitoBookingProgressOverlay({
    super.key,
    this.title = 'Estamos confirmando tu cita',
    this.message = 'Verificamos el horario y guardamos tu reserva en Hábito.',
  });

  @override
  State<HabitoBookingProgressOverlay> createState() =>
      _HabitoBookingProgressOverlayState();
}

class _HabitoBookingProgressOverlayState
    extends State<HabitoBookingProgressOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: AppColors.primary.withValues(alpha: 0.58),
          child: Center(
            child: Container(
              width: 292,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.display,
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: AppShadows.strong,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: _controller.value * math.pi * 2,
                              child: CustomPaint(
                                size: const Size.square(96),
                                painter: _HabitoProgressRingPainter(),
                              ),
                            ),
                            child!,
                          ],
                        );
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.extraLarge,
                          boxShadow: AppShadows.goldGlow,
                        ),
                        child: Image.asset(
                          'assets/images/logo_habito_blanco.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.titleLarge,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.bodyStrong,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _BookingProgressDots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingProgressDots extends StatefulWidget {
  const _BookingProgressDots();

  @override
  State<_BookingProgressDots> createState() => _BookingProgressDotsState();
}

class _BookingProgressDotsState extends State<_BookingProgressDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final offset = (index * 0.22).clamp(0.0, 1.0);
            final value = ((_controller.value + offset) % 1.0);
            final scale = 0.72 + (math.sin(value * math.pi) * 0.34);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(
                    alpha: 0.42 + (scale - 0.72),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _HabitoProgressRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = 5.0;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.goldMuted;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.goldLight,
          AppColors.secondary,
          AppColors.goldDeep,
        ],
        stops: [0.0, 0.38, 0.72, 1.0],
      ).createShader(rect);

    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.55,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
