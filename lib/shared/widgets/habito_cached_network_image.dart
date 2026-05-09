import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

const Map<String, String> habitoImageHeaders = {
  'Accept': 'image/avif,image/webp,image/*,*/*',
};

class HabitoCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  const HabitoCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    if (url.isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final image = CachedNetworkImage(
      imageUrl: url,
      httpHeaders: habitoImageHeaders,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      fadeInDuration: const Duration(milliseconds: 140),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) =>
          placeholder ?? const ColoredBox(color: AppColors.surfaceMuted),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          const Center(child: Icon(Icons.image_not_supported_outlined)),
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
}

ImageProvider<Object>? habitoCachedImageProvider(String imageUrl) {
  final url = imageUrl.trim();
  if (url.isEmpty) return null;

  return CachedNetworkImageProvider(
    url,
    headers: habitoImageHeaders,
  );
}
