import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../data/services/habito_shop_api.dart';
import 'product_detail_page.dart';

class ProductsArchivePage extends StatefulWidget {
  final String initialSearch;
  final String initialCategory;
  final String initialCategoryName;

  const ProductsArchivePage({
    super.key,
    this.initialSearch = '',
    this.initialCategory = '',
    this.initialCategoryName = '',
  });

  @override
  State<ProductsArchivePage> createState() => _ProductsArchivePageState();
}

class _ProductsArchivePageState extends State<ProductsArchivePage> {
  static const int _pageSize = 12;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  String _searchQuery = '';
  late String _categoryFilter;
  late String _categoryName;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearch.trim();
    _categoryFilter = widget.initialCategory.trim();
    _categoryName = widget.initialCategoryName.trim();
    _searchController.text = _searchQuery;
    _seedProductsFromCache();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _seedProductsFromCache() async {
    try {
      final cached = await HabitoShopApi.getCachedProducts(
        limit: _pageSize,
        page: 1,
        search: _searchQuery,
        category: _categoryFilter,
      );

      if (!mounted) return;

      if (cached.isNotEmpty) {
        setState(() {
          _products = cached;
          _page = 1;
          _hasMore = cached.length >= _pageSize;
          _isLoading = false;
          _isRefreshing = true;
          _error = null;
        });
      }
    } catch (_) {
      // Cache opcional.
    }

    unawaited(_loadProducts(reset: true, forceRefresh: true));
  }

  Future<void> _loadProducts({
    required bool reset,
    bool forceRefresh = false,
  }) async {
    final nextPage = reset ? 1 : _page + 1;
    final showMainLoading = reset && _products.isEmpty;

    if (!mounted) return;

    setState(() {
      if (showMainLoading) {
        _isLoading = true;
      } else if (reset) {
        _isRefreshing = true;
      } else {
        _isLoadingMore = true;
      }
      _error = null;
    });

    try {
      late final List<Map<String, dynamic>> items;
      late final bool hasMore;

      if (_searchQuery.isNotEmpty) {
        final localMatches = await HabitoShopApi.searchProductsLocally(
          _searchQuery,
          limit: (_pageSize * nextPage) + 1,
          category: _categoryFilter,
        );
        final start = (nextPage - 1) * _pageSize;
        items = localMatches.skip(start).take(_pageSize).toList();
        hasMore = localMatches.length > (start + items.length);
      } else {
        items = await HabitoShopApi.getProducts(
          limit: _pageSize,
          page: nextPage,
          search: _searchQuery,
          category: _categoryFilter,
          forceRefresh: forceRefresh,
        );
        hasMore = items.length >= _pageSize;
      }

      if (!mounted) return;

      setState(() {
        _products = reset ? items : [..._products, ...items];
        _page = nextPage;
        _hasMore = hasMore;
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        _error = FriendlyErrors.loadData(
          e,
          fallback: 'No pudimos cargar los productos. Intenta nuevamente.',
        );
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = '';
      _error = null;
      _isRefreshing = false;
    });
    _loadProducts(reset: true);
  }

  void _handleSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    if (query.length >= 2) {
      unawaited(HabitoShopApi.preloadSearchIndex());
      unawaited(_showInstantSearchResults(query));
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _searchQuery = query;
      _loadProducts(reset: true);
    });
  }

  Future<void> _showInstantSearchResults(String query) async {
    try {
      final instantResults = await HabitoShopApi.searchProductsLocally(
        query,
        limit: 18,
        category: _categoryFilter,
      );

      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        if (instantResults.isNotEmpty) {
          _products = instantResults;
        }
        _page = 1;
        _hasMore = false;
        _isLoading = false;
        _isRefreshing = true;
        _error = null;
        _searchQuery = query;
      });
    } catch (_) {
      // La busqueda remota sigue siendo la fuente final.
    }
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
    final categories = product['categories'];
    if (categories is List && categories.isNotEmpty) {
      final first = categories.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
    }
    return 'Producto';
  }

  String _productImage(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] != null) {
        return first['src'].toString();
      }
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

  Future<void> _openProductDetail(Map<String, dynamic> product) async {
    final productId = int.tryParse((product['id'] ?? '').toString()) ?? 0;
    if (productId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productId: productId,
          initialProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _categoryName.isNotEmpty ? _categoryName : 'Todos los productos',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () => _loadProducts(reset: true, forceRefresh: true),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 28),
          children: [
            _ArchiveSearchField(
              controller: _searchController,
              onChanged: _handleSearchChanged,
              onClear: () {
                _searchController.clear();
                _clearSearch();
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.secondary,
                ),
              ),
            if (_error != null && _products.isEmpty)
              _ArchiveInfoCard(
                message: _error!,
                actionLabel: 'Reintentar',
                onTap: () => _loadProducts(reset: true, forceRefresh: true),
              )
            else if (_isLoading && _products.isEmpty)
              const _ArchiveProductGridSkeleton()
            else if (_products.isEmpty)
              const _ArchiveEmptyState()
            else ...[
              _ArchiveSectionHeader(
                title: _searchQuery.isNotEmpty
                    ? 'Resultados para "$_searchQuery"'
                    : _categoryName.isNotEmpty
                        ? 'Productos de $_categoryName'
                        : 'Catálogo completo',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Mostrando coincidencias por producto y categoría dentro del catálogo.'
                    : _categoryName.isNotEmpty
                        ? 'Filtro activo por categoría. Puedes buscar dentro de esta selección.'
                        : 'Descubre productos premium para cabello, barba y cuidado personal.',
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
              GridView.builder(
                itemCount: _products.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 342,
                ),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return _ArchiveProductCard(
                    name: (product['name'] ?? 'Producto').toString(),
                    category: _productCategory(product),
                    price: _productPrice(product),
                    imageUrl: _productImage(product),
                    inStock: _inStock(product),
                    onTap: () => _openProductDetail(product),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
              if (_isLoadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                    ),
                  ),
                )
              else if (_hasMore)
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => _loadProducts(reset: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.secondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    child: const Text(
                      'Cargar más productos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchiveSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ArchiveSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar producto o categoria',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar busqueda',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(
            color: AppColors.secondary,
            width: 1.2,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _ArchiveSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ArchiveSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _ArchiveProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String imageUrl;
  final bool inStock;
  final VoidCallback onTap;

  const _ArchiveProductCard({
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.inStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.extraLarge,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.extraLarge,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.medium,
                  child: SizedBox(
                    height: 122,
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
                                  size: AppIconSize.xl + AppSpacing.xs,
                                  color: AppColors.primary,
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldDeep,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldDeep,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + AppSpacing.xxs,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color:
                        inStock ? AppColors.successSoft : AppColors.dangerSoft,
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    inStock ? 'En stock' : 'Sin stock',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: inStock
                              ? AppColors.success
                              : AppColors.dangerDeep,
                        ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: IgnorePointer(
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.medium,
                        ),
                      ),
                      child: Text(
                        'Ver producto',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
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
  }
}

class _ArchiveInfoCard extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _ArchiveInfoCard({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HabitoErrorState(
      title: 'No pudimos cargar el catálogo',
      message: message,
      actionLabel: actionLabel,
      onRetry: onTap,
      compact: true,
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return const HabitoEmptyState(
      icon: Icons.store_mall_directory_outlined,
      title: 'No encontramos productos',
      message:
          'Prueba con otra búsqueda o vuelve a intentarlo en unos segundos.',
    );
  }
}

class _ArchiveProductGridSkeleton extends StatelessWidget {
  const _ArchiveProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return const HabitoLoadingShimmer.grid(
      itemCount: 4,
      itemHeight: 342,
      columns: 2,
      spacing: AppSpacing.formNotice,
      borderRadius: AppRadius.extraLarge,
    );
  }
}
