import '../auth/models/auth_user.dart';
import 'models/points_summary.dart';

enum PointsRedemptionContext {
  order,
  booking,
}

class PointsRedemptionState {
  final bool enabled;
  final bool redeemEnabled;
  final bool redeemProductsEnabled;
  final bool redeemBookingsEnabled;
  final bool orderPointsEnabled;
  final bool bookingPointsEnabled;
  final double balance;
  final double rate;
  final double minPoints;
  final double maxPercent;
  final String label;

  const PointsRedemptionState({
    required this.enabled,
    required this.redeemEnabled,
    required this.redeemProductsEnabled,
    required this.redeemBookingsEnabled,
    required this.orderPointsEnabled,
    required this.bookingPointsEnabled,
    required this.balance,
    required this.rate,
    required this.minPoints,
    required this.maxPercent,
    required this.label,
  });
}

class PointsRedemptionResult {
  final PointsRedemptionState state;
  final PointsRedemptionContext context;
  final double total;
  final double pointsToUse;
  final double discount;
  final double payableTotal;
  final bool contextEnabled;

  const PointsRedemptionResult({
    required this.state,
    required this.context,
    required this.total,
    required this.pointsToUse,
    required this.discount,
    required this.payableTotal,
    required this.contextEnabled,
  });

  bool get canRedeem => contextEnabled && pointsToUse > 0 && discount > 0;

  String helperMessage() {
    final lowerLabel = state.label.toLowerCase();
    final contextLabel = context == PointsRedemptionContext.booking
        ? 'esta reserva'
        : 'este pedido';

    if (!state.enabled || !state.redeemEnabled || !contextEnabled) {
      return 'El canje de $lowerLabel no está disponible para $contextLabel.';
    }

    if (total <= 0) {
      return context == PointsRedemptionContext.booking
          ? 'Selecciona un servicio para calcular cuantos $lowerLabel puedes usar en esta reserva.'
          : 'Agrega productos para calcular cuantos $lowerLabel puedes usar en este pedido.';
    }

    if (state.balance <= 0) {
      return 'Aún no tienes $lowerLabel disponibles para aplicar en $contextLabel.';
    }

    if (pointsToUse <= 0) {
      if (state.balance < state.minPoints) {
        return 'Necesitas al menos ${PointsSummary.formatPoints(state.minPoints)} $lowerLabel para canjear.';
      }

      return 'Tus $lowerLabel actuales no alcanzan para generar descuento en $contextLabel.';
    }

    return 'Puedes combinar tu metodo de pago con $lowerLabel para reducir el total de $contextLabel.';
  }
}

class PointsCalculator {
  PointsCalculator._();

  static const double defaultRate = 100;
  static const double defaultMinPoints = 1;
  static const double defaultMaxPercent = 50;

  static PointsRedemptionState resolveState({
    required AuthUser? user,
    required PointsSummary? summary,
    double reservedPoints = 0,
  }) {
    final rawBalance = summary?.balance ?? user?.pointsBalance ?? 0;
    final availableBalance =
        (rawBalance - reservedPoints).clamp(0, double.infinity).toDouble();
    final enabled = summary?.enabled ?? user?.pointsEnabled ?? false;

    return PointsRedemptionState(
      enabled: enabled,
      redeemEnabled:
          summary?.redeemEnabled ?? user?.pointsRedeemEnabled ?? false,
      redeemProductsEnabled: summary?.redeemProductsEnabled ??
          user?.pointsRedeemProductsEnabled ??
          false,
      redeemBookingsEnabled: summary?.redeemBookingsEnabled ??
          user?.pointsRedeemBookingsEnabled ??
          false,
      orderPointsEnabled: summary?.orderPointsEnabled ?? enabled,
      bookingPointsEnabled: summary?.bookingPointsEnabled ?? enabled,
      balance: availableBalance,
      rate: summary?.redeemPointsPerUsd ??
          user?.pointsRedeemPointsPerUsd ??
          defaultRate,
      minPoints: summary?.redeemMinPoints ??
          user?.pointsRedeemMinPoints ??
          defaultMinPoints,
      maxPercent: summary?.redeemMaxPercent ??
          user?.pointsRedeemMaxPercent ??
          defaultMaxPercent,
      label: (summary?.label ?? user?.pointsLabel ?? 'Puntos').trim(),
    );
  }

  static PointsRedemptionResult calculate({
    required PointsRedemptionState state,
    required PointsRedemptionContext context,
    required double total,
  }) {
    final contextEnabled = isContextEnabled(state, context);
    final safeTotal = total.clamp(0, double.infinity).toDouble();

    if (!state.enabled ||
        !state.redeemEnabled ||
        !contextEnabled ||
        safeTotal <= 0) {
      return PointsRedemptionResult(
        state: state,
        context: context,
        total: safeTotal,
        pointsToUse: 0,
        discount: 0,
        payableTotal: safeTotal,
        contextEnabled: contextEnabled,
      );
    }

    final rate = state.rate > 0 ? state.rate : defaultRate;
    final maxPercent = state.maxPercent.clamp(0, 100).toDouble();
    final maxDiscount = safeTotal * (maxPercent / 100);
    final maxPointsByTotal = maxDiscount * rate;
    final rawPoints =
        state.balance < maxPointsByTotal ? state.balance : maxPointsByTotal;
    final points = rawPoints < state.minPoints
        ? 0.0
        : double.parse(rawPoints.toStringAsFixed(2));
    final discount = points <= 0
        ? 0.0
        : double.parse((points / rate).clamp(0, safeTotal).toStringAsFixed(2));
    final payableTotal =
        (safeTotal - discount).clamp(0, double.infinity).toDouble();

    return PointsRedemptionResult(
      state: state,
      context: context,
      total: safeTotal,
      pointsToUse: points,
      discount: discount,
      payableTotal: payableTotal,
      contextEnabled: contextEnabled,
    );
  }

  static bool isContextEnabled(
    PointsRedemptionState state,
    PointsRedemptionContext context,
  ) {
    switch (context) {
      case PointsRedemptionContext.order:
        return state.redeemProductsEnabled && state.orderPointsEnabled;
      case PointsRedemptionContext.booking:
        return state.redeemBookingsEnabled && state.bookingPointsEnabled;
    }
  }
}
