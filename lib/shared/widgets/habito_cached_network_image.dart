import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

const Map<String, String> habitoImageHeaders = {
  'Accept': 'image/avif,image/webp,image/*,*/*',
};

class HabitoCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  const HabitoCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final url = normalizeHabitoImageUrl(imageUrl);

    if (url.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    Widget buildImage({
      required int? memCacheWidth,
      required int? memCacheHeight,
    }) {
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: habitoImageHeaders,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 140),
        fadeOutDuration: const Duration(milliseconds: 80),
        placeholder: (_, __) =>
            placeholder ?? const ColoredBox(color: AppColors.surfaceMuted),
        errorWidget: (_, __, ___) =>
            errorWidget ??
            const Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final configuredTargetWidth = _cacheExtent(width, pixelRatio);
    final configuredTargetHeight = _cacheExtent(height, pixelRatio);

    Widget image = LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = configuredTargetWidth ??
            _cacheExtent(
              constraints.hasBoundedWidth ? constraints.maxWidth : null,
              pixelRatio,
            );
        final targetHeight = configuredTargetHeight ??
            _cacheExtent(
              constraints.hasBoundedHeight ? constraints.maxHeight : null,
              pixelRatio,
            );

        return buildImage(
          memCacheWidth: targetWidth,
          memCacheHeight: targetHeight,
        );
      },
    );

    final label = semanticLabel?.trim() ?? '';

    if (label.isEmpty) {
      return image;
    }

    return Semantics(
      label: label,
      image: true,
      child: image,
    );
  }

  int? _cacheExtent(double? logicalExtent, double pixelRatio) {
    if (logicalExtent == null ||
        !logicalExtent.isFinite ||
        logicalExtent <= 0) {
      return null;
    }

    return (logicalExtent * pixelRatio).round().clamp(1, 4096).toInt();
  }
}

ImageProvider<Object>? habitoCachedImageProvider(String imageUrl) {
  final url = normalizeHabitoImageUrl(imageUrl);
  if (url.isEmpty) return null;

  return CachedNetworkImageProvider(
    url,
    headers: habitoImageHeaders,
  );
}

String normalizeHabitoImageUrl(String imageUrl) {
  final rawUrl = imageUrl.trim();
  if (rawUrl.isEmpty) return '';

  final uri = Uri.tryParse(rawUrl);
  if (uri != null && uri.hasScheme) {
    return rawUrl;
  }

  final apiUri = Uri.tryParse(AppConfig.apiBaseUrl);
  if (apiUri == null || !apiUri.hasScheme || apiUri.host.isEmpty) {
    return rawUrl;
  }

  if (rawUrl.startsWith('//')) {
    return '${apiUri.scheme}:$rawUrl';
  }

  final origin = '${apiUri.scheme}://${apiUri.host}';
  final port = apiUri.hasPort ? ':${apiUri.port}' : '';
  final path = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';

  return '$origin$port$path';
}
