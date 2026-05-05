import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habito/features/shop/data/services/habito_shop_api.dart';
import 'package:habito/features/shop/presentation/pages/product_detail_page.dart';
import 'package:habito/features/shop/presentation/pages/products_archive_page.dart';

import '../../core/theme/app_colors.dart';
import 'habito_cached_network_image.dart';
import 'unread_notifications_button.dart';

class AppTopHeader extends StatelessWidget implements PreferredSizeWidget {
  final String searchHint;
  final VoidCallback onSearchTap;
  final VoidCallback onCartTap;
  final int cartCount;
  final IconData? leadingIcon;
  final String? leadingLabel;
  final String? leadingTooltip;
  final VoidCallback? onLeadingTap;
  final PreferredSizeWidget? bottom;
  final bool compactSearch;
  final bool emphasizeLeading;

  const AppTopHeader({
    super.key,
    required this.onSearchTap,
    required this.onCartTap,
    required this.cartCount,
    this.searchHint = 'Buscar en la tienda',
    this.leadingIcon,
    this.leadingLabel,
    this.leadingTooltip,
    this.onLeadingTap,
    this.bottom,
    this.compactSearch = false,
    this.emphasizeLeading = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final hasLeadingChip =
        leadingIcon != null && leadingLabel != null && leadingLabel!.isNotEmpty;

    return AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leadingWidth: hasLeadingChip ? 108 : (leadingIcon != null ? 56 : 12),
      leading:
          leadingIcon != null && (leadingLabel == null || leadingLabel!.isEmpty)
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _HeaderIconButton(
                    icon: leadingIcon!,
                    tooltip: leadingTooltip,
                    onTap: onLeadingTap,
                  ),
                )
              : leadingIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _HeaderActionChip(
                        icon: leadingIcon!,
                        label: leadingLabel!,
                        tooltip: leadingTooltip,
                        onTap: onLeadingTap,
                        emphasized: emphasizeLeading,
                      ),
                    )
                  : null,
      titleSpacing: leadingIcon != null ? 10 : 16,
      title: compactSearch
          ? Align(
              alignment: Alignment.centerLeft,
              child: _HeaderIconButton(
                icon: Icons.search_rounded,
                tooltip: searchHint,
                onTap: onSearchTap,
              ),
            )
          : _HeaderSearch(
              hint: searchHint,
            ),
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: UnreadNotificationsButton(),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _CartAction(
            cartCount: cartCount,
            onTap: onCartTap,
          ),
        ),
      ],
      bottom: bottom,
    );
  }
}

class _HeaderSearch extends StatefulWidget {
  final String hint;

  const _HeaderSearch({
    required this.hint,
  });

  @override
  State<_HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<_HeaderSearch> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _categorySuggestions = [];
  bool _isSearching = false;
  String _query = '';
  double _targetWidth = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future<void>.delayed(const Duration(milliseconds: 140), _hideOverlay);
      } else if (_suggestions.isNotEmpty ||
          _categorySuggestions.isNotEmpty ||
          _isSearching) {
        _showOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    _query = query;
    _debounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _categorySuggestions = [];
        _isSearching = false;
      });
      _hideOverlay();
      return;
    }

    setState(() {
      _isSearching = true;
    });
    _showOverlay();

    _debounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        final results = await Future.wait([
          HabitoShopApi.searchProductsLocally(
            query,
            limit: 6,
          ),
          HabitoShopApi.searchCategoriesLocally(
            query,
            limit: 4,
          ),
        ]);

        if (!mounted || _query != query) return;
        setState(() {
          _suggestions = results.first;
          _categorySuggestions = results.last;
          _isSearching = false;
        });
        _showOverlay();
      } catch (_) {
        if (!mounted || _query != query) return;
        setState(() {
          _suggestions = [];
          _categorySuggestions = [];
          _isSearching = false;
        });
        _showOverlay();
      }
    });
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _hideOverlay();
    _focusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsArchivePage(initialSearch: query),
      ),
    );
  }

  void _openProduct(Map<String, dynamic> product) {
    final productId = int.tryParse((product['id'] ?? '').toString()) ?? 0;
    if (productId <= 0) return;
    _hideOverlay();
    _focusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productId: productId,
          initialProduct: product,
        ),
      ),
    );
  }

  void _openCategory(Map<String, dynamic> category) {
    final categoryFilter =
        (category['slug'] ?? category['id'] ?? '').toString().trim();
    if (categoryFilter.isEmpty) return;

    _hideOverlay();
    _focusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsArchivePage(
          initialCategory: categoryFilter,
          initialCategoryName: (category['name'] ?? '').toString(),
        ),
      ),
    );
  }

  void _showOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;

      if (_overlayEntry == null) {
        _overlayEntry = OverlayEntry(
          builder: (context) => _SearchSuggestionsOverlay(
            layerLink: _layerLink,
            width: _targetWidth,
            isSearching: _isSearching,
            query: _query,
            suggestions: _suggestions,
            categorySuggestions: _categorySuggestions,
            onProductTap: _openProduct,
            onCategoryTap: _openCategory,
            onSeeAll: _submitSearch,
          ),
        );
        Overlay.of(context).insert(_overlayEntry!);
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    });
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _targetWidth = constraints.maxWidth;

        return CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _submitSearch(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar busqueda',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SearchSuggestionsOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final double width;
  final bool isSearching;
  final String query;
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> categorySuggestions;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final ValueChanged<Map<String, dynamic>> onCategoryTap;
  final VoidCallback onSeeAll;

  const _SearchSuggestionsOverlay({
    required this.layerLink,
    required this.width,
    required this.isSearching,
    required this.query,
    required this.suggestions,
    required this.categorySuggestions,
    required this.onProductTap,
    required this.onCategoryTap,
    required this.onSeeAll,
  });

  String _price(Map<String, dynamic> product) {
    final value = product['price'] ?? product['regular_price'];
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    final formatted = parsed == parsed.roundToDouble()
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
    return '\$$formatted';
  }

  String _image(Map<String, dynamic> product) {
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
    final normalized = value?.toString().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'instock';
  }

  int get _totalItems => suggestions.length + categorySuggestions.length;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: FocusScope.of(context).unfocus,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 50),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width:
                    width > 0 ? width : MediaQuery.of(context).size.width - 160,
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4AF37),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Buscando productos y categorias...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (query.length >= 2 && _totalItems == 0) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No encontramos coincidencias rapidas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Puedes ver todos los resultados del catalogo.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            _SeeAllButton(query: query, onTap: onSeeAll),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (categorySuggestions.isNotEmpty) ...[
          const _SuggestionSectionHeader(title: 'Categorias'),
          ...categorySuggestions.map(
            (category) => _CategorySuggestionTile(
              name: (category['name'] ?? 'Categoria').toString(),
              count: int.tryParse((category['count'] ?? '').toString()) ?? 0,
              onTap: () => onCategoryTap(category),
            ),
          ),
        ],
        if (categorySuggestions.isNotEmpty && suggestions.isNotEmpty)
          const Divider(height: 1, color: AppColors.border),
        if (suggestions.isNotEmpty) ...[
          const _SuggestionSectionHeader(title: 'Productos'),
          ...suggestions.map(
            (product) => _SuggestionTile(
              name: (product['name'] ?? 'Producto').toString(),
              price: _price(product),
              imageUrl: _image(product),
              inStock: _inStock(product),
              onTap: () => onProductTap(product),
            ),
          ),
        ],
        if (query.length >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: _SeeAllButton(query: query, onTap: onSeeAll),
          ),
      ],
    );
  }
}

class _SuggestionSectionHeader extends StatelessWidget {
  final String title;

  const _SuggestionSectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      color: const Color(0xFFF8F5EE),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CategorySuggestionTile extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const _CategorySuggestionTile({
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 producto' : '$count productos';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.category_rounded,
                color: Color(0xFF9C7732),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countLabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String name;
  final String price;
  final String imageUrl;
  final bool inStock;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.inStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                color: const Color(0xFFF5F2EC),
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textSecondary,
                      )
                    : HabitoCachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inStock ? 'Disponible' : 'Sin stock',
                    style: TextStyle(
                      color: inStock
                          ? const Color(0xFF2E7D32)
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: const TextStyle(
                color: Color(0xFF9C7732),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final String query;
  final VoidCallback onTap;

  const _SeeAllButton({
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Ver todos los resultados de "$query"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _HeaderActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;
  final bool emphasized;

  const _HeaderActionChip({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: emphasized ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: emphasized ? Colors.white : AppColors.primary,
                      size: 18,
                    ),
                    const Positioned(
                      top: -1,
                      right: -1,
                      child: SizedBox(
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: emphasized ? Colors.white : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _CartAction extends StatelessWidget {
  final int cartCount;
  final VoidCallback onTap;

  const _CartAction({
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.shopping_bag_outlined, color: Colors.white),
            ),
          ),
        ),
        if (cartCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$cartCount',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
