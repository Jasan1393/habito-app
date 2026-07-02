import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../data/services/habito_booking_api.dart';
import '../../data/services/habito_shop_api.dart';
import '../../provider/shop_provider.dart';
import 'cart_page.dart';
import 'product_detail_page.dart';
import 'products_archive_page.dart';
import 'services_archive_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loadingServices = true;
  bool _loadingProducts = true;
  String? _servicesError;
  String? _productsError;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome({bool forceRefresh = false}) async {
    await Future.wait([
      _loadServices(forceRefresh: forceRefresh),
      _loadProducts(forceRefresh: forceRefresh),
      _loadCategories(forceRefresh: forceRefresh),
    ]);
  }

  Future<void> _loadServices({bool forceRefresh = false}) async {
    setState(() {
      _loadingServices = true;
      _servicesError = null;
    });
    try {
      if (forceRefresh) {
        await HabitoBookingApi.clearServicesCache();
      }
      final items = await HabitoBookingApi.getServices(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _services = items
            .take(8)
            .whereType<Map>()
            .map((item) => _mapService(Map<String, dynamic>.from(item)))
            .toList();
        _loadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingServices = false;
        _servicesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });
    try {
      final items = await HabitoShopApi.getProducts(
        limit: 24,
        page: 1,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _products = items.take(8).toList();
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _productsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    try {
      final items = await HabitoShopApi.getCategories(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _categories = items;
      });
    } catch (_) {
      // Si fallan las categorías, no bloqueamos la tienda.
    }
  }

  Map<String, dynamic> _mapService(Map<String, dynamic> service) {
    final name = (service['name'] ?? 'Servicio').toString();
    final placeholderImage = _getServicePlaceholderImage(name);
    final imageUrl = HabitoBookingApi.extractServiceImageUrl(service);
    return {
      'id': service['id'],
      'title': name,
      'image': imageUrl,
      'imageUrl': imageUrl,
      'placeholderImage': placeholderImage,
      'price': '\$${_formatPrice(service['price'])}',
      'raw': service,
    };
  }

  String _getServicePlaceholderImage(String name) {
    return 'assets/images/services/Corte de Cabello.webp';
  }

  String _formatPrice(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed == parsed.roundToDouble()) return parsed.toStringAsFixed(0);
    return parsed.toStringAsFixed(2);
  }

  String _productPrice(Map<String, dynamic> product) {
    return '\$${_formatPrice(product['display_price'] ?? product['price_including_tax'] ?? product['price'] ?? product['regular_price'])}';
  }

  String _productCategory(Map<String, dynamic> product) {
    final raw = product['categories'];
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
    }
    return 'Producto';
  }

  String _productImage(Map<String, dynamic> product) {
    final raw = product['images'];
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['src'] != null) return first['src'].toString();
    }
    return '';
  }

  bool _inStock(Map<String, dynamic> product) {
    final value = product['in_stock'];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'instock';
    }
    return false;
  }

  void _openBooking(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingsPage(service: service)),
    );
  }

  void _openServicesArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServicesArchivePage()),
    );
  }

  void _openArchive({
    String initialSearch = '',
    String initialCategory = '',
    String initialCategoryName = '',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsArchivePage(
          initialSearch: initialSearch,
          initialCategory: initialCategory,
          initialCategoryName: initialCategoryName,
        ),
      ),
    );
  }

  Future<void> _openProduct(Map<String, dynamic> product) async {
    final id = int.tryParse((product['id'] ?? '').toString()) ?? 0;
    if (id <= 0) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productId: id,
          initialProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        searchHint: 'Buscar productos en tienda',
        cartCount: cartCount,
        onSearchTap: _openArchive,
        onCartTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          );
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: () => _loadHome(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _BlockHeader(
                title: 'Servicios',
                action: 'Ver todos',
                onTap: _openServicesArchive,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_servicesError != null && _services.isEmpty)
                _InfoCard(
                  message: _servicesError!,
                  label: 'Reintentar',
                  onTap: () => _loadServices(forceRefresh: true),
                )
              else if (_loadingServices)
                const _ServiceSkeleton()
              else if (_services.isEmpty)
                const _EmptyStrip(message: 'No hay servicios disponibles.')
              else
                SizedBox(
                  height: 264,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _services.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.md + AppSpacing.xs),
                    itemBuilder: (context, index) => _CatalogReveal(
                      index: index,
                      child: _ServiceCard(
                        service: _services[index],
                        onTap: () => _openBooking(_services[index]),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl - AppSpacing.xs),
              _BlockHeader(
                title: 'Productos destacados',
                action: 'Ver más',
                onTap: _openArchive,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_productsError != null && _products.isEmpty)
                _InfoCard(
                  message: _productsError!,
                  label: 'Reintentar',
                  onTap: () => _loadProducts(forceRefresh: true),
                )
              else if (_loadingProducts)
                const _ProductSkeleton()
              else if (_products.isEmpty)
                const _EmptyStrip(message: 'No hay productos disponibles.')
              else
                SizedBox(
                  height: 292,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _products.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.md + AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return _CatalogReveal(
                        index: index,
                        child: _ProductCard(
                          name: (product['name'] ?? 'Producto').toString(),
                          category: _productCategory(product),
                          price: _productPrice(product),
                          imageUrl: _productImage(product),
                          inStock: _inStock(product),
                          onTap: () => _openProduct(product),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl - AppSpacing.xs),
              _BlockHeader(
                title: 'Categorías',
              ),
              const SizedBox(height: AppSpacing.md),
              if (_productsError != null && _categories.isEmpty)
                _InfoCard(
                  message: _productsError!,
                  label: 'Reintentar',
                  onTap: () => _loadProducts(forceRefresh: true),
                )
              else if (_loadingProducts)
                const _CategorySkeleton()
              else if (_categories.isEmpty)
                const _EmptyStrip(message: 'No hay categorías disponibles.')
              else
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    itemBuilder: (context, index) => _CatalogReveal(
                      index: index,
                      child: _CategoryChip(
                        category: _categories[index],
                        onTap: () {
                          final category = _categories[index];
                          _openArchive(
                            initialCategory:
                                (category['slug'] ?? category['id'] ?? '')
                                    .toString(),
                            initialCategoryName:
                                (category['name'] ?? '').toString(),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;

  const _BlockHeader({
    required this.title,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
        if (action != null && onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.full,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.goldDeep,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (service['title'] ?? 'Servicio').toString();
    final price = (service['price'] ?? '\$0').toString();
    final imageUrl =
        (service['image'] ?? service['imageUrl'] ?? '').toString().trim();
    final placeholderImage = (service['placeholderImage'] ??
            'assets/images/services/Corte de Cabello.webp')
        .toString();

    return _PressableCard(
      width: 220,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: imageUrl.isNotEmpty
                      ? HabitoCachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          semanticLabel: 'Imagen del servicio $title',
                          errorWidget: Image.asset(
                            placeholderImage,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Semantics(
                          label: 'Imagen del servicio $title',
                          image: true,
                          child: Image.asset(
                            placeholderImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primarySoft,
                                    AppColors.goldDeep
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.content_cut,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const Positioned(
                top: 10,
                left: 10,
                child: _OverlayPill(label: 'Servicio'),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reserva tu espacio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.goldDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      const _ActionBubble(icon: Icons.arrow_forward_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = (category['name'] ?? 'Categoría').toString();
    final count = int.tryParse((category['count'] ?? '').toString()) ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Ink(
          width: 172,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + AppSpacing.xs,
            vertical: AppSpacing.sm + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.large,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: AppIconSize.xs + AppSpacing.xxs,
                  color: AppColors.goldSoft,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textPrimary,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$count productos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.goldDeep,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String imageUrl;
  final bool inStock;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.inStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableCard(
      width: 210,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _OverlayPill(label: category),
                  ),
                ),
                if (!inStock) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const _OverlayPill(label: 'Sin stock', dark: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.medium,
            child: SizedBox(
              height: 116,
              width: double.infinity,
              child: Container(
                color: Colors.white,
                child: imageUrl.isEmpty
                    ? Semantics(
                        label: 'Imagen del producto $name',
                        image: true,
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 38,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : HabitoCachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        semanticLabel: 'Imagen del producto $name',
                      ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          height: 1.13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Text(
                    inStock
                        ? 'Disponible para comprar'
                        : 'Consulta disponibilidad',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.goldDeep,
                                  ),
                        ),
                      ),
                      const _ActionBubble(
                        icon: Icons.add_shopping_cart_rounded,
                        background: AppColors.goldSoft,
                        foreground: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  final double width;
  final VoidCallback onTap;
  final Widget child;

  const _PressableCard({
    required this.width,
    required this.onTap,
    required this.child,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
        width: widget.width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            borderRadius: AppRadius.panel,
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.panel,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.medium,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.panel,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final String label;
  final bool dark;

  const _OverlayPill({
    required this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : AppColors.goldSoft,
        borderRadius: AppRadius.full,
        boxShadow: AppShadows.light,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: dark ? Colors.white : AppColors.textPrimary,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _ActionBubble extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;

  const _ActionBubble({
    required this.icon,
    this.background = AppColors.primary,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.compact,
      ),
      child: Icon(icon, color: foreground, size: 18),
    );
  }
}

class _CatalogReveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _CatalogReveal({
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 260 + (index.clamp(0, 5).toInt() * 35),
      ),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  final String message;

  const _EmptyStrip({required this.message});

  @override
  Widget build(BuildContext context) {
    return HabitoEmptyState(
      icon: Icons.info_outline_rounded,
      title: 'Aún no hay contenido disponible',
      message: message,
      compact: true,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  final String label;
  final VoidCallback onTap;

  const _InfoCard({
    required this.message,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HabitoErrorState(
      title: 'No pudimos cargar esta sección',
      message: message,
      actionLabel: label,
      onRetry: onTap,
      compact: true,
    );
  }
}

class _ServiceSkeleton extends StatelessWidget {
  const _ServiceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HabitoLoadingShimmer.horizontal(
      itemCount: 3,
      itemHeight: 292,
      itemWidth: 220,
      spacing: AppSpacing.md + AppSpacing.xs,
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const HabitoLoadingShimmer.horizontal(
      itemCount: 5,
      itemHeight: 58,
      itemWidth: 172,
      spacing: AppSpacing.sm + AppSpacing.xxs,
      borderRadius: AppRadius.large,
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HabitoLoadingShimmer.horizontal(
      itemCount: 3,
      itemHeight: 264,
      itemWidth: 210,
      spacing: AppSpacing.md + AppSpacing.xs,
    );
  }
}
