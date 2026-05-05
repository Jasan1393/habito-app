import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      await stopAuthentication();
      await Future<void>.delayed(const Duration(milliseconds: 160));

      return await _auth
          .authenticate(
        localizedReason: 'Confirma tu identidad para acceder a Hábito',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      )
          .timeout(const Duration(seconds: 18), onTimeout: () async {
        await stopAuthentication();
        return false;
      });
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopAuthentication() async {
    try {
      return await _auth
          .stopAuthentication()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
}
