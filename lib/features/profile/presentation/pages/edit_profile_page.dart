import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/ecuador_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/validators/ecuador_id_validator.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../auth/provider/auth_provider.dart';

const List<String> _editableIdentificationTypes = <String>[
  'cedula',
  'ruc',
  'pasaporte',
];

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _picker = ImagePicker();

  String _contactType = 'individual';
  String _identificationType = 'cedula';
  String _province = 'Azuay';
  String? _photoPath;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _firstNameCtrl.text = user?.firstName ?? '';
    _middleNameCtrl.text = user?.middleName ?? '';
    _lastNameCtrl.text = user?.lastName ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _birthdayCtrl.text = user?.birthday ?? '';
    _addressCtrl.text = user?.address ?? '';
    _businessNameCtrl.text = user?.businessName ?? '';
    _taxNumberCtrl.text = user?.taxNumber ?? '';
    _cityCtrl.text =
        (user?.city.trim().isNotEmpty ?? false) ? user!.city.trim() : 'Cuenca';
    _contactType = _normalizeContactType(user?.contactType);
    _identificationType =
        _normalizeIdentificationType(user?.identificationType);
    _province =
        kEcuadorProvinces.contains(user?.province) ? user!.province : 'Azuay';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _birthdayCtrl.dispose();
    _addressCtrl.dispose();
    _businessNameCtrl.dispose();
    _taxNumberCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (file == null || !mounted) return;

    setState(() {
      _photoPath = file.path;
      _removePhoto = false;
    });
  }

  Future<void> _pickBirthday() async {
    final initialDate = _parseDate(_birthdayCtrl.text) ?? DateTime(1995, 1, 1);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.secondary,
              surface: AppColors.cardDark,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (selected == null || !mounted) return;

    _birthdayCtrl.text = _formatIsoDate(selected);
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      birthday: _birthdayCtrl.text.trim(),
      contactType: _contactType,
      businessName: _businessNameCtrl.text.trim(),
      identificationType: _identificationType,
      taxNumber: _taxNumberCtrl.text.trim(),
      province: _province,
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      photoPath: _photoPath,
      removePhoto: _removePhoto,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente.'),
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
            backgroundColor: AppColors.primaryMuted,
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
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;

        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'Mis datos personales',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screen,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(
                        AppSpacing.xl - AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: AppRadius.extraLarge,
                      ),
                      child: Column(
                        children: [
                          _ProfilePhoto(
                            photoUrl: user?.photoUrl ?? '',
                            localPhotoPath: _photoPath,
                          ),
                          const SizedBox(height: AppSpacing.cartItemGap),
                          Wrap(
                            spacing: AppSpacing.sm + AppSpacing.xxs,
                            runSpacing: AppSpacing.sm + AppSpacing.xxs,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: auth.isLoading ? null : _pickPhoto,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.secondary,
                                  side: const BorderSide(
                                    color: AppColors.secondary,
                                  ),
                                ),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Subir foto'),
                              ),
                              if ((user?.photoUrl ?? '').isNotEmpty ||
                                  (_photoPath?.isNotEmpty ?? false))
                                TextButton.icon(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _photoPath = null;
                                            _removePhoto = true;
                                          });
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Quitar foto'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Datos personales',
                            style: TextStyle(
                              color: AppColors.borderStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.cartItemGap),
                          TextFormField(
                            controller: _firstNameCtrl,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.givenName],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Primer nombre',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) => FormValidators.requiredText(
                              value,
                              field: 'tu primer nombre',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _middleNameCtrl,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.middleName],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Segundo nombre',
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _lastNameCtrl,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.familyName],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Apellidos',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (value) => FormValidators.requiredText(
                              value,
                              field: 'tus apellidos',
                            ),
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
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) return null;
                              return FormValidators.phone(value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Facturacion (Ecuador)',
                            style: TextStyle(
                              color: AppColors.borderStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                              height: AppSpacing.sm + AppSpacing.xxs),
                          const Text(
                            'Estos datos se usan para reservas, compras y vinculacion correcta con tu contacto en caja.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          DropdownButtonFormField<String>(
                            initialValue: _contactType,
                            dropdownColor: AppColors.primaryMuted,
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
                                label: 'Razon social (opcional)',
                                icon: Icons.business_outlined,
                              ),
                              validator: (value) {
                                if (_contactType != 'business') return null;
                                if ((value ?? '').trim().isEmpty) return null;
                                return FormValidators.requiredMaxLength(
                                  value,
                                  field: 'la razón social',
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          DropdownButtonFormField<String>(
                            initialValue: _identificationType,
                            dropdownColor: AppColors.primaryMuted,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Tipo de identificacion',
                              icon: Icons.credit_card_outlined,
                            ),
                            items: _availableIdentificationTypes
                                .map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      kIdentificationTypeLabels[type] ?? type,
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
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _taxNumberCtrl,
                            keyboardType: _identificationType == 'pasaporte'
                                ? TextInputType.text
                                : TextInputType.number,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: '$_documentLabel (opcional)',
                              icon: Icons.badge_outlined,
                            ),
                            validator: _validateIdentificationNumber,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          DropdownButtonFormField<String>(
                            initialValue: _province,
                            dropdownColor: AppColors.primaryMuted,
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
                              label: 'Canton o ciudad (opcional)',
                              icon: Icons.location_city_outlined,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) return null;
                              return FormValidators.requiredText(
                                value,
                                field: 'el canton o ciudad',
                              );
                            },
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
                              label: 'Dirección principal (opcional)',
                              icon: Icons.home_outlined,
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) return null;
                              return FormValidators.requiredMaxLength(
                                value,
                                field: 'la dirección principal',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informacion adicional',
                            style: TextStyle(
                              color: AppColors.borderStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.cartItemGap),
                          TextFormField(
                            controller: _birthdayCtrl,
                            readOnly: true,
                            keyboardType: TextInputType.datetime,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.birthday],
                            onTap: auth.isLoading ? null : _pickBirthday,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                              label: 'Cumpleanos (opcional)',
                              icon: Icons.cake_outlined,
                              suffix: IconButton(
                                tooltip: 'Seleccionar fecha de cumpleaños',
                                onPressed:
                                    auth.isLoading ? null : _pickBirthday,
                                icon: const Icon(
                                  Icons.calendar_month_outlined,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final raw = (value ?? '').trim();
                              if (raw.isEmpty) return null;
                              if (_parseDate(raw) == null) {
                                return 'Usa una fecha válida';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                    SizedBox(
                      height: AppSpacing.actionHeight,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.tile,
                          ),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: AppIconSize.progress,
                                height: AppIconSize.progress,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppSpacing.progressStroke +
                                      AppSpacing.xxs / 10,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
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
        );
      },
    );
  }

  String _normalizeContactType(String? value) {
    return value == 'business' ? 'business' : 'individual';
  }

  String _normalizeIdentificationType(String? value) {
    return _editableIdentificationTypes.contains(value) ? value! : 'cedula';
  }

  List<String> get _availableIdentificationTypes {
    if (_contactType == 'business') return const ['ruc'];
    return _editableIdentificationTypes;
  }

  String get _documentLabel {
    final label =
        kIdentificationTypeLabels[_identificationType] ?? _identificationType;
    return 'Número de $label';
  }

  String? _validateIdentificationNumber(String? value) {
    if ((value ?? '').trim().isEmpty) return null;

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
      fillColor: AppColors.primaryMuted,
      border: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: const BorderSide(
          color: AppColors.secondary,
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: const BorderSide(
          color: AppColors.danger,
          width: 1.2,
        ),
      ),
    );
  }

  DateTime? _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _FieldCard extends StatelessWidget {
  final Widget child;

  const _FieldCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: AppRadius.extraLarge,
      ),
      child: child,
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final String photoUrl;
  final String? localPhotoPath;

  const _ProfilePhoto({
    required this.photoUrl,
    required this.localPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? image;

    if ((localPhotoPath ?? '').isNotEmpty) {
      image = FileImage(File(localPhotoPath!));
    } else if (photoUrl.isNotEmpty) {
      image = habitoCachedImageProvider(photoUrl);
    }

    return CircleAvatar(
      radius: AppIconSize.optionBadge + AppSpacing.xs + AppSpacing.xxs,
      backgroundColor: AppColors.secondary,
      backgroundImage: image,
      child: image == null
          ? const Icon(
              Icons.person,
              size: AppIconSize.pointsBadge,
              color: Colors.black,
            )
          : null,
    );
  }
}
