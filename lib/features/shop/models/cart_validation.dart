class ShopCartValidationItem {
  final int productId;
  final String name;
  final int requestedQuantity;
  final int finalQuantity;
  final int? availableQuantity;
  final double? oldUnitPrice;
  final double? newUnitPrice;
  final bool removed;
  final bool inStock;
  final String message;
  final String severity;

  const ShopCartValidationItem({
    required this.productId,
    required this.name,
    required this.requestedQuantity,
    required this.finalQuantity,
    required this.availableQuantity,
    required this.oldUnitPrice,
    required this.newUnitPrice,
    required this.removed,
    required this.inStock,
    required this.message,
    required this.severity,
  });

  bool get hasQuantityChanged =>
      requestedQuantity > 0 && requestedQuantity != finalQuantity;

  bool get hasPriceChanged =>
      oldUnitPrice != null &&
      newUnitPrice != null &&
      (oldUnitPrice! - newUnitPrice!).abs() > 0.009;

  bool get isBlocking =>
      severity == 'error' || (!inStock && finalQuantity <= 0);

  bool get hasChange => removed || hasQuantityChanged || hasPriceChanged;

  factory ShopCartValidationItem.fromJson(Map<String, dynamic> json) {
    final requestedQuantity = _parseInt(
      json['requested_quantity'] ??
          json['requestedQuantity'] ??
          json['requested'] ??
          json['quantity_before'] ??
          json['quantity'],
    );
    final rawFinalQuantity = json['final_quantity'] ??
        json['finalQuantity'] ??
        json['adjusted_quantity'] ??
        json['adjustedQuantity'] ??
        json['quantity_after'] ??
        json['quantity'];
    final availableQuantity = _parseNullableInt(
      json['available_quantity'] ??
          json['availableQuantity'] ??
          json['max_quantity'] ??
          json['maxQuantity'] ??
          json['stock_quantity'] ??
          json['stockQuantity'],
    );
    var finalQuantity = _parseInt(rawFinalQuantity ?? requestedQuantity);
    if (rawFinalQuantity == null &&
        availableQuantity != null &&
        requestedQuantity > availableQuantity) {
      finalQuantity = availableQuantity;
    }
    final removed = _parseBool(
          json['removed'] ??
              json['is_removed'] ??
              json['unavailable'] ??
              json['out_of_stock'],
        ) ??
        finalQuantity <= 0;
    final inStock = _parseBool(
          json['in_stock'] ?? json['inStock'] ?? json['is_in_stock'],
        ) ??
        !removed;
    final severity = (json['severity'] ?? json['level'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return ShopCartValidationItem(
      productId:
          _parseInt(json['product_id'] ?? json['productId'] ?? json['id']),
      name: (json['name'] ?? json['product_name'] ?? 'Producto').toString(),
      requestedQuantity: requestedQuantity,
      finalQuantity: finalQuantity,
      availableQuantity: availableQuantity,
      oldUnitPrice: _parseNullableDouble(
        json['old_unit_price'] ??
            json['oldUnitPrice'] ??
            json['current_unit_price'] ??
            json['currentUnitPrice'] ??
            json['unit_price_before'] ??
            json['unitPriceBefore'],
      ),
      newUnitPrice: _parseNullableDouble(
        json['new_unit_price'] ??
            json['newUnitPrice'] ??
            json['unit_price'] ??
            json['unitPrice'] ??
            json['price'] ??
            json['display_price'],
      ),
      removed: removed,
      inStock: inStock,
      message: (json['message'] ?? json['reason'] ?? '').toString().trim(),
      severity: severity.isEmpty ? (removed ? 'warning' : 'info') : severity,
    );
  }
}

class ShopCartValidationResult {
  final bool canCheckout;
  final bool cartChanged;
  final bool endpointAvailable;
  final String message;
  final List<ShopCartValidationItem> items;

  const ShopCartValidationResult({
    required this.canCheckout,
    required this.cartChanged,
    required this.endpointAvailable,
    required this.message,
    required this.items,
  });

  bool get shouldInterruptCheckout =>
      endpointAvailable && (!canCheckout || cartChanged);

  List<ShopCartValidationItem> get visibleItems {
    final changedItems =
        items.where((item) => item.hasChange || item.isBlocking);
    if (changedItems.isNotEmpty) return changedItems.toList();
    return items;
  }

  ShopCartValidationResult copyWith({
    bool? canCheckout,
    bool? cartChanged,
    bool? endpointAvailable,
    String? message,
    List<ShopCartValidationItem>? items,
  }) {
    return ShopCartValidationResult(
      canCheckout: canCheckout ?? this.canCheckout,
      cartChanged: cartChanged ?? this.cartChanged,
      endpointAvailable: endpointAvailable ?? this.endpointAvailable,
      message: message ?? this.message,
      items: items ?? this.items,
    );
  }

  factory ShopCartValidationResult.unavailable() {
    return const ShopCartValidationResult(
      canCheckout: true,
      cartChanged: false,
      endpointAvailable: false,
      message: '',
      items: [],
    );
  }

  factory ShopCartValidationResult.fromJson(Map<String, dynamic> json) {
    final payload =
        _asMap(json['data']).isNotEmpty ? _asMap(json['data']) : json;
    final rawItems = payload['items'] ??
        payload['line_items'] ??
        payload['lineItems'] ??
        payload['cart_items'] ??
        payload['cartItems'];
    final items = rawItems is Iterable
        ? rawItems
            .whereType<Map>()
            .map((item) => ShopCartValidationItem.fromJson(_asMap(item)))
            .where((item) => item.productId > 0)
            .toList()
        : const <ShopCartValidationItem>[];
    final inferredChanged = items.any((item) => item.hasChange);
    final canCheckout = _parseBool(
          payload['can_checkout'] ??
              payload['canCheckout'] ??
              payload['valid'] ??
              payload['is_valid'],
        ) ??
        !items.any((item) => item.isBlocking);

    return ShopCartValidationResult(
      canCheckout: canCheckout,
      cartChanged: _parseBool(
            payload['cart_changed'] ??
                payload['cartChanged'] ??
                payload['changed'] ??
                payload['requires_update'] ??
                payload['requiresUpdate'],
          ) ??
          inferredChanged,
      endpointAvailable: true,
      message: (payload['message'] ?? json['message'] ?? '').toString().trim(),
      items: items,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  final parsed = _parseInt(value);
  return parsed < 0 ? null : parsed;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool? _parseBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (['1', 'true', 'yes', 'si', 'valid', 'available'].contains(normalized)) {
    return true;
  }
  if ([
    '0',
    'false',
    'no',
    'invalid',
    'unavailable',
    'outofstock',
    'out-of-stock',
  ].contains(normalized)) {
    return false;
  }
  return null;
}
