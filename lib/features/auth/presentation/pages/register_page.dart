import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/ecuador_data.dart';
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
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            content: Text(
              auth.error!,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const bg = Color(0xFF111111);

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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF171717),
                          Color(0xFF111111),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _sectionTitle('Datos personales'),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final singleColumn = constraints.maxWidth < 390;

                                if (singleColumn) {
                                  return Column(
                                    children: [
                                      _buildFirstNameField(),
                                      const SizedBox(height: 16),
                                      _buildMiddleNameField(),
                                      const SizedBox(height: 16),
                                      _buildLastNameField(),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: _buildFirstNameField()),
                                    const SizedBox(width: 14),
                                    Expanded(child: _buildMiddleNameField()),
                                    const SizedBox(width: 14),
                                    Expanded(child: _buildLastNameField()),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
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
                              validator: (value) {
                                final digits =
                                    (value ?? '').replaceAll(RegExp(r'\D'), '');
                                if (digits.isEmpty) {
                                  return 'Ingresa tu celular';
                                }
                                if (digits.length < 8) {
                                  return 'Celular invalido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
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
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Ingresa tu correo';
                                if (!v.contains('@')) return 'Correo invalido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            _sectionTitle('Facturacion (Ecuador)'),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: Color(0xFFE7D39A),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Usaremos estos datos para tus facturas, reservas y futura vinculacion con puntos y compras en local.',
                                      style: TextStyle(
                                        color: Color(0xFFD3CDC5),
                                        height: 1.38,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _contactType,
                              dropdownColor: const Color(0xFF222222),
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _businessNameCtrl,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'Razon social',
                                  icon: Icons.business_outlined,
                                ),
                                validator: (value) {
                                  if (_contactType != 'business') return null;
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Ingresa la razon social';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final singleColumn = constraints.maxWidth < 390;

                                final identificationTypeField =
                                    DropdownButtonFormField<String>(
                                  initialValue: _identificationType,
                                  dropdownColor: const Color(0xFF222222),
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
                                      const SizedBox(height: 16),
                                      taxNumberField,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: identificationTypeField),
                                    const SizedBox(width: 14),
                                    Expanded(child: taxNumberField),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _province,
                              dropdownColor: const Color(0xFF222222),
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cityCtrl,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Canton o ciudad',
                                icon: Icons.location_city_outlined,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Ingresa el canton o ciudad';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressCtrl,
                              maxLines: 3,
                              minLines: 2,
                              textInputAction: TextInputAction.newline,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Direccion principal',
                                icon: Icons.home_outlined,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Ingresa la direccion principal';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            _sectionTitle('Acceso'),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                label: 'Contrasena',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordCtrl,
                              obscureText: _obscureConfirmPassword,
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
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
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.black,
                                        ),
                                      )
                                    : const Text(
                                        'Crear cuenta',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Color(0xFFE7D39A),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tu cuenta Habito',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Crea tu cuenta para reservar mas rapido, consultar tus puntos y dejar tus datos de facturacion listos para compras y servicios.',
          style: TextStyle(
            color: Color(0xFFD3CDC5),
            height: 1.45,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE7D39A),
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameCtrl,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Nombre de pila',
        icon: Icons.person_outline_rounded,
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Ingresa tu nombre de pila';
        return null;
      },
    );
  }

  Widget _buildMiddleNameField() {
    return TextFormField(
      controller: _middleNameCtrl,
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
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.familyName],
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Apellido',
        icon: Icons.badge_outlined,
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Ingresa tu apellido';
        return null;
      },
    );
  }

  String get _documentLabel {
    final label = kIdentificationTypeLabels[_identificationType] ??
        _identificationType;
    return 'Numero de $label';
  }

  List<String> get _availableIdentificationTypes {
    if (_contactType == 'business') return const ['ruc'];
    return _appIdentificationTypes;
  }

  String? _validateIdentificationNumber(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Ingresa tu $_documentLabel';
    }

    if (_identificationType == 'cedula') {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10) {
        return 'La cedula debe tener 10 digitos';
      }
      return null;
    }

    if (_identificationType == 'ruc') {
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 13) {
        return 'El RUC debe tener 13 digitos';
      }
      return null;
    }

    if (text.length < 5) {
      return 'Ingresa un pasaporte valido';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF222222),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFD4AF37),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
    );
  }
}
