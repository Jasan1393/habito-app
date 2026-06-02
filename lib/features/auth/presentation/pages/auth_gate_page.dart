import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_inbox_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../provider/auth_provider.dart';
import '../../services/biometric_service.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage>
    with WidgetsBindingObserver {
  int _initialIndex = 0;
  Map<String, dynamic>? _myAppointmentsArguments;
  bool _isBootstrapping = true;
  bool _needsBiometricGate = false;
  bool _isAuthenticating = false;
  bool _autoPromptQueued = false;
  String _biometricMessage = 'Preparando acceso seguro...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_bootstrapSession);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final value = args['initialIndex'];
      final parsed =
          value is int ? value : int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed >= 0 && parsed <= 4) {
        _initialIndex = parsed;
      }

      final myAppointmentsArguments = args['myAppointmentsArguments'];
      if (myAppointmentsArguments is Map) {
        _myAppointmentsArguments =
            Map<String, dynamic>.from(myAppointmentsArguments);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BiometricService.stopAuthentication();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      NotificationInboxService.refreshUnreadCount();
      _queuePendingSyncRepair();

      if (_needsBiometricGate && !_isAuthenticating) {
        _queueAutomaticBiometricPrompt();
      }
    }
  }

  Future<void> _bootstrapSession() async {
    final auth = context.read<AuthProvider>();
    await auth.init();

    if (!mounted) return;

    if (auth.restoredSavedSession && auth.isLoggedIn) {
      if (auth.biometricEnabled && auth.biometricAvailable) {
        setState(() {
          _needsBiometricGate = true;
          _isBootstrapping = false;
          _biometricMessage =
              'Usa tu huella o seguridad del dispositivo para entrar a tu cuenta.';
        });
        _queueAutomaticBiometricPrompt();
        return;
      }
    }

    setState(() {
      _isBootstrapping = false;
    });
  }

  void _queueAutomaticBiometricPrompt() {
    if (!mounted ||
        _autoPromptQueued ||
        _isAuthenticating ||
        !_needsBiometricGate) {
      return;
    }

    _autoPromptQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoPromptQueued = false;
      if (!mounted || !_needsBiometricGate || _isAuthenticating) return;
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted || !_needsBiometricGate || _isAuthenticating) return;
      if (!_isAppReadyForBiometricPrompt()) {
        setState(() {
          _biometricMessage = 'Retomando acceso seguro...';
        });
        return;
      }
      await _runBiometricAuthentication();
    });
  }

  void _queuePendingSyncRepair() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().retryPendingSyncIfNeeded();
    });
  }

  Future<void> _runBiometricAuthentication() async {
    if (!mounted || _isAuthenticating) return;

    if (!_isAppReadyForBiometricPrompt()) {
      setState(() {
        _biometricMessage = 'Retomando acceso seguro...';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      setState(() {
        _needsBiometricGate = false;
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _biometricMessage = 'Esperando huella o verificacion del dispositivo...';
    });

    final approved = await BiometricService.authenticate();

    if (!mounted) return;

    if (approved) {
      setState(() {
        _isAuthenticating = false;
        _needsBiometricGate = false;
      });
      return;
    }

    setState(() {
      _isAuthenticating = false;
      _biometricMessage =
          'No pudimos validar tu identidad. Intentaremos nuevamente cuando vuelvas a la app o puedes reintentar ahora.';
    });
  }

  bool _isAppReadyForBiometricPrompt() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (_isBootstrapping || !auth.isInitialized) {
          return const _AuthSplashScreen();
        }

        if (_needsBiometricGate) {
          return _BiometricGateScreen(
            isAuthenticating: _isAuthenticating,
            message: _biometricMessage,
            onRetry: _runBiometricAuthentication,
            onUseAnotherSession: () {
              auth.lockSession();
              setState(() {
                _needsBiometricGate = false;
                _isAuthenticating = false;
              });
            },
          );
        }

        return MainNavigationPage(
          initialIndex: _initialIndex,
          myAppointmentsArguments: _myAppointmentsArguments,
        );
      },
    );
  }
}

class _AuthSplashScreen extends StatelessWidget {
  const _AuthSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(),
            SizedBox(height: 22),
            CircularProgressIndicator(
              color: AppColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricGateScreen extends StatelessWidget {
  final bool isAuthenticating;
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onUseAnotherSession;

  const _BiometricGateScreen({
    required this.isAuthenticating,
    required this.message,
    required this.onRetry,
    required this.onUseAnotherSession,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.darkPanel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 28),
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.goldLight,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Acceso protegido',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.displaySmall - 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textOnDarkMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.goldLight,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Usamos la seguridad del dispositivo para proteger tu cuenta.',
                              style: TextStyle(
                                color: AppColors.textOnDarkMuted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isAuthenticating ? null : onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isAuthenticating
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Usar huella digital',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: AppTextSize.titleSmall,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            isAuthenticating ? null : onUseAnotherSession,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Usar otra sesión',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_habito_blanco.png',
      height: 76,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.content_cut_rounded,
        color: AppColors.goldLight,
        size: 52,
      ),
    );
  }
}
