import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LocationLauncherService {
  LocationLauncherService._();

  static const Duration _resolveTimeout = Duration(seconds: 8);

  static Future<bool> openMap({
    String? address,
    double? latitude,
    double? longitude,
    String? branchName,
    String? description,
  }) async {
    final explicitUrl = extractLocationUrl(description) ??
        extractLocationUrl(address) ??
        extractLocationUrl(branchName);

    if (explicitUrl != null) {
      final uri = Uri.tryParse(explicitUrl);
      if (uri != null && await _tryLaunchExternalUri(uri)) return true;
    }

    final hasCoordinates = hasUsableCoordinates(latitude, longitude);
    final searchQuery = hasCoordinates
        ? '${latitude!.toStringAsFixed(7)},${longitude!.toStringAsFixed(7)}'
        : buildLocationSearchQuery(
            address: address,
            branchName: branchName,
          );

    if (searchQuery.isEmpty) return false;

    final mapUris = <Uri>[
      Uri.https(
        'www.google.com',
        '/maps/dir/',
        {
          'api': '1',
          'destination': searchQuery,
          'travelmode': 'driving',
        },
      ),
      Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': searchQuery,
        },
      ),
    ];

    for (final uri in mapUris) {
      if (await _tryLaunchExternalUri(uri)) return true;
    }

    return false;
  }

  static String? extractLocationUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final text = value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    final hrefMatch = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(text);
    final href = hrefMatch?.group(1)?.trim();

    if (_isSupportedLocationUrl(href)) return href;

    final urlMatch = RegExp(
      r'''((?:https?:\/\/|geo:|google\.navigation:|comgooglemaps:\/\/)[^\s<>"']+)''',
      caseSensitive: false,
    ).firstMatch(text);
    var url = urlMatch?.group(1)?.trim();

    if (url != null) {
      url = url.replaceAll(RegExp(r'[),.;]+$'), '');
    }

    return _isSupportedLocationUrl(url) ? url : null;
  }

  static LocationCoordinates? extractCoordinatesFromText(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final text = _decodeUrlText(value);
    final patterns = [
      RegExp(
        r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:[?&](?:q|query|destination|daddr)=)(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'geo:(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final latitude = double.tryParse(match?.group(1) ?? '');
      final longitude = double.tryParse(match?.group(2) ?? '');

      if (hasUsableCoordinates(latitude, longitude)) {
        return LocationCoordinates(latitude!, longitude!);
      }
    }

    return null;
  }

  static Future<LocationCoordinates?> resolveCoordinatesFromText(
    String? value,
  ) async {
    final direct = extractCoordinatesFromText(value);
    if (direct != null) return direct;

    final url = extractLocationUrl(value);
    if (url == null) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme.toLowerCase())) {
      return null;
    }

    final client = http.Client();

    try {
      final request = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 10
        ..headers.addAll({
          'Accept': 'text/html,application/xhtml+xml,application/xml',
          'User-Agent': 'HabitoApp/1.0',
        });

      final response = await client.send(request).timeout(_resolveTimeout);
      final resolvedUrl = response.request?.url.toString();
      final resolvedFromUrl = extractCoordinatesFromText(resolvedUrl);
      if (resolvedFromUrl != null) {
        await response.stream.drain<void>();
        return resolvedFromUrl;
      }

      final body = await response.stream.bytesToString();

      return extractCoordinatesFromText(body);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static bool hasUsableCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude.abs() > 90 || longitude.abs() > 180) return false;
    return !(latitude == 0 && longitude == 0);
  }

  static String buildLocationSearchQuery({
    String? address,
    String? branchName,
  }) {
    final parts = <String>[];
    final cleanBranch = branchName?.trim() ?? '';
    final cleanAddress = address?.trim() ?? '';

    if (cleanBranch.isNotEmpty) parts.add(cleanBranch);
    if (cleanAddress.isNotEmpty && !cleanBranch.contains(cleanAddress)) {
      parts.add(cleanAddress);
    }

    return parts.join(' ').trim();
  }

  static bool _isSupportedLocationUrl(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme.isEmpty) return false;

    return [
      'http',
      'https',
      'geo',
      'google.navigation',
      'comgooglemaps',
    ].contains(uri.scheme.toLowerCase());
  }

  static Future<bool> _tryLaunchExternalUri(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Probamos con el modo por defecto como respaldo.
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  static String _decodeUrlText(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }
}

class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates(this.latitude, this.longitude);
}
