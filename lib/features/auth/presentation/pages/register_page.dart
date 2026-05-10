import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/ecuador_data.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/validators/ecuador_id_validator.dart';
import '../../../../core/validators/form_validators.dart';
import '../../provider/auth_provider.dart';

const List<String> _appIdentificationTypes = <String>[
  'cedula',
  'ruc',
  'pasaporte',
];

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _contactType = 'individual';
  String _identificationType = 'cedula';
  String _province = 'Guayas';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _businessNameCtrl.dispose();
    _taxNumberCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      firstName: _firstNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      contactType: _contactType,
      businessName: _businessNameCtrl.text.trim(),
      identificationType: _identificationType,
      taxNumber: _taxNumberCtrl.text.trim(),
      province: _province,
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Cuenta creada correctamente.'),
          ),
        );

      Navigator.pop(context, true);
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

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AppConfig.privacyPolicyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.secondary;
    const bg = AppColors.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Crear cuenta',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
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
                  constraints: const BoxConstraints(maxWidth: 520),
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
                            _buildHeader(),
                            const SizedBox(height: AppSpacing.xl),
                            _sectionTitle('Datos personales'),
                            const SizedBox(height: AppSpacing.formNotice),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final singleColumn = constraints.maxWidth < 390;

                                if (singleColumn) {
                                  return Column(
                                    children: [
                                      _buildFirstNameField(),
                                      const SizedBox(height: AppSpacing.lg),
                                      _buildMiddleNameField(),
                                      const SizedBox(height: AppSpacing.lg),
                                      _buildLastNameField(),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: _buildFirstNameField()),
                                    const SizedBox(
                                        width: AppSpacing.formNotice),
                                    Expanded(child: _buildMiddleNameField()),
                                    const SizedBox(
                                        width: AppSpacing.formNotice),
                                    Expanded(child: _buildLastNameField()),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Celular',
                                icon: Icons.phone_outlined,
                              ),
                              validator: FormValidators.phone,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Correo electronico',
                                icon: Icons.alternate_email_rounded,
                              ),
                              validator: FormValidators.email,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _sectionTitle('Facturacion (Ecuador)'),
                            const SizedBox(height: AppSpacing.gutter),
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
                                    Icons.receipt_long_outlined,
                                    color: AppColors.goldLight,
                                    size: AppIconSize.compact,
                                  ),
                                  SizedBox(width: AppSpacing.gutter),
                                  Expanded(
                                    child: Text(
                                      'Usaremos estos datos para tus facturas, reservas y futura vinculacion con puntos y compras en local.',
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
                            const SizedBox(height: AppSpacing.lg),
                            DropdownButtonFormField<String>(
                              initialValue: _contactType,
                              dropdownColor: AppColors.darkInput,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Tipo de cliente',
                                icon: Icons.apartment_outlined,
                              ),
                              items: kContactTypeLabels.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _contactType = value;
                                  if (_contactType == 'business') {
                                    _identificationType = 'ruc';
                                  }
                                });
                              },
                            ),
                            if (_contactType == 'business') ...[
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _businessNameCtrl,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.organizationName,
                                ],
                                maxLength: FormValidators.longTextMaxLength,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'Razon social',
                                  icon: Icons.business_outlined,
                                ),
                                validator: (value) {
                                  if (_contactType != 'business') return null;
                                  return FormValidators.requiredMaxLength(
                                    value,
                                    field: 'la razón social',
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final singleColumn = constraints.maxWidth < 390;

                                final identificationTypeField =
                                    DropdownButtonFormField<String>(
                                  initialValue: _identificationType,
                                  dropdownColor: AppColors.darkInput,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    label: 'Tipo de identificacion',
                                    icon: Icons.badge_outlined,
                                  ),
                                  items: _availableIdentificationTypes
                                      .map(
                                        (type) => DropdownMenuItem<String>(
                                          value: type,
                                          child: Text(
                                            kIdentificationTypeLabels[type] ??
                                                type,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _identificationType = value;
                                    });
                                  },
                                );

                                final taxNumberField = TextFormField(
                                  controller: _taxNumberCtrl,
                                  keyboardType:
                                      _identificationType == 'pasaporte'
                                          ? TextInputType.text
                                          : TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                  ],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    label: _documentLabel,
                                    icon: Icons.credit_card_outlined,
                                  ),
                                  validator: (value) =>
                                      _validateIdentificationNumber(value),
                                );

                                if (singleColumn) {
                                  return Column(
                                    children: [
                                      identificationTypeField,
                                      const SizedBox(height: AppSpacing.lg),
                                      taxNumberField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: identificationTypeField),
                                    const SizedBox(
                                        width: AppSpacing.formNotice),
                                    Expanded(child: taxNumberField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            DropdownButtonFormField<String>(
                              initialValue: _province,
                              dropdownColor: AppColors.darkInput,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Provincia',
                                icon: Icons.map_outlined,
                              ),
                              items: kEcuadorProvinces
                                  .map(
                                    (province) => DropdownMenuItem<String>(
                                      value: province,
                                      child: Text(province),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _province = value;
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _cityCtrl,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.addressCity],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Canton o ciudad',
                                icon: Icons.location_city_outlined,
                              ),
                              validator: (value) => FormValidators.requiredText(
                                value,
                                field: 'el canton o ciudad',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _addressCtrl,
                              keyboardType: TextInputType.streetAddress,
                              maxLines: 3,
                              minLines: 2,
                              textInputAction: TextInputAction.newline,
                              autofillHints: const [
                                AutofillHints.fullStreetAddress,
                              ],
                              maxLength: FormValidators.longTextMaxLength,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Direccion principal',
                                icon: Icons.home_outlined,
                              ),
                              validator: (value) =>
                                  FormValidators.requiredMaxLength(
                                value,
                                field: 'la direccion principal',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _sectionTitle('Acceso'),
                            const SizedBox(height: AppSpacing.formNotice),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Contrasena',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Mostrar contrasena'
                                      : 'Ocultar contrasena',
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
                                if (v.isEmpty) return 'Ingresa una contrasena';
                                if (v.length < 8) {
                                  return 'Minimo 8 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: _confirmPasswordCtrl,
                              obscureText: _obscureConfirmPassword,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) {
                                if (!auth.isLoading) _submit();
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Confirmar contrasena',
                                icon: Icons.lock_person_outlined,
                                suffix: IconButton(
                                  tooltip: _obscureConfirmPassword
                                      ? 'Mostrar confirmación'
                                      : 'Ocultar confirmación',
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Confirma tu contrasena';
                                }
                                if (value != _passwordCtrl.text) {
                                  return 'Las contrasenas no coinciden';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl),
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
                                        'Crear cuenta',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppTextSize.titleMedium,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Center(
                              child: TextButton.icon(
                                onPressed: _openPrivacyPolicy,
                                icon: const Icon(Icons.privacy_tip_outlined),
                                label: const Text('Ver política de privacidad'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.goldLight,
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
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppIconSize.authBadge,
              height: AppIconSize.authBadge,
              decoration: BoxDecoration(
                borderRadius: AppRadius.medium,
                color: AppColors.secondary.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.goldLight,
                size: AppIconSize.md,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text(
                'Tu cuenta Habito',
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
          'Crea tu cuenta para reservar más rápido, consultar tus puntos y dejar tus datos de facturación listos para compras y servicios.',
          style: TextStyle(
            color: AppColors.textOnDarkMuted,
            height: 1.45,
            fontSize: AppTextSize.base,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.goldLight,
        fontSize: AppTextSize.titleSmall,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameCtrl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Primer nombre',
        icon: Icons.person_outline_rounded,
      ),
      validator: (value) =>
          FormValidators.requiredText(value, field: 'tu primer nombre'),
    );
  }

  Widget _buildMiddleNameField() {
    return TextFormField(
      controller: _middleNameCtrl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.middleName],
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Segundo nombre',
        icon: Icons.person_outline_rounded,
      ),
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameCtrl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Apellidos',
        icon: Icons.badge_outlined,
      ),
      validator: (value) =>
          FormValidators.requiredText(value, field: 'tus apellidos'),
    );
  }

  String get _documentLabel {
    final label =
        kIdentificationTypeLabels[_identificationType] ?? _identificationType;
    return 'Número de $label';
  }

  List<String> get _availableIdentificationTypes {
    if (_contactType == 'business') return const ['ruc'];
    return _appIdentificationTypes;
  }

  String? _validateIdentificationNumber(String? value) {
    return EcuadorIdValidator.validate(
      identificationType: _identificationType,
      value: value,
      emptyMessage: 'Ingresa tu $_documentLabel.',
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
