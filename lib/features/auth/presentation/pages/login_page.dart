import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/validators/form_validators.dart';
import '../../provider/auth_provider.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final bool popOnSuccess;

  const LoginPage({
    super.key,
    this.popOnSuccess = true,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      if (widget.popOnSuccess) {
        Navigator.pop(context, true);
      }
      return;
    }

    if (auth.error != null && auth.error!.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.snackBarDark,
            behavior: SnackBarBehavior.floating,
            content: Text(
              auth.error!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
    }
  }

  Future<void> _openForgotPassword() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordPage(),
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.snackBarDark,
          behavior: SnackBarBehavior.floating,
          content: Text(
            result,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
  }

  Future<void> _openRegister() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterPage(),
      ),
    );

    if (!mounted || created != true) return;

    if (widget.popOnSuccess) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.secondary;
    const bg = AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.authTop,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.authPanel,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.darkPanel,
                          AppColors.primary,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.14),
                      ),
                      boxShadow: AppShadows.authPanel,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.dividerTall,
                        AppSpacing.xl,
                        AppSpacing.xl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: AppIconSize.authBadge,
                                  height: AppIconSize.authBadge,
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadius.medium,
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.lock_person_rounded,
                                    color: AppColors.goldLight,
                                    size: AppIconSize.md,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Image.asset(
                                    'assets/images/logo_habito_blanco.png',
                                    height: AppIconSize.authLogo,
                                    alignment: Alignment.centerLeft,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                      height: AppIconSize.authLogo,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Hábito Barbería',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: AppTextSize.headlineSmall,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppIconSize.inline),
                            const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppTextSize.displaySmall,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Accede a tu cuenta para gestionar tus citas, puntos y pedidos desde una sola experiencia.',
                              style: TextStyle(
                                color: AppColors.textOnDarkMuted,
                                height: 1.45,
                                fontSize: AppTextSize.base,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.authTop),
                            Container(
                              padding:
                                  const EdgeInsets.all(AppSpacing.formNotice),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: AppRadius.large,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.fingerprint_rounded,
                                    color: AppColors.goldLight,
                                    size: AppIconSize.compact,
                                  ),
                                  SizedBox(width: AppSpacing.gutter),
                                  Expanded(
                                    child: Text(
                                      'Si activas huella digital desde tu perfil, podras proteger el acceso automatico a la app.',
                                      style: TextStyle(
                                        color: AppColors.textOnDarkMuted,
                                        height: 1.38,
                                        fontSize: AppTextSize.bodySmall,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Correo electronico',
                                icon: Icons.alternate_email_rounded,
                              ),
                              validator: FormValidators.email,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!auth.isLoading) {
                                  _submit();
                                }
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Contraseña',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) return 'Ingresa tu contraseña';
                                if (v.length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.gutter),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed:
                                    auth.isLoading ? null : _openForgotPassword,
                                child: const Text(
                                  'Olvidé mi contraseña',
                                  style: TextStyle(
                                    color: gold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              height: AppSpacing.actionHeight,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor:
                                      gold.withValues(alpha: 0.72),
                                  disabledForegroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.tile,
                                  ),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: AppIconSize.inline,
                                        height: AppIconSize.inline,
                                        child: CircularProgressIndicator(
                                          strokeWidth:
                                              AppSpacing.progressStrokeStrong,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'Ingresar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppTextSize.titleMedium,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.all(AppSpacing.formNotice),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.035),
                                borderRadius: AppRadius.large,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    '¿Aún no tienes cuenta?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textOnDarkMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.gutter),
                                  SizedBox(
                                    width: double.infinity,
                                    height: AppSpacing.secondaryActionHeight,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          auth.isLoading ? null : _openRegister,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: gold,
                                        side: BorderSide(
                                          color: gold.withValues(alpha: 0.76),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppRadius.medium,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                        size: AppIconSize.sm,
                                      ),
                                      label: const Text(
                                        'Crear cuenta',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: AppColors.secondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.darkInput,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.inputVertical,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.tile,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.tile,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.tile,
        borderSide: const BorderSide(
          color: AppColors.secondary,
          width: AppSpacing.focusBorder,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.tile,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: AppSpacing.focusBorder,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.tile,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: AppSpacing.focusBorder,
        ),
      ),
    );
  }
}
