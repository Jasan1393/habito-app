import 'auth_user.dart';

class AuthResult {
  final String token;
  final AuthUser user;

  const AuthResult({
    required this.token,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AuthResult(
      token: (data['token'] ?? '').toString(),
      user: AuthUser.fromJson(
        (data['user'] as Map<String, dynamic>? ?? {}),
      ),
    );
  }
}
