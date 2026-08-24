import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_size.dart';

class AppUpdateInfo {
  final String currentVersion;
  final int currentBuild;
  final String latestVersion;
  final int latestBuild;
  final String updateUrl;
  final String notes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    required this.updateUrl,
    required this.notes,
    required this.forceUpdate,
  });
}

class AppUpdateService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _dismissedBuildKey = 'dismissed_app_update_build';
  static const String _androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.habitobarberia.app';
  static bool _dialogVisible = false;

  const AppUpdateService._();

  static Future<AppUpdateInfo?> checkForAvailableUpdate({
    bool ignoreDismissed = false,
  }) async {
    if (!Platform.isAndroid) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final currentBuild = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/app-update').replace(
      queryParameters: {
        'platform': 'android',
        'version': currentVersion,
        'build': currentBuild.toString(),
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ).timeout(AppConfig.authTimeout);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final data = decoded['data'];
    if (decoded['success'] != true || data is! Map<String, dynamic>) {
      return null;
    }

    final enabled = data['enabled'] == true;
    final updateAvailable = data['update_available'] == true;
    final storeUrl = (data['store_url'] ?? _androidStoreUrl).toString().trim();
    final latestVersion = (data['latest_version'] ?? '').toString().trim();
    final latestBuild = _parseInt(data['latest_build']);
    final newerThanInstalled = _isRemoteBuildNewer(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
    );

    if (!enabled ||
        !updateAvailable ||
        storeUrl.isEmpty ||
        !newerThanInstalled) {
      await _clearDismissedBuild();
      return null;
    }

    if (!ignoreDismissed &&
        latestBuild > 0 &&
        latestBuild == await _getDismissedBuild()) {
      return null;
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      latestVersion: latestVersion,
      latestBuild: latestBuild,
      updateUrl: storeUrl,
      notes: (data['notes'] ?? '').toString().trim(),
      forceUpdate: data['force_update'] == true,
    );
  }

  static Future<void> maybePromptForUpdate(BuildContext context) async {
    if (_dialogVisible || !context.mounted) return;

    try {
      final update = await checkForAvailableUpdate();
      if (update == null || !context.mounted) return;
      await _showUpdateDialog(context, update);
    } catch (_) {
      // No bloqueamos la app si la consulta de actualización falla.
    }
  }

  static Future<bool> checkNowAndPrompt(BuildContext context) async {
    if (_dialogVisible || !context.mounted) return false;

    try {
      final update = await checkForAvailableUpdate(ignoreDismissed: true);
      if (update == null) {
        return false;
      }

      if (!context.mounted) return false;
      await _showUpdateDialog(context, update);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    _dialogVisible = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.forceUpdate,
        builder: (dialogContext) {
          final notes = update.notes.isEmpty
              ? 'Tenemos mejoras y correcciones listas para esta versión.'
              : update.notes;

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    update.forceUpdate
                        ? 'Actualización importante'
                        : 'Nueva versión disponible',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu versión actual es ${update.currentVersion.isEmpty ? '-' : update.currentVersion} y ya está disponible la ${update.latestVersion.isEmpty ? 'nueva versión' : update.latestVersion}.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                if (update.latestBuild > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Build ${update.latestBuild}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    notes,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'La ficha oficial de Google Play se abrirá para completar la actualización de forma segura.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppTextSize.bodySmall,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              if (!update.forceUpdate)
                TextButton(
                  onPressed: () async {
                    await _rememberDismissedBuild(update.latestBuild);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Después'),
                ),
              ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final launched = await _launchStore(update.updateUrl);
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (!launched) {
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No pudimos abrir Google Play. Revisa tu conexión e intenta nuevamente.',
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text(
                  'Abrir Google Play',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogVisible = false;
    }
  }

  static Future<bool> _launchStore(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<int> _getDismissedBuild() async {
    final raw = await _storage.read(key: _dismissedBuildKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  static Future<void> _rememberDismissedBuild(int build) async {
    if (build <= 0) return;
    await _storage.write(key: _dismissedBuildKey, value: build.toString());
  }

  static Future<void> _clearDismissedBuild() async {
    await _storage.delete(key: _dismissedBuildKey);
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _isRemoteBuildNewer({
    required String currentVersion,
    required int currentBuild,
    required String latestVersion,
    required int latestBuild,
  }) {
    if (latestVersion.isNotEmpty && currentVersion.isNotEmpty) {
      final versionComparison = _compareVersions(latestVersion, currentVersion);
      if (versionComparison != 0) {
        return versionComparison > 0;
      }
    }

    if (latestBuild > 0 && currentBuild > 0) {
      return latestBuild > currentBuild;
    }

    return latestBuild > currentBuild;
  }

  static int _compareVersions(String a, String b) {
    final left =
        a.split('.').map((part) => int.tryParse(part.trim()) ?? 0).toList();
    final right =
        b.split('.').map((part) => int.tryParse(part.trim()) ?? 0).toList();
    final maxLength = left.length > right.length ? left.length : right.length;

    for (var i = 0; i < maxLength; i++) {
      final leftPart = i < left.length ? left[i] : 0;
      final rightPart = i < right.length ? right[i] : 0;

      if (leftPart > rightPart) return 1;
      if (leftPart < rightPart) return -1;
    }

    return 0;
  }
}
