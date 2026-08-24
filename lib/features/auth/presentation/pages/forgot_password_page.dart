import 'package:flutter/material.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/validators/form_validators.dart';
import '../../services/auth_api.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _api = AuthApi();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final message = await _api.forgotPassword(
        email: _emailCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;

      final error = FriendlyErrors.clean(
        e,
        fallback:
            'No pudimos enviar el enlace ahora. Intenta nuevamente en unos segundos.',
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppColors.snackBarDark,
            behavior: SnackBarBehavior.floating,
            content: Text(error, style: const TextStyle(color: Colors.white)),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.secondary;
    const bg = AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recuperar contraseña',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.authTop,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: Center(
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
                          children: [
                            Container(
                              width: AppIconSize.authBadge,
                              height: AppIconSize.authBadge,
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.medium,
                                color:
                                    AppColors.secondary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.22),
                                ),
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                color: AppColors.goldLight,
                                size: AppIconSize.md,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            const Expanded(
                              child: Text(
                                'Restablece tu acceso',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppTextSize.section,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Ingresa tu correo y te enviaremos un enlace para recuperar tu contraseña.',
                          style: TextStyle(
                            color: AppColors.textOnDarkMuted,
                            height: 1.45,
                            fontSize: AppTextSize.base,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.authTop),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.formNotice),
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
                                Icons.info_outline_rounded,
                                color: AppColors.goldLight,
                                size: AppIconSize.compact,
                              ),
                              SizedBox(width: AppSpacing.gutter),
                              Expanded(
                                child: Text(
                                  'Usa el mismo correo con el que registraste tu cuenta en Hábito.',
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
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          autofocus: true,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration(
                            label: 'Correo electrónico',
                            icon: Icons.alternate_email_rounded,
                          ),
                          validator: FormValidators.email,
                        ),
                        const SizedBox(height: AppIconSize.inline),
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.actionHeight,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
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
                            child: _isSubmitting
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
                                    'Enviar enlace',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: AppTextSize.titleMedium,
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
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: AppColors.secondary),
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
