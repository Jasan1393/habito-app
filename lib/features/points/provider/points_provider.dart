import 'package:flutter/foundation.dart';

import '../../auth/models/auth_user.dart';
import '../data/services/points_api.dart';
import '../models/points_history_entry.dart';
import '../models/points_quote.dart';
import '../models/points_summary.dart';

class PointsProvider extends ChangeNotifier {
  static const Duration _cacheTtl = Duration(minutes: 5);

  final PointsApi _api;

  PointsProvider({PointsApi? api}) : _api = api ?? PointsApi();

  String? _token;
  AuthUser? _authUser;
  PointsSummary? _summary;
  List<PointsHistoryEntry> _history = const [];
  bool _isLoading = false;
  String? _error;
  int _historyTotal = 0;
  DateTime? _lastLoadedAt;

  PointsSummary? get summary => _summary;
  List<PointsHistoryEntry> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get historyTotal => _historyTotal;
  bool get hasSummary => _summary != null;
  bool get isLoggedIn =>
      _token != null && _token!.isNotEmpty && _authUser != null;

  void updateSession({
    required String? token,
    required AuthUser? user,
  }) {
    final previousUserId = _authUser?.id;
    _token = token;
    _authUser = user;

    if (user == null || token == null || token.isEmpty) {
      _summary = null;
      _history = const [];
      _historyTotal = 0;
      _error = null;
      _lastLoadedAt = null;
      notifyListeners();
      return;
    }

    if (previousUserId != user.id) {
      _history = const [];
      _historyTotal = 0;
      _lastLoadedAt = null;
    }

    _summary = PointsSummary(
      enabled: user.pointsEnabled,
      mycredAvailable: user.pointsEnabled,
      balance: user.pointsBalance,
      totalEarned: user.pointsTotalEarned,
      pointType: user.pointsType,
      label: user.pointsLabel,
      nextGoal: user.pointsNextGoal ?? 0,
      toNextGoal: (user.pointsNextGoal ?? 0) > 0
          ? ((user.pointsNextGoal ?? 0) - user.pointsBalance)
              .clamp(0, double.infinity)
              .toDouble()
          : 0,
      redeemEnabled: user.pointsRedeemEnabled,
      redeemProductsEnabled: user.pointsRedeemProductsEnabled,
      redeemBookingsEnabled: user.pointsRedeemBookingsEnabled,
      redeemPointsPerUsd: user.pointsRedeemPointsPerUsd,
      redeemMinPoints: user.pointsRedeemMinPoints,
      redeemMaxPercent: user.pointsRedeemMaxPercent,
      bookingPointsEnabled: user.pointsEnabled,
      orderPointsEnabled: user.pointsEnabled,
    );
    _error = null;
    notifyListeners();
  }

  Future<void> load({bool forceRefresh = false}) async {
    final token = _token;

    if (token == null || token.isEmpty) return;

    if (!forceRefresh &&
        _summary != null &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _cacheTtl) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final overview = await _api.getSummary(token: token);
      _summary = overview.summary;
      _history = overview.history;
      _historyTotal = overview.historyTotal;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  Future<PointsQuote> quoteRedemption({
    required String context,
    required double amount,
    double requestedPoints = 0,
  }) {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesion para usar tus puntos.');
    }

    return _api.quoteRedemption(
      token: token,
      context: context,
      amount: amount,
      requestedPoints: requestedPoints,
    );
  }
}
