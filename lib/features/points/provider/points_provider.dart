import 'package:flutter/foundation.dart';

import '../../../core/errors/friendly_errors.dart';
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
  bool _isLoadingMoreHistory = false;
  String? _error;
  int _historyTotal = 0;
  int _historyPage = 1;
  bool _hasMoreHistory = false;
  DateTime? _lastLoadedAt;
  String? _reservationId;
  String? _reservationContext;
  double _reservedPoints = 0;

  PointsSummary? get summary => _summary;
  List<PointsHistoryEntry> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;
  String? get error => _error;
  int get historyTotal => _historyTotal;
  bool get hasMoreHistory => _hasMoreHistory;
  bool get hasSummary => _summary != null;
  double get reservedPoints => _reservedPoints;
  String? get reservationContext => _reservationContext;
  bool get hasPointsReservation =>
      _reservationId != null && _reservedPoints > 0;
  double get availableBalance =>
      ((_summary?.balance ?? _authUser?.pointsBalance ?? 0) - _reservedPoints)
          .clamp(0, double.infinity)
          .toDouble();
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
      _historyPage = 1;
      _hasMoreHistory = false;
      _error = null;
      _lastLoadedAt = null;
      _clearReservation(notify: false);
      notifyListeners();
      return;
    }

    if (previousUserId != user.id) {
      _history = const [];
      _historyTotal = 0;
      _historyPage = 1;
      _hasMoreHistory = false;
      _lastLoadedAt = null;
      _clearReservation(notify: false);
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
      _historyPage = 1;
      _hasMoreHistory =
          _history.length < _historyTotal && overview.history.isNotEmpty;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = FriendlyErrors.points(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  Future<void> loadMoreHistory() async {
    final token = _token;
    if (token == null ||
        token.isEmpty ||
        _isLoading ||
        _isLoadingMoreHistory ||
        !_hasMoreHistory) {
      return;
    }

    _isLoadingMoreHistory = true;
    _error = null;
    notifyListeners();

    try {
      final nextPage = _historyPage + 1;
      final more = await _api.getHistory(
        token: token,
        page: nextPage,
        limit: 20,
      );

      if (more.isNotEmpty) {
        _history = [..._history, ...more];
        _historyPage = nextPage;
      }

      _hasMoreHistory = more.isNotEmpty &&
          (_historyTotal <= 0 || _history.length < _historyTotal);
    } catch (e) {
      _error = FriendlyErrors.points(e);
    } finally {
      _isLoadingMoreHistory = false;
      notifyListeners();
    }
  }

  bool reserveRedemption({
    required String id,
    required String context,
    required double points,
  }) {
    if (points <= 0) return true;

    if (_reservationId != null && _reservationId != id) {
      return false;
    }

    if (points > availableBalance + 0.0001) {
      return false;
    }

    _reservationId = id;
    _reservationContext = context;
    _reservedPoints = double.parse(points.toStringAsFixed(2));
    notifyListeners();
    return true;
  }

  void releaseReservation(String id) {
    if (_reservationId != id) return;
    _clearReservation();
  }

  void _clearReservation({bool notify = true}) {
    _reservationId = null;
    _reservationContext = null;
    _reservedPoints = 0;
    if (notify) notifyListeners();
  }

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
