import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
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
        _error = e.toString().replaceFirst('Exception: ', '');
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
        color: const Color(0xFFD4AF37),
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
            const SizedBox(height: 18),
            if (_isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFFD4AF37),
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
                        : 'Catalogo completo',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Mostrando coincidencias por producto y categoria dentro del catalogo.'
                    : _categoryName.isNotEmpty
                        ? 'Filtro activo por categoria. Puedes buscar dentro de esta seleccion.'
                        : 'Descubre productos premium para cabello, barba y cuidado personal.',
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              if (_isLoadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: Color(0xFFD4AF37),
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
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: Color(0xFFD4AF37),
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
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
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 122,
                    width: double.infinity,
                    child: Container(
                      color: Colors.white,
                      child: imageUrl.isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            )
                          : HabitoCachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9C7732),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9C7732),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: inStock
                        ? const Color(0xFFE7F4EA)
                        : const Color(0xFFF4E7E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    inStock ? 'En stock' : 'Sin stock',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: inStock
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFA33A3A),
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
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ver producto',
                        style: TextStyle(
                          fontSize: 12.5,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9C7732)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 40,
            color: Color(0xFF9C7732),
          ),
          SizedBox(height: 12),
          Text(
            'No encontramos productos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Prueba con otra busqueda o vuelve a intentarlo en unos segundos.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ArchiveProductGridSkeleton extends StatelessWidget {
  const _ArchiveProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: 342,
      ),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}
