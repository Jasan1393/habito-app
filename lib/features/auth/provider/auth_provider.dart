import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../bookings/presentation/pages/my_appointments_page.dart';
import '../../shop/data/services/habito_booking_api.dart';
import '../models/auth_user.dart';
import '../services/biometric_service.dart';
import '../services/auth_api.dart';
import '../services/auth_storage.dart';

class AuthProvider extends ChangeNotifier {
  static const Duration _pendingSyncRetryCooldown = Duration(minutes: 10);

  final AuthApi _api;
  final AuthStorage _storage;

  AuthProvider({
    AuthApi? api,
    AuthStorage? storage,
  })  : _api = api ?? AuthApi(),
        _storage = storage ?? AuthStorage();

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _token;
  AuthUser? _user;
  String? _error;
  bool _biometricEnabled = true;
  bool _biometricAvailable = false;
  DateTime? _lastPendingSyncRetryAt;
  bool _isPendingSyncRepairRunning = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty && _user != null;
  String? get token => _token;
  AuthUser? get user => _user;
  String? get error => _error;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;

  Future<void> init() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _biometricEnabled = await _storage.isBiometricEnabled();
      _biometricAvailable = await BiometricService.isAvailable();

      final savedToken = await _storage.getToken();
      final savedUser = await _storage.getUser();

      if (savedToken != null && savedToken.isNotEmpty && savedUser != null) {
        _token = savedToken;
        _user = savedUser;

        try {
          final refreshedUser = await _api.getProfile(savedToken);
          _user = refreshedUser;
          await _storage.saveSession(token: savedToken, user: refreshedUser);
        } catch (_) {
          // Si falla el refresh, mantenemos la sesión local existente.
        }

        await PushNotificationService.registerToken(authToken: savedToken);
        await _identifyAnalyticsUser(_user);
      }
    } catch (_) {
      _error = 'No se pudo restaurar la sesión.';
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      final result = await _api.login(email: email, password: password);
      await _persistSession(result.token, result.user);
      _runPostAuthTasks(
        token: result.token,
        action: _PostAuthAction.login,
      );
      return true;
    });
  }

  Future<bool> register({
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String phone,
    required String birthday,
    required String contactType,
    required String businessName,
    required String identificationType,
    required String taxNumber,
    required String province,
    required String city,
    required String address,
    required String password,
    String referralCode = '',
  }) async {
    final hasReferral = referralCode.trim().isNotEmpty;

    return _runAuthAction(() async {
      final result = await _api.register(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        email: email,
        phone: phone,
        birthday: birthday,
        contactType: contactType,
        businessName: businessName,
        identificationType: identificationType,
        taxNumber: taxNumber,
        province: province,
        city: city,
        address: address,
        password: password,
        referralCode: referralCode,
      );
      await _persistSession(result.token, result.user);
      _runPostAuthTasks(
        token: result.token,
        action: _PostAuthAction.register,
        hasReferral: hasReferral,
      );
      return true;
    });
  }

  Future<String?> forgotPassword({
    required String email,
  }) async {
    String? responseMessage;

    await _runAuthAction(() async {
      responseMessage = await _api.forgotPassword(email: email);
      return true;
    });

    return responseMessage;
  }

  Future<bool> updateProfile({
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
    required String birthday,
    required String contactType,
    required String businessName,
    required String identificationType,
    required String taxNumber,
    required String province,
    required String city,
    required String address,
    String? photoPath,
    required bool removePhoto,
  }) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) {
      _error = 'Tu sesión ya no está disponible.';
      notifyListeners();
      return false;
    }

    return _runAuthAction(() async {
      final updatedUser = await _api.updateProfile(
        token: currentToken,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phone: phone,
        birthday: birthday,
        contactType: contactType,
        businessName: businessName,
        identificationType: identificationType,
        taxNumber: taxNumber,
        province: province,
        city: city,
        address: address,
        photoPath: photoPath,
        removePhoto: removePhoto,
      );

      _user = updatedUser;
      await _storage.saveSession(token: currentToken, user: updatedUser);
      await _identifyAnalyticsUser(updatedUser);
      return true;
    });
  }

  Future<void> logout() async {
    final currentToken = _token;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (currentToken != null && currentToken.isNotEmpty) {
        await _api.logout(currentToken);
      }
    } catch (_) {
      // Aunque falle el logout remoto, limpiamos la sesión local.
    } finally {
      await _clearSession(clearStorage: true);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> hasSavedSession() async {
    try {
      final savedToken = await _storage.getToken();
      final savedUser = await _storage.getUser();
      return savedToken != null && savedToken.isNotEmpty && savedUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _storage.setBiometricEnabled(enabled);
    notifyListeners();
  }

  Future<bool> setPushNotificationsEnabled(bool enabled) async {
    final currentToken = _token;
    final currentUser = _user;

    if (currentToken == null ||
        currentToken.isEmpty ||
        currentUser == null ||
        !isLoggedIn) {
      _error = 'Tu sesión ya no está disponible.';
      notifyListeners();
      return false;
    }

    return _runAuthAction(() async {
      final updatedUser = await _api.updatePushNotificationsPreference(
        token: currentToken,
        enabled: enabled,
      );

      _user = updatedUser;
      await _storage.saveSession(token: currentToken, user: updatedUser);
      await _identifyAnalyticsUser(updatedUser);

      if (enabled) {
        await PushNotificationService.registerToken(authToken: currentToken);
      }

      return true;
    });
  }

  Future<Map<String, String>?> requestAccountDeletion() async {
    final currentToken = _token;

    if (currentToken == null || currentToken.isEmpty || !isLoggedIn) {
      _error = 'Tu sesión ya no está disponible.';
      notifyListeners();
      return null;
    }

    Map<String, String>? responseData;

    final success = await _runAuthAction(() async {
      responseData = await _api.requestAccountDeletion(token: currentToken);
      return true;
    });

    if (!success) {
      return null;
    }

    return responseData;
  }

  Future<bool> refreshProfile({bool notify = true}) async {
    final currentToken = _token;

    if (currentToken == null || currentToken.isEmpty || !isLoggedIn) {
      return false;
    }

    try {
      final refreshedUser = await _api.getProfile(currentToken);
      _user = refreshedUser;
      await _storage.saveSession(token: currentToken, user: refreshedUser);

      if (notify) {
        notifyListeners();
      }
      return true;
    } catch (_) {
      // Mantenemos la sesion actual si el refresh falla.
      return false;
    }
  }

  Future<void> retryPendingSyncIfNeeded({bool force = false}) async {
    final currentToken = _token;
    final currentUser = _user;

    if (!_isInitialized ||
        currentToken == null ||
        currentToken.isEmpty ||
        currentUser == null ||
        !_hasPendingAmeliaSync(currentUser)) {
      return;
    }

    if (_isPendingSyncRepairRunning) return;

    final now = DateTime.now();
    final lastAttempt = _lastPendingSyncRetryAt;
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt) < _pendingSyncRetryCooldown) {
      return;
    }

    _isPendingSyncRepairRunning = true;
    _lastPendingSyncRetryAt = now;

    var shouldNotify = false;

    shouldNotify = await refreshProfile(notify: false);

    try {
      await PushNotificationService.registerToken(authToken: currentToken);
    } catch (_) {
      // No bloqueamos la sesion si el refresh del push falla.
    } finally {
      _isPendingSyncRepairRunning = false;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  void lockSession() {
    _token = null;
    _user = null;
    _error = null;
    _lastPendingSyncRetryAt = null;
    _isPendingSyncRepairRunning = false;
    PushNotificationService.clearSession();
    HabitoBookingApi.clearMyBookingsCache();
    MyAppointmentsPage.clearCachedState();
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<bool> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await action();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistSession(String token, AuthUser user) async {
    _token = token;
    _user = user;
    await _storage.saveSession(token: token, user: user);
    _registerPushTokenInBackground(token);
  }

  void _registerPushTokenInBackground(String token) {
    unawaited(() async {
      try {
        await PushNotificationService.registerToken(authToken: token);
      } catch (_) {
        // El token push se puede reintentar luego; no debe frenar el login.
      }
    }());
  }

  void _runPostAuthTasks({
    required String token,
    required _PostAuthAction action,
    bool hasReferral = false,
  }) {
    unawaited(() async {
      try {
        await _refreshProfileAfterAuth(token);
        await _identifyAnalyticsUser(_user);

        if (action == _PostAuthAction.register) {
          await AnalyticsService.logSignUp(hasReferral: hasReferral);

          if (hasReferral) {
            await AnalyticsService.logReferralCodeApplied(source: 'register');
          }
        } else {
          await AnalyticsService.logLogin();
        }
      } catch (_) {
        // Las tareas post-auth no deben bloquear el acceso del usuario.
      }
    }());
  }

  Future<void> _refreshProfileAfterAuth(String token) async {
    try {
      final refreshedUser = await _api.getProfile(token);
      _user = refreshedUser;
      await _storage.saveSession(token: token, user: refreshedUser);
    } catch (_) {
      // Si Amelia sigue sincronizando, mantenemos la sesión ya iniciada.
    }
  }

  Future<void> _clearSession({required bool clearStorage}) async {
    _token = null;
    _user = null;
    _error = null;
    _lastPendingSyncRetryAt = null;
    _isPendingSyncRepairRunning = false;

    if (clearStorage) {
      await _storage.clearSession();
    }

    PushNotificationService.clearSession();
    HabitoBookingApi.clearMyBookingsCache();
    MyAppointmentsPage.clearCachedState();
    await _identifyAnalyticsUser(null);
  }

  Future<void> _identifyAnalyticsUser(AuthUser? user) {
    return AnalyticsService.identifyUser(
      userId: user?.id,
      email: user?.email ?? '',
      phone: user?.phone ?? '',
      displayName: user?.displayName ?? '',
      hasAmeliaLink: ((user?.ameliaCustomerId ?? 0) > 0),
      hasWooLink: ((user?.wooCustomerId ?? 0) > 0),
      contactType: user?.contactType ?? 'unknown',
      pointsEnabled: user?.pointsEnabled ?? false,
    );
  }

  bool _hasPendingAmeliaSync(AuthUser user) {
    final syncStatus = user.syncStatus?.trim().toLowerCase();
    final missingAmeliaId = (user.ameliaCustomerId ?? 0) <= 0;

    return syncStatus == 'pending' ||
        syncStatus == 'error' ||
        syncStatus == 'failed' ||
        (missingAmeliaId && syncStatus != 'linked');
  }
}

enum _PostAuthAction { login, register }
