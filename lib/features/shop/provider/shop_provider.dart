import 'package:flutter/foundation.dart';

import '../../auth/models/auth_user.dart';
import '../data/services/habito_shop_api.dart';
import '../models/shop_payment_method.dart';

enum ShopFulfillmentMethod {
  delivery,
  pickup,
}

class ShopCartActionResult {
  final bool success;
  final bool requiresCartReset;
  final bool quantitiesAdjusted;
  final int adjustedItemsCount;
  final String? message;

  const ShopCartActionResult({
    required this.success,
    this.requiresCartReset = false,
    this.quantitiesAdjusted = false,
    this.adjustedItemsCount = 0,
    this.message,
  });
}

extension ShopFulfillmentMethodInfo on ShopFulfillmentMethod {
  String get title {
    switch (this) {
      case ShopFulfillmentMethod.delivery:
        return 'Envío local';
      case ShopFulfillmentMethod.pickup:
        return 'Retiro en tienda';
    }
  }

  String get description {
    switch (this) {
      case ShopFulfillmentMethod.delivery:
        return 'Recibe tu pedido en la dirección indicada.';
      case ShopFulfillmentMethod.pickup:
        return 'Indica tu sucursal preferida para coordinar el retiro sin pagar envío.';
    }
  }

  String get shippingMethodId {
    switch (this) {
      case ShopFulfillmentMethod.delivery:
        return 'flat_rate';
      case ShopFulfillmentMethod.pickup:
        return 'local_pickup';
    }
  }

  String get payloadValue {
    switch (this) {
      case ShopFulfillmentMethod.delivery:
        return 'delivery';
      case ShopFulfillmentMethod.pickup:
        return 'pickup';
    }
  }
}

class ShopCartItem {
  final int productId;
  final String name;
  final String imageUrl;
  final String category;
  final double unitPrice;
  final int quantity;
  final bool inStock;
  final bool taxable;
  final double taxRatePercent;
  final String taxType;
  final String taxLabel;
  final bool pricesIncludeTax;
  final int? globalMaxQuantity;
  final List<Map<String, dynamic>> warehouseStock;
  final int? maxQuantity;

  const ShopCartItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    required this.inStock,
    required this.taxable,
    required this.taxRatePercent,
    required this.taxType,
    required this.taxLabel,
    required this.pricesIncludeTax,
    required this.globalMaxQuantity,
    required this.warehouseStock,
    required this.maxQuantity,
  });

  double get total => unitPrice * quantity;
  double get taxRate => taxRatePercent <= 0 ? 0 : taxRatePercent / 100;

  double get unitTax {
    if (!taxable || taxRate <= 0 || unitPrice <= 0) return 0;
    if (pricesIncludeTax) {
      return unitPrice - (unitPrice / (1 + taxRate));
    }
    return unitPrice * taxRate;
  }

  double get taxTotal => unitTax * quantity;
  double get additionalTaxTotal => pricesIncludeTax ? 0 : taxTotal;

  ShopCartItem copyWith({
    int? quantity,
    bool? inStock,
    int? globalMaxQuantity,
    List<Map<String, dynamic>>? warehouseStock,
    int? maxQuantity,
  }) {
    return ShopCartItem(
      productId: productId,
      name: name,
      imageUrl: imageUrl,
      category: category,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      inStock: inStock ?? this.inStock,
      taxable: taxable,
      taxRatePercent: taxRatePercent,
      taxType: taxType,
      taxLabel: taxLabel,
      pricesIncludeTax: pricesIncludeTax,
      globalMaxQuantity: globalMaxQuantity ?? this.globalMaxQuantity,
      warehouseStock: warehouseStock ?? this.warehouseStock,
      maxQuantity: maxQuantity ?? this.maxQuantity,
    );
  }
}

class ShopProvider extends ChangeNotifier {
  static const double fixedShippingTotal = 3.50;

  final List<ShopCartItem> _cartItems = [];
  final List<Map<String, dynamic>> _orders = [];
  final List<ShopPaymentMethod> _paymentMethods = [
    ShopPaymentMethod.bankTransfer,
  ];
  final Set<int> _uploadingProofOrderIds = {};

  String? _ordersToken;
  bool _isCreatingOrder = false;
  bool _isLoadingOrders = false;
  bool _isLoadingPaymentMethods = false;
  bool _hasLoadedPaymentMethods = false;
  String? _checkoutError;
  String? _ordersError;
  String? _paymentMethodsError;
  String? _paymentProofError;
  ShopFulfillmentMethod _fulfillmentMethod = ShopFulfillmentMethod.delivery;
  Map<String, dynamic>? _pickupLocation;

  List<ShopCartItem> get cartItems => List.unmodifiable(_cartItems);
  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  List<ShopPaymentMethod> get paymentMethods =>
      List.unmodifiable(_paymentMethods);
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingPaymentMethods => _isLoadingPaymentMethods;
  String? get checkoutError => _checkoutError;
  String? get ordersError => _ordersError;
  String? get paymentMethodsError => _paymentMethodsError;
  String? get paymentProofError => _paymentProofError;
  bool isUploadingPaymentProof(int orderId) =>
      _uploadingProofOrderIds.contains(orderId);
  ShopFulfillmentMethod get fulfillmentMethod => _fulfillmentMethod;
  Map<String, dynamic>? get pickupLocation => _pickupLocation == null
      ? null
      : Map<String, dynamic>.from(_pickupLocation!);
  String get pickupLocationName =>
      (_pickupLocation?['name'] ?? '').toString().trim();
  int get cartCount =>
      _cartItems.fold<int>(0, (total, item) => total + item.quantity);
  bool get hasItems => _cartItems.isNotEmpty;
  double get subtotal =>
      _cartItems.fold<double>(0, (total, item) => total + item.total);
  double get shippingTotal => _cartItems.isEmpty ? 0 : fixedShippingTotal;
  double get taxTotal =>
      _cartItems.fold<double>(0, (total, item) => total + item.taxTotal);
  double get additionalTaxTotal => _cartItems.fold<double>(
        0,
        (total, item) => total + item.additionalTaxTotal,
      );
  bool get hasTaxableItems => _cartItems.any((item) => item.taxTotal > 0);
  bool get hasIvaBreakdown => _cartItems.any(
        (item) =>
            item.taxType == 'iva_15' ||
            item.taxType == 'iva_0' ||
            item.taxTotal > 0,
      );
  bool get hasIva15Items => _cartItems.any(
        (item) => item.taxType == 'iva_15' || item.taxRatePercent > 0,
      );
  bool get hasIva0Items => _cartItems.any((item) => item.taxType == 'iva_0');
  bool get taxIsIncluded =>
      hasTaxableItems && _cartItems.any((item) => item.pricesIncludeTax);
  String get taxBreakdownLabel {
    if (hasIva15Items && hasIva0Items) {
      return additionalTaxTotal > 0 ? 'IVA' : 'IVA incluido';
    }
    if (hasIva15Items) {
      return additionalTaxTotal > 0 ? 'IVA 15%' : 'IVA 15% incluido';
    }
    if (hasIva0Items) return 'IVA 0%';
    return 'IVA';
  }

  double get orderTotal => orderTotalFor(ShopFulfillmentMethod.delivery);
  double get selectedShippingTotal => shippingTotalFor(_fulfillmentMethod);
  double get selectedOrderTotal => orderTotalFor(_fulfillmentMethod);

  double shippingTotalFor(ShopFulfillmentMethod method) {
    if (_cartItems.isEmpty) return 0;
    switch (method) {
      case ShopFulfillmentMethod.delivery:
        return fixedShippingTotal;
      case ShopFulfillmentMethod.pickup:
        return 0;
    }
  }

  double orderTotalFor(ShopFulfillmentMethod method) {
    return subtotal + shippingTotalFor(method) + additionalTaxTotal;
  }

  void setFulfillmentMethod(ShopFulfillmentMethod method) {
    changeFulfillmentMethod(method);
  }

  void setPickupLocation(Map<String, dynamic>? location) {
    changePickupLocation(location);
  }

  ShopCartActionResult addProduct(
    Map<String, dynamic> product, {
    int quantity = 1,
    ShopFulfillmentMethod? fulfillmentMethod,
    Map<String, dynamic>? pickupLocation,
    bool replaceCartContext = false,
  }) {
    final productId = _parseInt(product['id']);
    if (productId <= 0 || quantity <= 0) {
      return const ShopCartActionResult(
        success: false,
        message: 'No pudimos agregar este producto al carrito.',
      );
    }

    final requestedMethod = fulfillmentMethod ?? _fulfillmentMethod;
    final requestedPickupLocation =
        requestedMethod == ShopFulfillmentMethod.pickup
            ? _normalizePickupLocation(pickupLocation ?? _pickupLocation)
            : null;

    if (requestedMethod == ShopFulfillmentMethod.pickup &&
        requestedPickupLocation == null) {
      return const ShopCartActionResult(
        success: false,
        message: 'Selecciona primero la sucursal de retiro.',
      );
    }

    if (_cartItems.isNotEmpty) {
      final methodChanged = requestedMethod != _fulfillmentMethod;
      final pickupChanged = requestedMethod == ShopFulfillmentMethod.pickup &&
          !_samePickupLocation(_pickupLocation, requestedPickupLocation);

      if ((methodChanged || pickupChanged) && !replaceCartContext) {
        return ShopCartActionResult(
          success: false,
          requiresCartReset: true,
          message: requestedMethod == ShopFulfillmentMethod.pickup
              ? 'Tu carrito ya esta asociado a otra forma de entrega o a otra sucursal. Para continuar, reemplazaremos el carrito actual.'
              : 'Tu carrito actual esta preparado para retiro en tienda. Para continuar con envio, reemplazaremos el carrito actual.',
        );
      }

      if (methodChanged || pickupChanged) {
        _cartItems.clear();
      }
    }

    _applyCartContext(requestedMethod, requestedPickupLocation);

    final globalMaxQuantity = _extractMaxQuantity(product);
    final warehouseStock = _extractWarehouseStock(product);
    final maxQuantity = _resolveMaxQuantityForProduct(
      globalMaxQuantity: globalMaxQuantity,
      warehouseStock: warehouseStock,
      fulfillmentMethod: requestedMethod,
      pickupLocation: requestedPickupLocation,
    );

    final existingIndex =
        _cartItems.indexWhere((item) => item.productId == productId);
    var addedQuantity = quantity;

    if (existingIndex >= 0) {
      final current = _cartItems[existingIndex];
      if (maxQuantity != null && current.quantity >= maxQuantity) {
        notifyListeners();
        return const ShopCartActionResult(
          success: false,
          message: 'Ya tienes el maximo disponible de este producto.',
        );
      }
      if (maxQuantity != null) {
        final remaining = maxQuantity - current.quantity;
        if (remaining <= 0) {
          notifyListeners();
          return const ShopCartActionResult(
            success: false,
            message: 'Ya tienes el maximo disponible de este producto.',
          );
        }
        if (addedQuantity > remaining) {
          addedQuantity = remaining;
        }
      }
      _cartItems[existingIndex] = current.copyWith(
        quantity: current.quantity + addedQuantity,
        globalMaxQuantity: globalMaxQuantity,
        warehouseStock: warehouseStock,
        maxQuantity: maxQuantity,
      );
    } else {
      if (maxQuantity != null) {
        if (maxQuantity <= 0) {
          notifyListeners();
          return ShopCartActionResult(
            success: false,
            message: requestedMethod == ShopFulfillmentMethod.pickup
                ? 'Esta sucursal ya no tiene stock disponible para este producto.'
                : 'Este producto ya no tiene stock disponible.',
          );
        }
        if (addedQuantity > maxQuantity) {
          addedQuantity = maxQuantity;
        }
      }
      _cartItems.add(
        ShopCartItem(
          productId: productId,
          name: (product['name'] ?? 'Producto').toString(),
          imageUrl: _extractImageUrl(product),
          category: _extractCategory(product),
          unitPrice: _extractDisplayPrice(product),
          quantity: addedQuantity,
          inStock: _isProductInStock(product),
          taxable: _isProductTaxable(product),
          taxRatePercent: _extractTaxRatePercent(product),
          taxType: _extractTaxType(product),
          taxLabel: _extractTaxLabel(product),
          pricesIncludeTax: _displayPricesIncludeTax(product),
          globalMaxQuantity: globalMaxQuantity,
          warehouseStock: warehouseStock,
          maxQuantity: maxQuantity,
        ),
      );
    }

    notifyListeners();
    if (addedQuantity < quantity) {
      return ShopCartActionResult(
        success: true,
        message:
            'Solo agregamos $addedQuantity unidad(es), segun el stock disponible.',
      );
    }
    return const ShopCartActionResult(success: true);
  }

  ShopCartActionResult changeFulfillmentMethod(ShopFulfillmentMethod method) {
    final result = updateCartContext(
      fulfillmentMethod: method,
      pickupLocation:
          method == ShopFulfillmentMethod.pickup ? _pickupLocation : null,
    );
    return result;
  }

  ShopCartActionResult changePickupLocation(Map<String, dynamic>? location) {
    final result = updateCartContext(
      fulfillmentMethod: _fulfillmentMethod,
      pickupLocation: location,
    );
    return result;
  }

  ShopCartActionResult updateCartContext({
    required ShopFulfillmentMethod fulfillmentMethod,
    Map<String, dynamic>? pickupLocation,
  }) {
    final normalizedPickupLocation =
        fulfillmentMethod == ShopFulfillmentMethod.pickup
            ? _normalizePickupLocation(pickupLocation)
            : null;
    final methodChanged = _fulfillmentMethod != fulfillmentMethod;
    final pickupChanged =
        !_samePickupLocation(_pickupLocation, normalizedPickupLocation);

    if (!methodChanged && !pickupChanged) {
      return const ShopCartActionResult(success: true);
    }

    _applyCartContext(fulfillmentMethod, normalizedPickupLocation);
    final adjustedItemsCount = _recalculateCartItemLimits();
    notifyListeners();
    if (adjustedItemsCount > 0) {
      return ShopCartActionResult(
        success: true,
        quantitiesAdjusted: true,
        adjustedItemsCount: adjustedItemsCount,
        message:
            'Ajustamos algunas cantidades segun el stock disponible para la opcion seleccionada.',
      );
    }
    return const ShopCartActionResult(success: true);
  }

  void incrementQuantity(int productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index < 0) return;

    final item = _cartItems[index];
    if (item.maxQuantity != null && item.quantity >= item.maxQuantity!) {
      notifyListeners();
      return;
    }
    _cartItems[index] = item.copyWith(quantity: item.quantity + 1);
    notifyListeners();
  }

  void decrementQuantity(int productId) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index < 0) return;

    final item = _cartItems[index];
    if (item.quantity <= 1) {
      _cartItems.removeAt(index);
    } else {
      _cartItems[index] = item.copyWith(quantity: item.quantity - 1);
    }
    _resetCartContextIfEmpty();
    notifyListeners();
  }

  void removeProduct(int productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _resetCartContextIfEmpty();
    notifyListeners();
  }

  void clearCart() {
    if (_cartItems.isEmpty &&
        _fulfillmentMethod == ShopFulfillmentMethod.delivery &&
        _pickupLocation == null) {
      return;
    }
    _cartItems.clear();
    _resetCartContextIfEmpty();
    notifyListeners();
  }

  Future<void> loadOrders({
    required String token,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingOrders) return;
    _scopeOrdersToToken(token);
    if (!forceRefresh && _orders.isNotEmpty) return;

    _isLoadingOrders = true;
    _ordersError = null;
    notifyListeners();

    try {
      final result = await HabitoShopApi.getOrders(
        token: token,
        forceRefresh: forceRefresh,
      );
      final mergedOrders = HabitoShopApi.mergeOrders([
        ..._orders,
        ...result,
      ]);
      if (mergedOrders.isNotEmpty || _orders.isEmpty) {
        _orders
          ..clear()
          ..addAll(mergedOrders);
      }
    } catch (e) {
      _ordersError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadPaymentMethods({bool forceRefresh = false}) async {
    if (_isLoadingPaymentMethods) return;
    if (!forceRefresh && _hasLoadedPaymentMethods) return;

    _isLoadingPaymentMethods = true;
    _paymentMethodsError = null;
    notifyListeners();

    try {
      final result = await HabitoShopApi.getPaymentMethods(
        forceRefresh: forceRefresh,
      );
      _paymentMethods
        ..clear()
        ..addAll(
            result.isEmpty ? const [ShopPaymentMethod.bankTransfer] : result);
    } catch (e) {
      _paymentMethodsError = e.toString().replaceFirst('Exception: ', '');
      _paymentMethods
        ..clear()
        ..add(ShopPaymentMethod.bankTransfer);
    } finally {
      _hasLoadedPaymentMethods = true;
      _isLoadingPaymentMethods = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> checkout({
    required String token,
    required AuthUser user,
    required String firstName,
    required String lastName,
    required String billingName,
    required String billingEmail,
    required String billingPhone,
    required String documentType,
    required String documentNumber,
    required String address,
    String address2 = '',
    required String city,
    String state = '',
    required String customerNote,
    required ShopPaymentMethod paymentMethod,
    required ShopFulfillmentMethod fulfillmentMethod,
    double redeemPoints = 0,
  }) async {
    if (_cartItems.isEmpty) {
      _checkoutError = 'Tu carrito esta vacio.';
      notifyListeners();
      return null;
    }

    _scopeOrdersToToken(token);
    _isCreatingOrder = true;
    _checkoutError = null;
    notifyListeners();

    try {
      final selectedShippingTotal = shippingTotalFor(fulfillmentMethod);
      final selectedOrderTotal = orderTotalFor(fulfillmentMethod);
      final selectedPickupLocationName =
          (fulfillmentMethod == ShopFulfillmentMethod.pickup)
              ? pickupLocationName
              : '';
      final normalizedCustomerNote = [
        customerNote.trim(),
        'Facturación: $billingName.',
        'Documento: ${documentType.toUpperCase()} $documentNumber.',
        'Entrega: ${fulfillmentMethod.title}.',
        if (selectedPickupLocationName.isNotEmpty)
          'Sucursal preferida de retiro: $selectedPickupLocationName.',
      ].where((part) => part.isNotEmpty).join('\n');

      final order = await HabitoShopApi.createOrder(
        token: token,
        lineItems: _cartItems
            .map(
              (item) => {
                'product_id': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(),
        customerId: user.id,
        wooCustomerId: user.wooCustomerId,
        firstName: firstName.trim().isNotEmpty ? firstName : user.firstName,
        lastName: lastName.trim().isNotEmpty ? lastName : user.lastName,
        company: documentType == 'ruc' ? billingName : '',
        email: billingEmail.trim().isNotEmpty ? billingEmail : user.email,
        phone: billingPhone.trim().isNotEmpty ? billingPhone : user.phone,
        address1: address,
        address2: address2,
        city: city,
        state: state,
        country: 'EC',
        customerNote: normalizedCustomerNote,
        billingDocumentType: documentType,
        billingDocumentNumber: documentNumber,
        paymentMethod: paymentMethod.id,
        paymentTitle: paymentMethod.title,
        shippingTotal: selectedShippingTotal,
        subtotal: subtotal,
        taxTotal: taxTotal,
        pricesIncludeTax: taxIsIncluded,
        orderTotal: selectedOrderTotal,
        shippingMethodId: fulfillmentMethod.shippingMethodId,
        shippingMethodTitle: fulfillmentMethod.title,
        fulfillmentMethod: fulfillmentMethod.payloadValue,
        pickupLocationId: fulfillmentMethod == ShopFulfillmentMethod.pickup
            ? _parseInt(_pickupLocation?['id'])
            : 0,
        pickupLocationName: selectedPickupLocationName,
        pickupWarehouseExternalId:
            fulfillmentMethod == ShopFulfillmentMethod.pickup
                ? (_pickupLocation?['external_id'] ?? '').toString().trim()
                : '',
        status: paymentMethod.orderStatus,
        redeemPoints: redeemPoints,
      );

      _orders
        ..clear()
        ..addAll(HabitoShopApi.mergeOrders([order, ..._orders]));
      _ordersError = null;
      _cartItems.clear();
      _resetCartContextIfEmpty();
      return order;
    } catch (e) {
      _checkoutError = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  Future<bool> uploadPaymentProof({
    required String token,
    required int orderId,
    required String filePath,
  }) async {
    if (orderId <= 0 || filePath.trim().isEmpty) return false;
    if (_uploadingProofOrderIds.contains(orderId)) return false;

    _scopeOrdersToToken(token);
    _uploadingProofOrderIds.add(orderId);
    _paymentProofError = null;
    notifyListeners();

    try {
      final updatedOrder = await HabitoShopApi.uploadPaymentProof(
        token: token,
        orderId: orderId,
        filePath: filePath,
      );
      final index =
          _orders.indexWhere((order) => _parseInt(order['id']) == orderId);
      if (index >= 0) {
        _orders[index] = updatedOrder;
      } else {
        _orders.insert(0, updatedOrder);
      }
      final mergedOrders = HabitoShopApi.mergeOrders(_orders);
      _orders
        ..clear()
        ..addAll(mergedOrders);
      _paymentProofError = null;
      return true;
    } catch (e) {
      _paymentProofError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _uploadingProofOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  void _scopeOrdersToToken(String token) {
    if (_ordersToken == token) return;
    _ordersToken = token;
    _orders.clear();
    _uploadingProofOrderIds.clear();
  }

  void clearErrors() {
    if (_checkoutError == null &&
        _ordersError == null &&
        _paymentMethodsError == null &&
        _paymentProofError == null) {
      return;
    }
    _checkoutError = null;
    _ordersError = null;
    _paymentMethodsError = null;
    _paymentProofError = null;
    notifyListeners();
  }

  void _applyCartContext(
    ShopFulfillmentMethod fulfillmentMethod,
    Map<String, dynamic>? pickupLocation,
  ) {
    _fulfillmentMethod = fulfillmentMethod;
    _pickupLocation = fulfillmentMethod == ShopFulfillmentMethod.pickup
        ? pickupLocation == null
            ? null
            : Map<String, dynamic>.from(pickupLocation)
        : null;
  }

  void _resetCartContextIfEmpty() {
    if (_cartItems.isNotEmpty) return;
    _fulfillmentMethod = ShopFulfillmentMethod.delivery;
    _pickupLocation = null;
  }

  int _recalculateCartItemLimits() {
    if (_cartItems.isEmpty) return 0;

    var adjustedItemsCount = 0;
    final updatedItems = <ShopCartItem>[];

    for (final item in _cartItems) {
      final maxQuantity = _resolveMaxQuantityForProduct(
        globalMaxQuantity: item.globalMaxQuantity,
        warehouseStock: item.warehouseStock,
        fulfillmentMethod: _fulfillmentMethod,
        pickupLocation: _pickupLocation,
      );

      var nextQuantity = item.quantity;
      if (maxQuantity != null && nextQuantity > maxQuantity) {
        nextQuantity = maxQuantity;
      }

      if (nextQuantity <= 0) {
        adjustedItemsCount++;
        continue;
      }

      if (nextQuantity != item.quantity || maxQuantity != item.maxQuantity) {
        adjustedItemsCount++;
      }

      updatedItems.add(
        item.copyWith(
          quantity: nextQuantity,
          maxQuantity: maxQuantity,
        ),
      );
    }

    _cartItems
      ..clear()
      ..addAll(updatedItems);
    _resetCartContextIfEmpty();
    return adjustedItemsCount;
  }

  static String _extractImageUrl(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map && first['src'] != null) {
        return first['src'].toString();
      }
    }
    return '';
  }

  static String _extractCategory(Map<String, dynamic> product) {
    final categories = product['categories'];
    if (categories is List && categories.isNotEmpty) {
      final first = categories.first;
      if (first is Map && first['name'] != null) {
        return first['name'].toString();
      }
    }
    return 'Producto';
  }

  static bool _isProductInStock(Map<String, dynamic> product) {
    final value = product['in_stock'] ?? product['is_in_stock'];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'instock';
    }
    return false;
  }

  static bool _isProductTaxable(Map<String, dynamic> product) {
    final taxType = _extractTaxType(product);
    if (taxType == 'iva_15' || taxType == 'iva_0') return true;
    if (taxType == 'no_iva') return false;

    final explicit = _parseBool(
      product['taxable'] ?? product['is_taxable'] ?? product['isTaxable'],
    );
    if (explicit != null) return explicit;

    final status =
        (product['tax_status'] ?? product['taxStatus'] ?? '').toString();
    return status.toLowerCase().trim() == 'taxable';
  }

  static bool _displayPricesIncludeTax(Map<String, dynamic> product) {
    return _parseBool(
          product['display_prices_include_tax'] ??
              product['displayPricesIncludeTax'] ??
              product['price_including_tax_is_display'],
        ) ??
        true;
  }

  static double _extractDisplayPrice(Map<String, dynamic> product) {
    return _parseDouble(
      product['display_price'] ??
          product['displayPrice'] ??
          product['price_including_tax'] ??
          product['priceIncludingTax'] ??
          product['price'] ??
          product['regular_price'],
    );
  }

  static double _extractTaxRatePercent(Map<String, dynamic> product) {
    final taxType = _extractTaxType(product);
    if (taxType == 'iva_15') return 15;
    if (taxType == 'iva_0' || taxType == 'no_iva') return 0;

    final direct = _parseDouble(
      product['iva_rate_percent'] ??
          product['ivaRatePercent'] ??
          product['tax_rate_percent'] ??
          product['taxRatePercent'] ??
          product['tax_rate'],
    );
    if (direct > 0) return direct;

    final rates = product['tax_rates'] ?? product['taxRates'];
    if (rates is List) {
      return rates.whereType<Map>().fold<double>(0, (total, rate) {
        return total + _parseDouble(rate['rate'] ?? rate['percent']);
      });
    }

    return 0;
  }

  static String _extractTaxType(Map<String, dynamic> product) {
    final raw = (product['iva_type'] ??
            product['ivaType'] ??
            product['tax_type'] ??
            product['taxType'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    if (raw == 'iva_15' || raw == 'iva15' || raw == 'iva-15') {
      return 'iva_15';
    }
    if (raw == 'iva_0' ||
        raw == 'iva0' ||
        raw == 'iva-0' ||
        raw == 'zero_rate') {
      return 'iva_0';
    }
    if (raw == 'no_iva' || raw == 'noiva' || raw == 'none') {
      return 'no_iva';
    }

    final rate = _parseDouble(
      product['iva_rate_percent'] ??
          product['ivaRatePercent'] ??
          product['tax_rate_percent'] ??
          product['taxRatePercent'] ??
          product['tax_rate'],
    );
    if (rate > 0) return rate == 15 ? 'iva_15' : 'iva_other';

    final status =
        (product['tax_status'] ?? product['taxStatus'] ?? '').toString();
    final taxClass = (product['tax_class'] ?? product['taxClass'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (status.toLowerCase().trim() == 'taxable' &&
        (taxClass.isEmpty || taxClass == 'standard')) {
      return 'iva_15';
    }
    if (status.toLowerCase().trim() == 'taxable') return 'iva_0';

    return 'no_iva';
  }

  static String _extractTaxLabel(Map<String, dynamic> product) {
    final explicit =
        (product['iva_label'] ?? product['ivaLabel'] ?? product['tax_label'])
            ?.toString()
            .trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    switch (_extractTaxType(product)) {
      case 'iva_15':
        return 'IVA 15%';
      case 'iva_0':
        return 'IVA 0%';
      case 'iva_other':
        final rate = _extractTaxRatePercent(product);
        return rate > 0 ? 'IVA ${rate.toStringAsFixed(2)}%' : 'IVA';
      default:
        return 'No grava IVA';
    }
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase().trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (['1', 'true', 'yes', 'si', 'taxable'].contains(normalized)) {
      return true;
    }
    if (['0', 'false', 'no', 'none', 'nontaxable'].contains(normalized)) {
      return false;
    }
    return null;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic>? _normalizePickupLocation(
    Map<String, dynamic>? location,
  ) {
    if (location == null) return null;
    final id = _parseInt(location['id']);
    final externalId = (location['external_id'] ?? location['externalId'] ?? '')
        .toString()
        .trim();
    final name = (location['name'] ?? '').toString().trim();
    if (id <= 0 && externalId.isEmpty && name.isEmpty) return null;
    return {
      ...location,
      'id': id > 0 ? id : location['id'],
      'external_id': externalId,
      'name': name,
    };
  }

  static bool _samePickupLocation(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    final normalizedA = _normalizePickupLocation(a);
    final normalizedB = _normalizePickupLocation(b);
    if (normalizedA == null && normalizedB == null) return true;
    if (normalizedA == null || normalizedB == null) return false;

    final externalA = (normalizedA['external_id'] ?? '').toString().trim();
    final externalB = (normalizedB['external_id'] ?? '').toString().trim();
    if (externalA.isNotEmpty || externalB.isNotEmpty) {
      return externalA == externalB;
    }

    return _parseInt(normalizedA['id']) == _parseInt(normalizedB['id']);
  }

  static int? _extractMaxQuantity(Map<String, dynamic> product) {
    final manageStock =
        _parseBool(product['manage_stock'] ?? product['manageStock']) ?? false;
    if (!manageStock) return null;

    final quantity = _parseInt(
      product['stock_quantity'] ?? product['stockQuantity'],
    );
    if (quantity <= 0) return 0;
    return quantity;
  }

  static List<Map<String, dynamic>> _extractWarehouseStock(
    Map<String, dynamic> product,
  ) {
    final raw = product['warehouse_stock'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw.whereType<Map>().map<Map<String, dynamic>>((item) {
      final quantity = _parseInt(item['quantity'] ?? item['stock_quantity']);
      return {
        ...item,
        'id': _parseInt(item['id']),
        'external_id':
            (item['external_id'] ?? item['warehouse_external_id'] ?? '')
                .toString()
                .trim(),
        'name': (item['name'] ?? 'Sucursal').toString().trim(),
        'code': (item['code'] ?? '').toString().trim(),
        'city': (item['city'] ?? '').toString().trim(),
        'quantity': quantity,
        'in_stock': (_parseBool(item['in_stock']) ?? false) || quantity > 0,
        'is_default': item['is_default'] == true,
      };
    }).toList();
  }

  static int? _resolveMaxQuantityForProduct({
    required int? globalMaxQuantity,
    required List<Map<String, dynamic>> warehouseStock,
    required ShopFulfillmentMethod fulfillmentMethod,
    required Map<String, dynamic>? pickupLocation,
  }) {
    if (fulfillmentMethod == ShopFulfillmentMethod.delivery) {
      return globalMaxQuantity;
    }

    final normalizedPickupLocation = _normalizePickupLocation(pickupLocation);
    if (normalizedPickupLocation == null) {
      return globalMaxQuantity;
    }

    final externalId =
        (normalizedPickupLocation['external_id'] ?? '').toString().trim();
    final pickupId = _parseInt(normalizedPickupLocation['id']);

    for (final item in warehouseStock) {
      final itemExternalId = (item['external_id'] ?? '').toString().trim();
      final itemId = _parseInt(item['id']);
      if ((externalId.isNotEmpty && itemExternalId == externalId) ||
          (externalId.isEmpty && pickupId > 0 && itemId == pickupId)) {
        return _parseInt(item['quantity']);
      }
    }

    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
