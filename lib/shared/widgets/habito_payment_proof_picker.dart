import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icon_size.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_size.dart';

class HabitoPaymentProofSelection {
  final XFile file;
  final int sizeBytes;
  final Uint8List previewBytes;

  const HabitoPaymentProofSelection({
    required this.file,
    required this.sizeBytes,
    required this.previewBytes,
  });

  String get path => file.path;
  String get name => _fileNameFor(file);
  String get sizeLabel => HabitoPaymentProofPicker.formatSize(sizeBytes);
}

class HabitoPaymentProofPicker {
  HabitoPaymentProofPicker._();

  static const int maxSizeBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};
  static const Set<String> _allowedMimeTypes = {'image/jpeg', 'image/png'};

  static Future<HabitoPaymentProofSelection?> pickAndConfirm(
    BuildContext context, {
    void Function(String message)? showMessage,
  }) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );

    if (picked == null) return null;

    final validationMessage = await validate(picked);
    if (!context.mounted) return null;

    if (validationMessage != null) {
      _showMessage(context, validationMessage, showMessage);
      return null;
    }

    late final Uint8List previewBytes;
    try {
      previewBytes = await picked.readAsBytes();
    } catch (_) {
      if (!context.mounted) return null;

      _showMessage(
        context,
        'No pudimos leer la imagen seleccionada. Intenta con otra foto.',
        showMessage,
      );
      return null;
    }

    if (!context.mounted) return null;

    final sizeBytes = await picked.length();
    if (!context.mounted) return null;

    final selection = HabitoPaymentProofSelection(
      file: picked,
      sizeBytes: sizeBytes,
      previewBytes: previewBytes,
    );
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentProofPreviewSheet(selection: selection),
    );

    return confirmed == true ? selection : null;
  }

  static Future<String?> validate(XFile file) async {
    final extension = _extensionFor(file).toLowerCase();
    final mimeType = (file.mimeType ?? '').toLowerCase().trim();
    final hasAllowedExtension = _allowedExtensions.contains(extension);
    final hasAllowedMime = _allowedMimeTypes.contains(mimeType);

    if (!hasAllowedExtension && !hasAllowedMime) {
      return 'El comprobante debe ser una imagen JPG, JPEG o PNG.';
    }

    final sizeBytes = await file.length();

    if (sizeBytes <= 0) {
      return 'La imagen seleccionada esta vacia. Intenta con otra foto.';
    }

    if (sizeBytes > maxSizeBytes) {
      return 'La imagen pesa ${formatSize(sizeBytes)}. El maximo permitido es 5 MB.';
    }

    return null;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  static void _showMessage(
    BuildContext context,
    String message,
    void Function(String message)? showMessage,
  ) {
    if (showMessage != null) {
      showMessage(message);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.snackBarDark,
          content: Text(message),
        ),
      );
  }
}

class _PaymentProofPreviewSheet extends StatelessWidget {
  final HabitoPaymentProofSelection selection;

  const _PaymentProofPreviewSheet({required this.selection});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.bottomSheet,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xxxl,
                height: AppSpacing.xs,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Container(
                  width: AppIconSize.successBadge,
                  height: AppIconSize.successBadge,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.infoSoft,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.info,
                    size: AppIconSize.lg,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revisa tu comprobante',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTextSize.section,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Confirma que la imagen sea clara antes de subirla.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.extraLarge,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.light,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.large,
                child: Image.memory(
                  selection.previewBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.goldSurface,
                borderRadius: AppRadius.large,
                border: Border.all(color: AppColors.goldLight),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    color: AppColors.goldDeep,
                    size: AppIconSize.md,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      selection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    selection.sizeLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.large,
                      ),
                      padding: AppSpacing.button,
                    ),
                    child: const Text(
                      'Cambiar foto',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.large,
                      ),
                      padding: AppSpacing.button,
                    ),
                    icon: const Icon(
                      Icons.cloud_upload_outlined,
                      size: AppIconSize.sm,
                    ),
                    label: const Text(
                      'Subir',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _fileNameFor(XFile file) {
  final name = file.name.trim();
  if (name.isNotEmpty) return name;
  final path = file.path.trim();
  if (path.isEmpty) return 'comprobante';
  return path.split(RegExp(r'[\\/]')).last;
}

String _extensionFor(XFile file) {
  final name = _fileNameFor(file);
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == name.length - 1) return '';
  return name.substring(dotIndex + 1);
}
