import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icon_size.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_size.dart';

enum HabitoBankDataSheetAction {
  viewOrder,
  uploadProof,
}

class HabitoBankDataSheet extends StatelessWidget {
  final Map<String, dynamic> bankDetails;
  final String orderNumber;
  final String amountLabel;

  const HabitoBankDataSheet({
    super.key,
    required this.bankDetails,
    required this.orderNumber,
    required this.amountLabel,
  });

  static Future<HabitoBankDataSheetAction?> show(
    BuildContext context, {
    required Map<String, dynamic> bankDetails,
    required String orderNumber,
    required String amountLabel,
  }) {
    return showModalBottomSheet<HabitoBankDataSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitoBankDataSheet(
        bankDetails: bankDetails,
        orderNumber: orderNumber,
        amountLabel: amountLabel,
      ),
    );
  }

  String _read(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = bankDetails[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String get _bankName => _read(['bank_name', 'bankName', 'bank']);

  String get _accountType =>
      _read(['account_type', 'accountType', 'type'], 'Cuenta bancaria');

  String get _accountNumber =>
      _read(['account_number', 'accountNumber', 'number']);

  String get _accountHolder =>
      _read(['account_holder', 'accountHolder', 'holder', 'beneficiary']);

  String get _document =>
      _read(['identification', 'document', 'document_number', 'ruc']);

  String get _email => _read(['email', 'bank_email']);

  String get _whatsapp => _read([
        'whatsapp',
        'whatsapp_phone',
        'phone',
        'support_phone',
      ]);

  String get _instructions => _read(['instructions', 'note', 'message'],
      'Sube el comprobante para que podamos validar tu pago.');

  bool get _hasConfiguredAccount => _accountNumber.isNotEmpty;

  Future<void> _copyAccount(BuildContext context) async {
    if (!_hasConfiguredAccount) return;
    await Clipboard.setData(ClipboardData(text: _accountNumber));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Número de cuenta copiado.')),
      );
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final cleanPhone = _whatsapp.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;

    final message = Uri.encodeComponent(
      'Hola Habito, acabo de crear el pedido $orderNumber por $amountLabel y quiero enviar el comprobante.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos abrir WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.bottomSheet,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: AppRadius.full,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.panel,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.account_balance_rounded,
                        color: AppColors.secondary,
                        size: AppIconSize.xxl,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Datos para transferencia',
                        style: TextStyle(
                          color: AppColors.textOnDark,
                          fontSize: AppTextSize.headlineMedium,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Pedido $orderNumber - Total a pagar $amountLabel',
                        style: const TextStyle(
                          color: AppColors.textOnDarkMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_hasConfiguredAccount)
                  const _BankNotice(
                    icon: Icons.info_outline_rounded,
                    title: 'Datos bancarios pendientes',
                    message:
                        'El bridge aún no tiene una cuenta bancaria configurada. Puedes ver el pedido y subir el comprobante después de recibir la información del equipo.',
                  )
                else
                  _BankDetailsCard(
                    rows: [
                      _BankDetailRow('Banco', _bankName),
                      _BankDetailRow('Tipo de cuenta', _accountType),
                      _BankDetailRow('Número de cuenta', _accountNumber),
                      _BankDetailRow('Titular', _accountHolder),
                      _BankDetailRow('RUC / cédula', _document),
                      _BankDetailRow('Correo', _email),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                _BankNotice(
                  icon: Icons.receipt_long_outlined,
                  title: 'Luego de transferir',
                  message: _instructions,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hasConfiguredAccount
                            ? () => _copyAccount(context)
                            : null,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar cuenta'),
                      ),
                    ),
                    if (_whatsapp.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openWhatsapp(context),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.actionHeight,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      HabitoBankDataSheetAction.uploadProof,
                    ),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Subir comprobante'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.large,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.secondaryActionHeight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      HabitoBankDataSheetAction.viewOrder,
                    ),
                    child: const Text('Ver mi pedido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BankDetailsCard extends StatelessWidget {
  final List<_BankDetailRow> rows;

  const _BankDetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visibleRows = rows.where((row) => row.value.trim().isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final row in visibleRows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 124,
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    row.value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _BankNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _BankNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldDeep),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDetailRow {
  final String label;
  final String value;

  const _BankDetailRow(this.label, this.value);
}
