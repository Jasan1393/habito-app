import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'location_launcher_service.dart';

class LocationCoordinateCacheService {
  LocationCoordinateCacheService._();

  static const String _fileName = 'location_coordinate_cache.json';
  static final Map<String, LocationCoordinates> _memoryCache = {};
  static bool _isLoaded = false;

  static Future<LocationCoordinates?> get(String key) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return null;

    await _ensureLoaded();
    return _memoryCache[normalizedKey];
  }

  static Future<void> put(String key, LocationCoordinates coordinates) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;
    if (!LocationLauncherService.hasUsableCoordinates(
      coordinates.latitude,
      coordinates.longitude,
    )) {
      return;
    }

    await _ensureLoaded();
    _memoryCache[normalizedKey] = coordinates;
    await _save();
  }

  static Future<void> putMany(
    Map<String, LocationCoordinates> coordinatesByKey,
  ) async {
    final validEntries = coordinatesByKey.entries.where((entry) {
      return entry.key.trim().isNotEmpty &&
          LocationLauncherService.hasUsableCoordinates(
            entry.value.latitude,
            entry.value.longitude,
          );
    });

    if (validEntries.isEmpty) return;

    await _ensureLoaded();
    for (final entry in validEntries) {
      _memoryCache[entry.key.trim()] = entry.value;
    }
    await _save();
  }

  static Future<void> _ensureLoaded() async {
    if (_isLoaded) return;

    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        _isLoaded = true;
        return;
      }

      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        _isLoaded = true;
        return;
      }

      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;

        final latitude = _parseDouble(value['latitude']);
        final longitude = _parseDouble(value['longitude']);
        if (!LocationLauncherService.hasUsableCoordinates(
          latitude,
          longitude,
        )) {
          continue;
        }

        _memoryCache[entry.key.toString()] = LocationCoordinates(
          latitude!,
          longitude!,
        );
      }
    } catch (_) {
      _memoryCache.clear();
    } finally {
      _isLoaded = true;
    }
  }

  static Future<void> _save() async {
    try {
      final file = await _cacheFile();
      final payload = _memoryCache.map(
        (key, coordinates) => MapEntry(
          key,
          {
            'latitude': coordinates.latitude,
            'longitude': coordinates.longitude,
            'updated_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // La pantalla puede seguir funcionando con el caché en memoria.
    }
  }

  static Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
