import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../data/services/habito_shop_api.dart';
import '../../provider/shop_provider.dart';
import 'cart_page.dart';

class ProductDetailPage extends StatefulWidget {
  final int productId;
  final Map<String, dynamic>? initialProduct;

  const ProductDetailPage({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  ShopFulfillmentMethod _selectedFulfillmentMethod =
      ShopFulfillmentMethod.delivery;
  Map<String, dynamic>? _selectedPickupWarehouse;

  @override
  void initState() {
    super.initState();
    final shop = context.read<ShopProvider>();
    if (shop.hasItems) {
      _selectedFulfillmentMethod = shop.fulfillmentMethod;
      _selectedPickupWarehouse = shop.pickupLocation;
    }
    _product = widget.initialProduct;
    _isLoading = widget.initialProduct == null;
    _precacheMainImage();
    _loadProduct();
    if (_product != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPickupWarehouseSelection();
      });
    }
  }

  Future<void> _loadProduct() async {
    try {
      final product =
          await HabitoShopApi.getProduct(productId: widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _isLoading = false;
        _error = null;
      });
      _syncPickupWarehouseSelection();
      unawaited(_precacheMainImage());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_product == null) {
          _error = FriendlyErrors.loadData(
            e,
            fallback: 'No pudimos cargar este producto. Intenta nuevamente.',
          );
        }
      });
    }
  }

  bool get _inStock {
    final value = _product?['in_stock'];
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  String get _imageUrl {
    final images = _product?['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] != null) {
        return first['src'].toString();
      }
    }
    return '';
  }

  ImageProvider<Object>? get _imageProvider {
    final url = _imageUrl.trim();
    if (url.isEmpty) return null;
    return habitoCachedImageProvider(url);
  }

  Future<void> _precacheMainImage() async {
    final provider = _imageProvider;
    if (provider == null || !mounted) return;
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // Solo optimizacion.
    }
  }

  String get _category {
    final categories = _product?['categories'];
    if (categories is List && categories.isNotEmpty) {
      final first = categories.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
    }
    return 'Producto';
  }

  String get _description {
    final description = (_product?['description'] ?? '').toString().trim();
    if (description.isNotEmpty) return description;
    return (_product?['short_description'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> get _warehouseStock {
    final value = _product?['warehouse_stock'];
    if (value is List) {
      return value.whereType<Map>().map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> get _selectablePickupWarehouses {
    return _warehouseStock.where(_warehouseHasStock).toList();
  }

  double get _price {
    final value = _product?['display_price'] ??
        _product?['price_including_tax'] ??
        _product?['price'] ??
        _product?['regular_price'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? get _maxAvailableQuantity {
    final manageStock = _product?['manage_stock'] == true;
    if (!manageStock) return null;
    final raw = _product?['stock_quantity'];
    final parsed = raw is int
        ? raw
        : raw is double
            ? raw.toInt()
            : int.tryParse(raw?.toString() ?? '');
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  int? get _selectedWarehouseMaxQuantity {
    if (_selectedFulfillmentMethod != ShopFulfillmentMethod.pickup) {
      return _maxAvailableQuantity;
    }

    final warehouse = _selectedPickupWarehouse;
    if (warehouse == null) return 0;
    return _parseWarehouseQuantity(warehouse['quantity']);
  }

  int? get _effectiveMaxQuantity {
    if (_selectedFulfillmentMethod == ShopFulfillmentMethod.delivery) {
      return _maxAvailableQuantity;
    }
    return _selectedWarehouseMaxQuantity;
  }

  bool get _canIncreaseQuantity {
    final max = _effectiveMaxQuantity;
    if (!_canAddCurrentSelection) return false;
    if (max == null) return true;
    return _quantity < max;
  }

  bool get _pickupSelectionEnabled => _selectablePickupWarehouses.isNotEmpty;

  bool get _canAddCurrentSelection {
    if (!_inStock) return false;
    if (_selectedFulfillmentMethod == ShopFulfillmentMethod.delivery) {
      return true;
    }
    final max = _selectedWarehouseMaxQuantity;
    return _selectedPickupWarehouse != null && (max == null || max > 0);
  }

  String get _taxLabel {
    final label = (_product?['iva_label'] ??
            _product?['ivaLabel'] ??
            _product?['tax_label'] ??
            '')
        .toString()
        .trim();
    if (label.isNotEmpty) return label;

    final type = (_product?['iva_type'] ?? _product?['ivaType'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (type == 'iva_15') return 'IVA 15%';
    if (type == 'iva_0') return 'IVA 0%';
    return 'No grava IVA';
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\$${value.toStringAsFixed(0)}';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatWarehouseQuantity(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if ((parsed - parsed.roundToDouble()).abs() < 0.0001) {
      return parsed.toStringAsFixed(0);
    }
    return parsed.toStringAsFixed(2);
  }

  int _parseWarehouseQuantity(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _warehouseHasStock(Map<String, dynamic> item) {
    return item['in_stock'] == true ||
        _parseWarehouseQuantity(item['quantity']) > 0;
  }

  bool _sameWarehouse(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    final externalA =
        (a['external_id'] ?? a['externalId'] ?? '').toString().trim();
    final externalB =
        (b['external_id'] ?? b['externalId'] ?? '').toString().trim();
    if (externalA.isNotEmpty || externalB.isNotEmpty) {
      return externalA == externalB;
    }
    final idA = int.tryParse((a['id'] ?? '').toString()) ?? 0;
    final idB = int.tryParse((b['id'] ?? '').toString()) ?? 0;
    return idA > 0 && idA == idB;
  }

  Map<String, dynamic>? _findWarehouseForLocation(
    Map<String, dynamic>? location,
  ) {
    if (location == null) return null;
    for (final item in _warehouseStock) {
      if (_sameWarehouse(item, location)) {
        return item;
      }
    }
    return null;
  }

  Map<String, dynamic>? _defaultSelectableWarehouse() {
    for (final item in _selectablePickupWarehouses) {
      if (item['is_default'] == true) return item;
    }
    if (_selectablePickupWarehouses.isNotEmpty) {
      return _selectablePickupWarehouses.first;
    }
    return null;
  }

  void _syncQuantityToAvailability() {
    final max = _effectiveMaxQuantity;
    if (max != null && max > 0 && _quantity > max) {
      _quantity = max;
    }
    if (max != null && max <= 0) {
      _quantity = 1;
    }
  }

  void _syncPickupWarehouseSelection() {
    if (!mounted) return;

    final shop = context.read<ShopProvider>();
    final hasCartItems = shop.hasItems;
    final preferredWarehouse =
        _findWarehouseForLocation(hasCartItems ? shop.pickupLocation : null);
    final keepCurrent = _findWarehouseForLocation(_selectedPickupWarehouse);

    final nextMethod = _pickupSelectionEnabled
        ? _selectedFulfillmentMethod
        : ShopFulfillmentMethod.delivery;

    Map<String, dynamic>? nextWarehouse;
    if (nextMethod == ShopFulfillmentMethod.pickup) {
      if (preferredWarehouse != null &&
          _warehouseHasStock(preferredWarehouse)) {
        nextWarehouse = preferredWarehouse;
      } else if (keepCurrent != null && _warehouseHasStock(keepCurrent)) {
        nextWarehouse = keepCurrent;
      } else if (!hasCartItems) {
        nextWarehouse = _defaultSelectableWarehouse();
      }
    }

    setState(() {
      _selectedFulfillmentMethod = nextMethod;
      _selectedPickupWarehouse = nextWarehouse;
      _syncQuantityToAvailability();
    });
  }

  void _selectFulfillmentMethod(ShopFulfillmentMethod method) {
    if (method == ShopFulfillmentMethod.pickup && !_pickupSelectionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este producto todavia no tiene stock por sucursal disponible para retiro.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedFulfillmentMethod = method;
      if (method == ShopFulfillmentMethod.pickup &&
          (_selectedPickupWarehouse == null ||
              !_warehouseHasStock(_selectedPickupWarehouse!))) {
        _selectedPickupWarehouse = _defaultSelectableWarehouse();
      }
      _syncQuantityToAvailability();
    });
  }

  void _selectPickupWarehouse(Map<String, dynamic> warehouse) {
    if (!_warehouseHasStock(warehouse)) return;
    setState(() {
      _selectedPickupWarehouse = warehouse;
      _syncQuantityToAvailability();
    });
  }

  Future<bool> _confirmReplaceCart(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Actualizar carrito'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reemplazar'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _goToMainTab(int index) async {
    if (!mounted) return;
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.main),
        builder: (_) => MainNavigationPage(initialIndex: index),
      ),
      (route) => false,
    );
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null || !_inStock) return;

    if (_selectedFulfillmentMethod == ShopFulfillmentMethod.pickup &&
        _selectedPickupWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona primero la sucursal de retiro.'),
        ),
      );
      return;
    }

    final shop = context.read<ShopProvider>();
    var result = shop.addProduct(
      product,
      quantity: _quantity,
      fulfillmentMethod: _selectedFulfillmentMethod,
      pickupLocation: _selectedPickupWarehouse,
    );

    if (result.requiresCartReset) {
      final confirmed = await _confirmReplaceCart(
        result.message ??
            'El carrito actual usa otra configuracion. Si continuas, se reemplazara con esta seleccion.',
      );
      if (!confirmed || !mounted) return;
      result = shop.addProduct(
        product,
        quantity: _quantity,
        fulfillmentMethod: _selectedFulfillmentMethod,
        pickupLocation: _selectedPickupWarehouse,
        replaceCartContext: true,
      );
    }

    if (!result.success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'No pudimos agregar este producto al carrito.',
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.message ??
              '${product['name'] ?? 'Producto'} fue agregado al carrito.',
        ),
        action: SnackBarAction(
          label: 'Ver carrito',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      controller.close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (shop) => shop.cartCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle de producto',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Abrir carrito',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      bottomNavigationBar: HabitoBottomNavigationBar(
        selectedIndex: 1,
        onDestinationSelected: _goToMainTab,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            )
          : _error != null
              ? _DetailErrorState(
                  message: _error!,
                  onRetry: _loadProduct,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    _DetailHero(
                      imageProvider: _imageProvider,
                      semanticLabel:
                          'Imagen del producto ${(_product?['name'] ?? 'Producto').toString()}',
                      category: _category,
                      price: _formatPrice(_price),
                      inStock: _inStock,
                    ),
                    const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                    Text(
                      (_product?['name'] ?? 'Producto').toString(),
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.08,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _DetailPill(
                          icon: Icons.local_shipping_outlined,
                          label: _inStock
                              ? 'Listo para compra'
                              : 'Temporalmente sin stock',
                        ),
                        _DetailPill(
                          icon: Icons.receipt_long_outlined,
                          label: _taxLabel,
                        ),
                        const _DetailPill(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Selección Hábito',
                        ),
                      ],
                    ),
                    if (_description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                      const _DetailSectionTitle(title: 'Descripción'),
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.all(
                          AppSpacing.lg + AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.extraLarge,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                    const _DetailSectionTitle(title: 'Compra'),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    Container(
                      padding: const EdgeInsets.all(
                        AppSpacing.lg + AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.hero,
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.light,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Como quieres recibirlo',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FulfillmentChoiceCard(
                            title: 'Envio',
                            subtitle:
                                'Compra ahora y coordinamos el despacho con el inventario disponible.',
                            selected: _selectedFulfillmentMethod ==
                                ShopFulfillmentMethod.delivery,
                            icon: Icons.local_shipping_outlined,
                            onTap: () => _selectFulfillmentMethod(
                              ShopFulfillmentMethod.delivery,
                            ),
                          ),
                          const SizedBox(
                            height: AppSpacing.sm + AppSpacing.xxs,
                          ),
                          _FulfillmentChoiceCard(
                            title: 'Retiro en tienda',
                            subtitle: _pickupSelectionEnabled
                                ? 'Elige la sucursal donde deseas retirar tu producto.'
                                : 'Disponible cuando este producto tenga stock por sucursal sincronizado.',
                            selected: _selectedFulfillmentMethod ==
                                ShopFulfillmentMethod.pickup,
                            icon: Icons.storefront_outlined,
                            enabled: _pickupSelectionEnabled,
                            onTap: () => _selectFulfillmentMethod(
                              ShopFulfillmentMethod.pickup,
                            ),
                          ),
                          if (_selectedFulfillmentMethod ==
                              ShopFulfillmentMethod.pickup) ...[
                            const SizedBox(
                              height: AppSpacing.lg + AppSpacing.xs,
                            ),
                            const Text(
                              'Selecciona donde retirar',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(
                              height: AppSpacing.sm + AppSpacing.xxs,
                            ),
                            for (var index = 0;
                                index < _warehouseStock.length;
                                index++) ...[
                              _PickupWarehouseOptionCard(
                                item: _warehouseStock[index],
                                quantityLabel: _formatWarehouseQuantity(
                                  _warehouseStock[index]['quantity'],
                                ),
                                selected: _sameWarehouse(
                                  _warehouseStock[index],
                                  _selectedPickupWarehouse,
                                ),
                                enabled:
                                    _warehouseHasStock(_warehouseStock[index]),
                                onTap: () => _selectPickupWarehouse(
                                  _warehouseStock[index],
                                ),
                              ),
                              if (index < _warehouseStock.length - 1)
                                const SizedBox(
                                  height: AppSpacing.sm + AppSpacing.xxs,
                                ),
                            ],
                          ],
                          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                              AppSpacing.md + AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: AppRadius.large,
                            ),
                            child: Text(
                              _selectedFulfillmentMethod ==
                                      ShopFulfillmentMethod.pickup
                                  ? _selectedPickupWarehouse == null
                                      ? 'Selecciona una sucursal con stock para continuar con el retiro.'
                                      : 'Disponible para retirar en ${(_selectedPickupWarehouse?['name'] ?? 'la sucursal seleccionada').toString()}: ${_selectedWarehouseMaxQuantity ?? 0} unidad(es).'
                                  : _effectiveMaxQuantity == null
                                      ? 'Puedes agregar la cantidad que necesites.'
                                      : 'Disponible para compra inmediata: ${_effectiveMaxQuantity ?? 0} unidad(es).',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Cantidad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _QtyButton(
                                icon: Icons.remove,
                                tooltip: 'Disminuir cantidad',
                                onTap: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md + AppSpacing.xs,
                                ),
                                child: Text(
                                  '$_quantity',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              _QtyButton(
                                icon: Icons.add,
                                tooltip: 'Aumentar cantidad',
                                onTap: _canIncreaseQuantity
                                    ? () => setState(() => _quantity++)
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.all(
                              AppSpacing.md + AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: AppRadius.large,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Subtotal',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatPrice(_price * _quantity),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed:
                                  _canAddCurrentSelection ? _addToCart : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor:
                                    AppColors.secondary.withValues(alpha: 0.4),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.medium,
                                ),
                              ),
                              child: Text(
                                !_inStock
                                    ? 'No disponible'
                                    : _selectedFulfillmentMethod ==
                                            ShopFulfillmentMethod.pickup
                                        ? _selectedPickupWarehouse == null
                                            ? 'Selecciona una sucursal'
                                            : 'Agregar para retirar en ${(_selectedPickupWarehouse?['name'] ?? 'tienda').toString()}'
                                        : 'Agregar al carrito',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
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

class _DetailHero extends StatelessWidget {
  final ImageProvider<Object>? imageProvider;
  final String semanticLabel;
  final String category;
  final String price;
  final bool inStock;

  const _DetailHero({
    required this.imageProvider,
    required this.semanticLabel,
    required this.category,
    required this.price,
    required this.inStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.extraExtraLarge,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.goldDeep,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: inStock ? AppColors.successSoft : AppColors.dangerSoft,
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  inStock ? 'En stock' : 'Sin stock',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: inStock ? AppColors.success : AppColors.dangerDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.extraLarge,
            child: Container(
              height: 240,
              color: Colors.white,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.08,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Semantics(
                      label: semanticLabel,
                      image: true,
                      child: imageProvider == null
                          ? const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color: AppColors.primary,
                              ),
                            )
                          : Image(
                              image: imageProvider!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppIconSize.xs + AppSpacing.xxs,
            color: AppColors.goldDeep,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionTitle extends StatelessWidget {
  final String title;

  const _DetailSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
    );
  }
}

// ignore: unused_element
class _WarehouseStockRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String quantityLabel;

  const _WarehouseStockRow({
    required this.item,
    required this.quantityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? 'Bodega').toString().trim();
    final code = (item['code'] ?? '').toString().trim();
    final city = (item['city'] ?? '').toString().trim();
    final isDefault = item['is_default'] == true;
    final inStock = item['in_stock'] == true;

    final subtitleParts = <String>[
      if (code.isNotEmpty) code,
      if (city.isNotEmpty) city,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        'Principal',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldDeep,
                            ),
                      ),
                    ),
                ],
              ),
              if (subtitleParts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitleParts.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              quantityLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              inStock ? 'Disponible' : 'Sin stock',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: inStock ? AppColors.success : AppColors.dangerDeep,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FulfillmentChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _FulfillmentChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.large,
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldMuted : AppColors.surfaceMuted,
            borderRadius: AppRadius.large,
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.secondary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Icon(icon, color: AppColors.primary, size: 22),
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
                      subtitle,
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
        ),
      ),
    );
  }
}

class _PickupWarehouseOptionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String quantityLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PickupWarehouseOptionCard({
    required this.item,
    required this.quantityLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? 'Sucursal').toString().trim();
    final code = (item['code'] ?? '').toString().trim();
    final city = (item['city'] ?? '').toString().trim();
    final isDefault = item['is_default'] == true;
    final subtitleParts = <String>[
      if (code.isNotEmpty) code,
      if (city.isNotEmpty) city,
    ];

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.large,
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldMuted : AppColors.surfaceMuted,
            borderRadius: AppRadius.large,
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.secondary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.goldMuted,
                              borderRadius: AppRadius.full,
                            ),
                            child: Text(
                              'Principal',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.goldDeep,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitleParts.join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quantityLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    enabled ? 'Disponible' : 'Sin stock',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? AppColors.success
                              : AppColors.dangerDeep,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: AppColors.goldDeep,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _QtyButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.compact,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: AppRadius.compact,
            ),
            child: Icon(
              icon,
              size: 20,
              color: onTap == null ? Colors.black38 : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
