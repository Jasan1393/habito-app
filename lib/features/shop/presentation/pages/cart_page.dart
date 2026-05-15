import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../data/services/habito_shop_api.dart';
import '../../provider/shop_provider.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> _pickupLocations = [];
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPickupLocations);
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\$${value.toStringAsFixed(0)}';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatShipping(double value) =>
      value <= 0 ? 'Gratis' : _formatPrice(value);

  Future<void> _loadPickupLocations() async {
    if (_isLoadingLocations) return;
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final fresh = await HabitoShopApi.getWarehouses();
      if (!mounted) return;
      setState(() {
        _pickupLocations = fresh
            .whereType<Map>()
            .map((item) => _normalizeLocation(Map<String, dynamic>.from(item)))
            .where((item) => item['id'] != null)
            .toList();
      });
    } catch (_) {
      // La seleccion de sucursal no debe bloquear el carrito.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  Map<String, dynamic> _normalizeLocation(Map<String, dynamic> item) {
    return {
      'id': _parseInt(item['id']),
      'external_id':
          (item['external_id'] ?? item['externalId'] ?? '').toString().trim(),
      'code': (item['code'] ?? '').toString().trim(),
      'name': (item['name'] ?? 'Bodega').toString().trim(),
      'address':
          (item['address'] ?? item['address_line_1'] ?? '').toString().trim(),
      'city': (item['city'] ?? '').toString().trim(),
      'is_default': item['is_default'] == true,
    };
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _defaultPickupLocation() {
    for (final location in _pickupLocations) {
      if (location['is_default'] == true) return location;
    }
    if (_pickupLocations.isNotEmpty) {
      return _pickupLocations.first;
    }
    return null;
  }

  void _showCartContextFeedback(ShopCartActionResult result) {
    if (!mounted || result.message == null || result.message!.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(result.message!),
        ),
      );
  }

  void _removeCartItemWithUndo(
    ShopProvider shop,
    ShopCartItem item,
    int index,
  ) {
    shop.removeProduct(item.productId);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${item.name} se quito del carrito.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => shop.restoreCartItem(item, index: index),
          ),
        ),
      );
  }

  void _handleFulfillmentMethodSelection(
    ShopProvider shop,
    ShopFulfillmentMethod method,
  ) {
    final result = shop.updateCartContext(
      fulfillmentMethod: method,
      pickupLocation: method == ShopFulfillmentMethod.pickup
          ? (shop.pickupLocation ?? _defaultPickupLocation())
          : null,
    );
    _showCartContextFeedback(result);
  }

  void _handlePickupLocationSelection(
    ShopProvider shop,
    Map<String, dynamic>? location,
  ) {
    final result = shop.changePickupLocation(location);
    _showCartContextFeedback(result);
  }

  Future<void> _confirmClearCart(ShopProvider shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
        title: const Text(
          'Vaciar carrito',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'Esto solo limpia los productos guardados en este telefono. Tu cuenta y tus pedidos no se modifican.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await shop.repairLocalCheckoutState();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
              'Carrito local reiniciado. Puedes armar el pedido otra vez.'),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShopProvider, AuthProvider>(
      builder: (context, shop, auth, _) {
        final textTheme = Theme.of(context).textTheme;
        final cartItems = shop.cartItems;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            title: const Text('Carrito'),
          ),
          bottomNavigationBar: HabitoBottomNavigationBar(
            selectedIndex: 1,
            onDestinationSelected: _goToMainTab,
          ),
          body: cartItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: HabitoEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Tu carrito está vacío',
                      message:
                          'Agrega productos desde la tienda para preparar un pedido claro, elegante y rápido.',
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                        children: [
                          _CartSectionHeader(
                            itemCount: shop.cartCount,
                            subtotal: _formatPrice(shop.subtotal),
                            onClearCart: () => _confirmClearCart(shop),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (var index = 0; index < cartItems.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Dismissible(
                                key: ValueKey(
                                  'cart-item-${cartItems[index].productId}',
                                ),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) async {
                                  _removeCartItemWithUndo(
                                    shop,
                                    cartItems[index],
                                    index,
                                  );
                                  return false;
                                },
                                background: const _RemoveCartItemBackground(),
                                child: _CartItemCard(
                                  item: cartItems[index],
                                  formatPrice: _formatPrice,
                                  onIncrement:
                                      cartItems[index].maxQuantity != null &&
                                              cartItems[index].quantity >=
                                                  cartItems[index].maxQuantity!
                                          ? null
                                          : () => shop.incrementQuantity(
                                                cartItems[index].productId,
                                              ),
                                  onDecrement: () => shop.decrementQuantity(
                                    cartItems[index].productId,
                                  ),
                                  onRemove: () => _removeCartItemWithUndo(
                                    shop,
                                    cartItems[index],
                                    index,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          _FulfillmentCard(
                            selectedMethod: shop.fulfillmentMethod,
                            pickupLocations: _pickupLocations,
                            selectedPickupLocation: shop.pickupLocation,
                            isLoadingLocations: _isLoadingLocations,
                            formatShipping: _formatShipping,
                            deliveryPrice: shop.shippingTotalFor(
                              ShopFulfillmentMethod.delivery,
                            ),
                            pickupPrice: shop.shippingTotalFor(
                              ShopFulfillmentMethod.pickup,
                            ),
                            onSelectMethod: (method) =>
                                _handleFulfillmentMethodSelection(
                              shop,
                              method,
                            ),
                            onSelectPickupLocation: (location) =>
                                _handlePickupLocationSelection(
                              shop,
                              location,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                          _SummaryCard(
                            subtotal: _formatPrice(shop.subtotal),
                            tax: shop.hasIvaBreakdown
                                ? _formatPrice(shop.taxTotal)
                                : '',
                            taxLabel: shop.taxBreakdownLabel,
                            shipping:
                                _formatShipping(shop.selectedShippingTotal),
                            shippingLabel: shop.fulfillmentMethod.title,
                            total: _formatPrice(shop.selectedOrderTotal),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.bottomSheet,
                          boxShadow: AppShadows.bottomSheet,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total estimado',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatPrice(shop.selectedOrderTotal),
                                  style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                                height: AppSpacing.md + AppSpacing.xs),
                            SizedBox(
                              width: double.infinity,
                              height: AppSpacing.actionHeight,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!auth.isLoggedIn) {
                                    await Navigator.pushNamed(
                                      context,
                                      AppRoutes.login,
                                    );

                                    if (!context.mounted ||
                                        !context
                                            .read<AuthProvider>()
                                            .isLoggedIn) {
                                      return;
                                    }
                                  }

                                  if (!context.mounted) return;

                                  if (shop.fulfillmentMethod ==
                                          ShopFulfillmentMethod.pickup &&
                                      shop.pickupLocationName.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Selecciona la sucursal preferida de retiro.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CheckoutPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.large,
                                  ),
                                ),
                                child: Text(
                                  auth.isLoggedIn
                                      ? 'Continuar al checkout'
                                      : 'Inicia sesión para comprar',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CartSectionHeader extends StatelessWidget {
  final int itemCount;
  final String subtotal;
  final VoidCallback onClearCart;

  const _CartSectionHeader({
    required this.itemCount,
    required this.subtotal,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context) {
    final productLabel = itemCount == 1 ? '1 producto' : '$itemCount productos';
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productos',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CompactInfoPill(label: productLabel, dark: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Ajusta cantidades antes de confirmar tu compra.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _CompactInfoPill(label: 'Subtotal $subtotal'),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: onClearCart,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.dangerDeep,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text(
                  'Vaciar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactInfoPill extends StatelessWidget {
  final String label;
  final bool dark;

  const _CompactInfoPill({
    required this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : AppColors.goldMuted,
        borderRadius: AppRadius.full,
        border: Border.all(
          color: dark ? AppColors.primary : AppColors.goldSoft,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.labelMedium?.copyWith(
          color: dark ? AppColors.goldSoft : AppColors.goldDeep,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RemoveCartItemBackground extends StatelessWidget {
  const _RemoveCartItemBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Quitar',
            style: TextStyle(
              color: AppColors.dangerDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.delete_outline_rounded,
            color: AppColors.dangerDeep,
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final ShopCartItem item;
  final String Function(double value) formatPrice;
  final VoidCallback? onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.formatPrice,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Imagen del producto ${item.name}',
            image: true,
            child: ClipRRect(
              borderRadius: AppRadius.large,
              child: Container(
                width: AppIconSize.productThumbnail,
                height: AppIconSize.productThumbnail,
                color: Colors.white,
                child: item.imageUrl.isEmpty
                    ? const Icon(
                        Icons.shopping_bag_outlined,
                        size: AppIconSize.quantityButton,
                        color: AppColors.textPrimary,
                      )
                    : HabitoCachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.contain,
                        semanticLabel: 'Imagen del producto ${item.name}',
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: item.inStock
                            ? AppColors.successSoft
                            : AppColors.dangerSoft,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        item.inStock ? 'En stock' : 'Sin stock',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.inStock
                              ? AppColors.success
                              : AppColors.dangerDeep,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatPrice(item.total),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.goldDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QtyButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Disminuir cantidad de ${item.name}',
                          onTap: onDecrement,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _QtyButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Aumentar cantidad de ${item.name}',
                          onTap: onIncrement,
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onRemove,
                      child: const Text('Quitar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  static const double _targetSize = 44;

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
        child: Material(
          color: AppColors.goldMuted,
          borderRadius: AppRadius.compact,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.compact,
            child: SizedBox(
              width: _targetSize,
              height: _targetSize,
              child: Icon(
                icon,
                size: AppIconSize.compact,
                color: onTap == null ? Colors.black38 : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FulfillmentCard extends StatelessWidget {
  final ShopFulfillmentMethod selectedMethod;
  final List<Map<String, dynamic>> pickupLocations;
  final Map<String, dynamic>? selectedPickupLocation;
  final bool isLoadingLocations;
  final String Function(double value) formatShipping;
  final double deliveryPrice;
  final double pickupPrice;
  final ValueChanged<ShopFulfillmentMethod> onSelectMethod;
  final ValueChanged<Map<String, dynamic>?> onSelectPickupLocation;

  const _FulfillmentCard({
    required this.selectedMethod,
    required this.pickupLocations,
    required this.selectedPickupLocation,
    required this.isLoadingLocations,
    required this.formatShipping,
    required this.deliveryPrice,
    required this.pickupPrice,
    required this.onSelectMethod,
    required this.onSelectPickupLocation,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLocationId = _parseInt(selectedPickupLocation?['id']);
    final textTheme = Theme.of(context).textTheme;
    final dropdownValue = pickupLocations.any(
      (location) => _parseInt(location['id']) == selectedLocationId,
    )
        ? selectedLocationId
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entrega',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
          const Text(
            'Elige si quieres envío local o indicar una sucursal preferida para retiro.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          _FulfillmentOption(
            title: ShopFulfillmentMethod.delivery.title,
            subtitle: ShopFulfillmentMethod.delivery.description,
            price: formatShipping(deliveryPrice),
            icon: Icons.local_shipping_outlined,
            selected: selectedMethod == ShopFulfillmentMethod.delivery,
            onTap: () => onSelectMethod(ShopFulfillmentMethod.delivery),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          _FulfillmentOption(
            title: ShopFulfillmentMethod.pickup.title,
            subtitle: ShopFulfillmentMethod.pickup.description,
            price: formatShipping(pickupPrice),
            icon: Icons.storefront_rounded,
            selected: selectedMethod == ShopFulfillmentMethod.pickup,
            onTap: () => onSelectMethod(ShopFulfillmentMethod.pickup),
          ),
          if (selectedMethod == ShopFulfillmentMethod.pickup) ...[
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            DropdownButtonFormField<int>(
              initialValue: dropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sucursal preferida de retiro',
              ),
              items: pickupLocations
                  .map(
                    (location) => DropdownMenuItem<int>(
                      value: _parseInt(location['id']),
                      child: Text(
                        (location['name'] ?? 'Sucursal').toString(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .where((item) => item.value != null)
                  .toList(),
              onChanged: pickupLocations.isEmpty
                  ? null
                  : (value) {
                      final selected = pickupLocations.firstWhere(
                        (location) => _parseInt(location['id']) == value,
                        orElse: () => <String, dynamic>{},
                      );
                      onSelectPickupLocation(
                        selected.isEmpty ? null : selected,
                      );
                    },
            ),
            if (isLoadingLocations) ...[
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
              const LinearProgressIndicator(
                minHeight: AppSpacing.progress,
                color: AppColors.secondary,
                backgroundColor: AppColors.goldMuted,
              ),
            ],
          ],
        ],
      ),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _FulfillmentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FulfillmentOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.large,
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
            Icon(icon, color: AppColors.primary, size: AppIconSize.inline),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        price,
                        style: const TextStyle(
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String subtotal;
  final String tax;
  final String taxLabel;
  final String shipping;
  final String shippingLabel;
  final String total;

  const _SummaryCard({
    required this.subtotal,
    required this.tax,
    required this.taxLabel,
    required this.shipping,
    required this.shippingLabel,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: subtotal),
          if (tax.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _SummaryRow(label: taxLabel, value: tax),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          _SummaryRow(label: shippingLabel, value: shipping),
          const Divider(height: AppSpacing.dividerTall),
          _SummaryRow(
            label: 'Total estimado',
            value: total,
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'El total se actualiza según el método de entrega seleccionado.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: (highlight ? textTheme.titleLarge : textTheme.titleSmall)
              ?.copyWith(
            fontWeight: FontWeight.w900,
            color: highlight ? AppColors.textPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class EmptyCartView extends StatelessWidget {
  const EmptyCartView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.hero,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: AppIconSize.emptyState,
                color: AppColors.goldDeep,
              ),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
              Text(
                'Tu carrito está vacío',
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
              const Text(
                'Agrega productos desde la tienda para preparar un pedido claro, elegante y rápido.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
