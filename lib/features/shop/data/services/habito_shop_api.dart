import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../models/shop_payment_method.dart';
import '../../models/cart_validation.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/utils/uuid.dart';

class HabitoShopApi {
  static const String _customBase = AppConfig.apiBaseUrl;
  static const String _storeBase = AppConfig.wooStoreBaseUrl;
  static const Duration _timeout = AppConfig.shopTimeout;
  static const Duration _productsTtl = Duration(minutes: 5);
  static const Duration _productTtl = Duration(minutes: 10);
  static const Duration _searchIndexTtl = Duration(minutes: 10);
  static const Duration _staleListTtl = Duration(days: 3);
  static const Duration _staleProductTtl = Duration(days: 7);
  static const int _cacheSchemaVersion = 9;
  static const int _searchIndexSeedLimit = 160;
  static const Set<String> _excludedStoreCategorySlugs = {
    'servicio',
    'servicios',
    'service',
    'services',
    'amelia-servicios',
    'amelia-services',
    'reservas',
    'bookings',
  };
  static const List<String> _orderStatuses = [
    'pending',
    'on-hold',
    'processing',
    'completed',
    'cancelled',
    'failed',
    'refunded',
  ];

  static final http.Client _client = http.Client();
  static final Map<String, _CacheEntry<List<Map<String, dynamic>>>> _listCache =
      {};
  static final Map<int, _CacheEntry<Map<String, dynamic>>> _productCache = {};
  static final Set<String> _refreshingListKeys = {};
  static final Set<int> _refreshingProductIds = {};
  static Future<void>? _loadFuture;

  static Future<List<Map<String, dynamic>>> getProducts({
    int limit = 20,
    int page = 1,
    String search = '',
    String category = '',
    bool featured = false,
    bool inStock = false,
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    final key = [
      'products',
      limit,
      page,
      search.trim(),
      category.trim(),
      featured,
      inStock,
    ].join('|');

    final cached = !forceRefresh ? _listCache[key] : null;
    if (cached != null && cached.value.isNotEmpty) {
      if (!cached.isExpired) {
        return _cloneList(
          _normalizeProductList(
            _filterVisibleProducts(cached.value, search: search),
          ),
        );
      }
      if (cached.isUsable) {
        _refreshListInBackground(
          key,
          () => getProducts(
            limit: limit,
            page: page,
            search: search,
            category: category,
            featured: featured,
            inStock: inStock,
            forceRefresh: true,
          ),
        );
        return _cloneList(
          _normalizeProductList(
            _filterVisibleProducts(cached.value, search: search),
          ),
        );
      }
    }

    final products = _filterVisibleProducts(
      await _fetchProducts(
        limit: limit,
        page: page,
        search: search,
        category: category,
        featured: featured,
        inStock: inStock,
      ),
      search: search,
    );

    final expiresAt = DateTime.now().add(_productsTtl);
    _listCache[key] =
        _CacheEntry(products, expiresAt, expiresAt.add(_staleListTtl));
    _primeProductCache(products);
    await _persistCache();
    return _cloneList(products);
  }

  static Future<List<Map<String, dynamic>>> getCachedProducts({
    int limit = 20,
    int page = 1,
    String search = '',
    String category = '',
    bool featured = false,
    bool inStock = false,
  }) async {
    await _ensureLoaded();
    final key = [
      'products',
      limit,
      page,
      search.trim(),
      category.trim(),
      featured,
      inStock,
    ].join('|');
    final cached = _listCache[key];
    if (cached == null || !cached.isUsable) return <Map<String, dynamic>>[];
    return _cloneList(
      _normalizeProductList(
        _filterVisibleProducts(cached.value, search: search),
      ),
    );
  }

  static Future<Map<String, dynamic>> getProduct({
    required int productId,
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    final cached = !forceRefresh ? _productCache[productId] : null;
    if (cached != null) {
      final normalizedProduct = _normalizeProductPayload(cached.value);
      final hasWarehouseStock = _hasWarehouseStockPayload(normalizedProduct);
      if (hasWarehouseStock && !cached.isExpired) {
        if (!_isProductVisibleForSale(normalizedProduct, search: '')) {
          throw Exception('Este producto no esta visible en la tienda.');
        }
        return _cloneMap(normalizedProduct);
      }
      if (hasWarehouseStock && cached.isUsable) {
        if (!_isProductVisibleForSale(normalizedProduct, search: '')) {
          throw Exception('Este producto no esta visible en la tienda.');
        }
        _refreshProductInBackground(productId);
        return _cloneMap(normalizedProduct);
      }
    }

    final customUri = Uri.parse('$_customBase/shop/products/$productId');
    try {
      final data = await _getJson(customUri);
      final product = _asMap(data['data']);
      if (product.isNotEmpty) {
        final normalizedProduct = _normalizeProductPayload(product);
        if (!_isProductVisibleForSale(normalizedProduct, search: '')) {
          throw Exception('Este producto no esta visible en la tienda.');
        }
        _storeProduct(productId, normalizedProduct);
        return _cloneMap(normalizedProduct);
      }
    } catch (_) {
      // Fallback publico.
    }

    final response = await _client
        .get(
          Uri.parse('$_storeBase/products/$productId'),
          headers: _defaultHeaders(),
        )
        .timeout(_timeout);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('No pudimos cargar el producto.');
    }
    final product = _normalizeWooProduct(decoded);
    if (!_isProductVisibleForSale(product, search: '')) {
      throw Exception('Este producto no esta visible en la tienda.');
    }
    _storeProduct(productId, product);
    return _cloneMap(product);
  }

  static Future<List<Map<String, dynamic>>> getCategories({
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    const key = 'product_categories';
    final cached = !forceRefresh ? _listCache[key] : null;
    if (cached != null) {
      if (!cached.isExpired) {
        return _cloneList(cached.value);
      }
      if (cached.isUsable) {
        _refreshListInBackground(
          key,
          () => getCategories(forceRefresh: true),
        );
        return _cloneList(cached.value);
      }
    }

    try {
      final data = await _getJson(
        Uri.parse('$_customBase/shop/categories').replace(
          queryParameters: const {'limit': '100'},
        ),
      );
      final payload = _asMap(data['data']);
      final items = payload['items'] is List
          ? List<dynamic>.from(payload['items'])
          : <dynamic>[];
      if (payload.containsKey('items')) {
        final categories = items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where(_isVisibleCategory)
            .toList();
        _sortCategories(categories);

        final expiresAt = DateTime.now().add(_productsTtl);
        _listCache[key] = _CacheEntry(
          categories,
          expiresAt,
          expiresAt.add(_staleListTtl),
        );
        await _persistCache();
        return _cloneList(categories);
      }
    } catch (_) {
      // Fallback publico.
    }

    final response = await _client
        .get(
          Uri.parse('$_storeBase/products/categories'),
          headers: _defaultHeaders(),
        )
        .timeout(_timeout);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('No pudimos cargar las categorías.');
    }

    final categories = decoded
        .whereType<Map>()
        .map((item) {
          final map = _asMap(item);
          return {
            'id': _parseInt(map['id']) ?? 0,
            'name': (map['name'] ?? '').toString(),
            'slug': (map['slug'] ?? '').toString(),
            'count': _parseInt(map['count']) ?? 0,
            'image': _asMap(map['image']),
          };
        })
        .where(_isVisibleCategory)
        .toList();
    _sortCategories(categories);

    final expiresAt = DateTime.now().add(_productsTtl);
    _listCache[key] = _CacheEntry(
      categories,
      expiresAt,
      expiresAt.add(_staleListTtl),
    );
    await _persistCache();
    return _cloneList(categories);
  }

  static Future<List<Map<String, dynamic>>> getWarehouses({
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    const key = 'shop_warehouses';
    final cached = !forceRefresh ? _listCache[key] : null;
    if (cached != null) {
      if (!cached.isExpired) {
        return _cloneList(cached.value);
      }
      if (cached.isUsable) {
        _refreshListInBackground(
          key,
          () => getWarehouses(forceRefresh: true),
        );
        return _cloneList(cached.value);
      }
    }

    final data = await _getJson(Uri.parse('$_customBase/shop/warehouses'));
    final payload = _asMap(data['data']);
    final items = payload['items'] is List
        ? List<dynamic>.from(payload['items'])
        : <dynamic>[];

    final warehouses = items
        .whereType<Map>()
        .map((item) {
          final map = _asMap(item);
          return {
            'id': _parseInt(map['id']) ?? 0,
            'external_id': (map['external_id'] ?? map['externalId'] ?? '')
                .toString()
                .trim(),
            'code': (map['code'] ?? '').toString().trim(),
            'name': (map['name'] ?? 'Bodega').toString().trim(),
            'slug': (map['slug'] ?? '').toString().trim(),
            'address': (map['address_line_1'] ?? map['addressLine1'] ?? '')
                .toString()
                .trim(),
            'city': (map['city'] ?? '').toString().trim(),
            'state': (map['state'] ?? '').toString().trim(),
            'country': (map['country'] ?? '').toString().trim(),
            'postal_code': (map['postal_code'] ?? map['postalCode'] ?? '')
                .toString()
                .trim(),
            'is_default':
                _parseBool(map['is_default'] ?? map['isDefault']) ?? false,
          };
        })
        .where((item) => (item['id'] as int) > 0)
        .toList();

    final expiresAt = DateTime.now().add(_productsTtl);
    _listCache[key] = _CacheEntry(
      warehouses,
      expiresAt,
      expiresAt.add(_staleListTtl),
    );
    await _persistCache();
    return _cloneList(warehouses);
  }

  static Future<void> preloadSearchIndex({bool forceRefresh = false}) async {
    await getSearchIndex(forceRefresh: forceRefresh);
  }

  static Future<List<Map<String, dynamic>>> getSearchIndex({
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    const key = 'search_index';
    final cached = !forceRefresh ? _listCache[key] : null;
    if (cached != null) {
      if (!cached.isExpired) {
        return _cloneList(cached.value);
      }
      if (cached.isUsable) {
        _refreshListInBackground(
          key,
          () => getSearchIndex(forceRefresh: true),
        );
        return _cloneList(cached.value);
      }
    }

    final items = await getProducts(
      limit: _searchIndexSeedLimit,
      page: 1,
      forceRefresh: forceRefresh,
    );
    final expiresAt = DateTime.now().add(_searchIndexTtl);
    _listCache[key] =
        _CacheEntry(items, expiresAt, expiresAt.add(_staleListTtl));
    await _persistCache();
    return _cloneList(items);
  }

  static Future<List<Map<String, dynamic>>> searchProductsLocally(
    String query, {
    int limit = 20,
    String category = '',
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return <Map<String, dynamic>>[];

    final searchIndex = await getSearchIndex();
    final ranked = <_RankedProduct>[];

    for (final product in searchIndex) {
      final score = _score(product, normalizedQuery);
      if (score > 0) {
        ranked.add(_RankedProduct(product, score));
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    final normalizedCategory = category.trim();
    final products = ranked
        .map((e) => _cloneMap(e.product))
        .where(
          (product) => normalizedCategory.isEmpty
              ? true
              : _productMatchesCategoryValue(product, normalizedCategory),
        )
        .take(limit)
        .toList();
    return products;
  }

  static Future<List<Map<String, dynamic>>> searchCategoriesLocally(
    String query, {
    int limit = 6,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return <Map<String, dynamic>>[];

    final categories = await getCategories();
    final ranked = <_RankedCategory>[];

    for (final category in categories) {
      final score = _scoreCategory(category, normalizedQuery);
      if (score > 0) {
        ranked.add(_RankedCategory(category, score));
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked.take(limit).map((e) => _cloneMap(e.category)).toList();
  }

  static Future<List<Map<String, dynamic>>> getOrders({
    required String token,
    int limit = 20,
    int page = 1,
    String status = '',
    bool forceRefresh = false,
  }) async {
    final normalizedStatus = status.trim();
    if (normalizedStatus.isNotEmpty) {
      return _fetchOrders(
        token: token,
        limit: limit,
        page: page,
        status: normalizedStatus,
      );
    }

    final batches = await Future.wait([
      _fetchOrders(token: token, limit: limit, page: page),
      ..._orderStatuses.map(
        (itemStatus) => _fetchOrders(
          token: token,
          limit: limit,
          page: page,
          status: itemStatus,
        ),
      ),
    ]);

    return _mergeAndSortOrders(batches.expand((batch) => batch).toList())
        .take(limit)
        .toList();
  }

  static List<Map<String, dynamic>> mergeOrders(
    List<Map<String, dynamic>> orders,
  ) {
    return _mergeAndSortOrders(
      orders
          .map((order) => _normalizeOrder(Map<String, dynamic>.from(order)))
          .toList(),
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchOrders({
    required String token,
    required int limit,
    required int page,
    String status = '',
  }) async {
    final uri = Uri.parse('$_customBase/shop/orders').replace(
      queryParameters: {
        'limit': limit.toString(),
        'page': page.toString(),
        if (status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    final data = await _getJson(uri, headers: _authHeaders(token));
    final items = _extractOrderItems(data);
    return items
        .whereType<Map>()
        .map((item) => _normalizeOrder(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<ShopPaymentMethod>> getPaymentMethods({
    bool forceRefresh = false,
  }) async {
    await _ensureLoaded();
    const key = 'payment_methods';
    final cached = !forceRefresh ? _listCache[key] : null;
    if (cached != null && cached.isUsable) {
      if (cached.isExpired) {
        _refreshListInBackground(
          key,
          () => getPaymentMethods(forceRefresh: true),
        );
      }
      return cached.value
          .map(ShopPaymentMethod.fromJson)
          .where((method) => method.enabled)
          .toList();
    }

    try {
      final data = await _getJson(
        Uri.parse('$_customBase/shop/payment-methods'),
      );
      final items = _extractPaymentMethodItems(data);
      final methods = items
          .whereType<Map>()
          .map((item) => ShopPaymentMethod.fromJson(_asMap(item)))
          .where((method) => method.enabled)
          .toList();

      if (methods.isNotEmpty) {
        final expiresAt = DateTime.now().add(_productsTtl);
        _listCache[key] = _CacheEntry(
          methods.map((method) => method.toJson()).toList(),
          expiresAt,
          expiresAt.add(_staleListTtl),
        );
        await _persistCache();
        return methods;
      }
    } catch (_) {
      // Si el plugin remoto aún no expone métodos, usamos un fallback seguro.
    }

    return const [ShopPaymentMethod.bankTransfer];
  }

  static Future<Map<String, dynamic>> createOrder({
    required String token,
    required List<Map<String, dynamic>> lineItems,
    int? customerId,
    int? wooCustomerId,
    String firstName = '',
    String lastName = '',
    String company = '',
    String email = '',
    String phone = '',
    String address1 = '',
    String address2 = '',
    String city = '',
    String state = '',
    String postcode = '',
    String country = 'EC',
    String customerNote = '',
    String billingDocumentType = '',
    String billingDocumentNumber = '',
    String paymentMethod = '',
    String paymentTitle = '',
    double shippingTotal = 0,
    double subtotal = 0,
    double taxTotal = 0,
    double orderTotal = 0,
    String shippingMethodId = 'flat_rate',
    String shippingMethodTitle = 'Envío local',
    String fulfillmentMethod = 'delivery',
    int pickupLocationId = 0,
    String pickupLocationName = '',
    String pickupWarehouseExternalId = '',
    bool pricesIncludeTax = false,
    String currency = 'USD',
    String status = 'pending',
    bool setPaid = false,
    double redeemPoints = 0,
    double redeemAmount = 0,
  }) async {
    final billing = _removeEmpty({
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'company': company.trim(),
      'address_1': address1.trim(),
      'address_2': address2.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'postcode': postcode.trim(),
      'country': country.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
    });

    final shipping = _removeEmpty({
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'company': company.trim(),
      'address_1': address1.trim(),
      'address_2': address2.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'postcode': postcode.trim(),
      'country': country.trim(),
    });

    final normalizedLineItems =
        lineItems.map(_normalizeLineItemPayload).toList();
    final selectedCustomerId = _firstPositiveInt([wooCustomerId, customerId]);
    final formattedShipping = _formatAmount(shippingTotal);
    final formattedSubtotal = _formatAmount(subtotal);
    final formattedTaxTotal = _formatAmount(taxTotal);
    final formattedTotal = _formatAmount(orderTotal);
    final normalizedShippingMethodId = shippingMethodId.trim().isNotEmpty
        ? shippingMethodId.trim()
        : 'flat_rate';
    final normalizedShippingMethodTitle = shippingMethodTitle.trim().isNotEmpty
        ? shippingMethodTitle.trim()
        : 'Envío local';
    final normalizedFulfillmentMethod = fulfillmentMethod.trim().isNotEmpty
        ? fulfillmentMethod.trim()
        : 'delivery';
    final normalizedPickupLocationName = pickupLocationName.trim();
    final normalizedPickupWarehouseExternalId =
        pickupWarehouseExternalId.trim();
    final normalizedDocumentType = billingDocumentType.trim().toLowerCase();
    final normalizedDocumentNumber = billingDocumentNumber.trim();

    final body = _removeNulls({
      if (selectedCustomerId != null) 'customer_id': selectedCustomerId,
      if (wooCustomerId != null && wooCustomerId > 0)
        'woo_customer_id': wooCustomerId,
      'currency': currency,
      'status': status,
      'set_paid': setPaid,
      if (redeemPoints > 0) 'redeem_points': _amountNumber(redeemPoints),
      if (redeemAmount > 0) 'redeem_amount': _amountNumber(redeemAmount),
      'payment_method': paymentMethod,
      'payment_method_title': paymentTitle,
      'payment_title': paymentTitle,
      'customer_note': customerNote,
      'billing': billing,
      'shipping': shipping,
      'line_items': normalizedLineItems,
      'shipping_lines': [
        {
          'method_id': normalizedShippingMethodId,
          'method_title': normalizedShippingMethodTitle,
          'total': formattedShipping,
        }
      ],
      'meta_data': [
        {'key': '_habito_app_order', 'value': '1'},
        {'key': '_habito_app_subtotal', 'value': formattedSubtotal},
        {'key': '_habito_app_tax_total', 'value': formattedTaxTotal},
        {'key': '_habito_app_shipping_total', 'value': formattedShipping},
        {'key': '_habito_app_total', 'value': formattedTotal},
        if (redeemPoints > 0)
          {
            'key': '_habito_app_redeem_points',
            'value': _amountNumber(redeemPoints),
          },
        if (redeemAmount > 0)
          {
            'key': '_habito_app_redeem_amount',
            'value': _amountNumber(redeemAmount),
          },
        {
          'key': '_habito_app_prices_include_tax',
          'value': pricesIncludeTax ? '1' : '0',
        },
        {
          'key': '_habito_app_fulfillment_method',
          'value': normalizedFulfillmentMethod,
        },
        if (normalizedDocumentType.isNotEmpty)
          {
            'key': '_habito_billing_document_type',
            'value': normalizedDocumentType,
          },
        if (normalizedDocumentNumber.isNotEmpty)
          {
            'key': '_habito_billing_document_number',
            'value': normalizedDocumentNumber,
          },
        if (pickupLocationId > 0)
          {'key': '_habito_app_pickup_location_id', 'value': pickupLocationId},
        if (normalizedPickupLocationName.isNotEmpty)
          {
            'key': '_habito_app_pickup_location_name',
            'value': normalizedPickupLocationName,
          },
        if (normalizedPickupWarehouseExternalId.isNotEmpty)
          {
            'key': '_ultimatepos_pickup_warehouse_external_id',
            'value': normalizedPickupWarehouseExternalId,
          },
        {
          'key': '_ultimatepos_fulfillment_type',
          'value': normalizedFulfillmentMethod,
        },
      ],

      // Campos legacy que el endpoint Hábito actual ya entiende.
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'email': email,
      'phone': phone,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      if (normalizedDocumentType.isNotEmpty)
        'billing_document_type': normalizedDocumentType,
      if (normalizedDocumentNumber.isNotEmpty)
        'billing_document_number': normalizedDocumentNumber,
      'shipping_total': shippingTotal,
      'fulfillment_method': normalizedFulfillmentMethod,
      if (pickupLocationId > 0) 'pickup_location_id': pickupLocationId,
      if (normalizedPickupLocationName.isNotEmpty)
        'pickup_location_name': normalizedPickupLocationName,
      if (normalizedPickupWarehouseExternalId.isNotEmpty)
        'pickup_warehouse_external_id': normalizedPickupWarehouseExternalId,
      'app_totals': {
        'subtotal': formattedSubtotal,
        'tax_total': formattedTaxTotal,
        'shipping_total': formattedShipping,
        'total': formattedTotal,
        'prices_include_tax': pricesIncludeTax,
        'fulfillment_method': normalizedFulfillmentMethod,
        if (redeemPoints > 0) 'redeem_points': _amountNumber(redeemPoints),
        if (redeemAmount > 0) 'redeem_amount': _amountNumber(redeemAmount),
      },
    });

    final response = await _retryingPost(
      Uri.parse('$_customBase/shop/orders'),
      headers: _jsonAuthHeaders(token),
      body: jsonEncode(body),
      idempotencyKey: newIdempotencyKey(prefix: 'habito-shop-order'),
      timeoutMessage:
          'No pudimos confirmar el pedido a tiempo. Revisa tus pedidos antes de intentarlo nuevamente.',
      connectionMessage:
          'No pudimos conectar para crear el pedido. Revisa tu internet e intenta nuevamente.',
    );

    final data = _decodeMap(response);
    if (data['success'] != true) {
      throw Exception(_extractMessage(data));
    }
    return _normalizeOrder(_extractCreatedOrder(data));
  }

  static Future<ShopCartValidationResult> validateCart({
    required String token,
    required List<Map<String, dynamic>> lineItems,
    required String fulfillmentMethod,
    int pickupLocationId = 0,
    String pickupLocationName = '',
    String pickupWarehouseExternalId = '',
    double subtotal = 0,
    double taxTotal = 0,
    double shippingTotal = 0,
    double orderTotal = 0,
    bool pricesIncludeTax = false,
  }) async {
    final normalizedLineItems =
        lineItems.map(_normalizeLineItemPayload).toList();
    final body = _removeNulls({
      'line_items': normalizedLineItems,
      'fulfillment_method': fulfillmentMethod,
      if (pickupLocationId > 0) 'pickup_location_id': pickupLocationId,
      if (pickupLocationName.trim().isNotEmpty)
        'pickup_location_name': pickupLocationName.trim(),
      if (pickupWarehouseExternalId.trim().isNotEmpty)
        'pickup_warehouse_external_id': pickupWarehouseExternalId.trim(),
      'app_totals': {
        'subtotal': _formatAmount(subtotal),
        'tax_total': _formatAmount(taxTotal),
        'shipping_total': _formatAmount(shippingTotal),
        'total': _formatAmount(orderTotal),
        'prices_include_tax': pricesIncludeTax,
      },
    });

    final response = await _retryingPost(
      Uri.parse('$_customBase/shop/cart/validate'),
      headers: _jsonAuthHeaders(token),
      body: jsonEncode(body),
      attempts: 1,
      idempotencyKey: newIdempotencyKey(prefix: 'habito-cart-validate'),
      timeoutMessage:
          'No pudimos validar tu carrito a tiempo. Revisa tu conexión e intenta nuevamente.',
      connectionMessage:
          'No pudimos conectar para validar el carrito. Revisa tu internet e intenta nuevamente.',
    );

    if (response.statusCode == 404) {
      return ShopCartValidationResult.unavailable();
    }

    final data = _decodeMap(response);
    if (data['success'] != true) {
      throw Exception(_extractMessage(data));
    }

    return ShopCartValidationResult.fromJson(data);
  }

  static Future<Map<String, dynamic>> uploadPaymentProof({
    required String token,
    required int orderId,
    required String filePath,
  }) async {
    final uri = Uri.parse('$_customBase/shop/orders/$orderId/payment-proof');
    final response = await _retryingMultipartPost(
      uri,
      headers: _authHeaders(token),
      fileField: 'proof',
      filePath: filePath,
      idempotencyKey: newIdempotencyKey(prefix: 'habito-payment-proof'),
      timeoutMessage:
          'No pudimos confirmar la carga del comprobante a tiempo. Revisa el pedido antes de intentarlo nuevamente.',
      connectionMessage:
          'No pudimos conectar para subir el comprobante. Revisa tu internet e intenta nuevamente.',
    );
    final data = _decodeMap(response);

    if (data['success'] != true) {
      throw Exception(_extractMessage(data));
    }

    return _normalizeOrder(_extractCreatedOrder(data));
  }

  static Future<List<Map<String, dynamic>>> _fetchProducts({
    required int limit,
    required int page,
    required String search,
    required String category,
    required bool featured,
    required bool inStock,
  }) async {
    final customUri = Uri.parse('$_customBase/shop/products').replace(
      queryParameters: {
        'limit': limit.toString(),
        'page': page.toString(),
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (category.trim().isNotEmpty) 'category': category.trim(),
        if (featured) 'featured': '1',
        if (inStock) 'in_stock': '1',
      },
    );

    try {
      final data = await _getJson(customUri);
      final payload = _asMap(data['data']);
      final items = payload['items'] is List
          ? List<dynamic>.from(payload['items'])
          : <dynamic>[];
      if (items.isNotEmpty) {
        return items
            .whereType<Map>()
            .map((item) => _normalizeProductPayload(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }
    } catch (_) {
      // Fallback publico.
    }

    final storeUri = Uri.parse('$_storeBase/products').replace(
      queryParameters: {
        'per_page': limit.toString(),
        'page': page.toString(),
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (category.trim().isNotEmpty) 'category': category.trim(),
        if (featured) 'featured': 'true',
        'stock_status[0]': 'instock',
        if (!inStock) 'stock_status[1]': 'outofstock',
        if (!inStock) 'stock_status[2]': 'onbackorder',
      },
    );

    final response = await _client
        .get(storeUri, headers: _defaultHeaders())
        .timeout(_timeout);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('No pudimos cargar la tienda.');
    }

    return decoded
        .whereType<Map>()
        .map((item) => _normalizeWooProduct(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await _client
        .get(uri, headers: headers ?? _defaultHeaders())
        .timeout(_timeout);
    final data = _decodeMap(response);
    if (data['success'] != true) {
      throw Exception(_extractMessage(data));
    }
    return data;
  }

  static Future<http.Response> _retryingPost(
    Uri uri, {
    required Map<String, String> headers,
    Object? body,
    Duration timeout = _timeout,
    int attempts = 3,
    String? idempotencyKey,
    String timeoutMessage =
        'La operacion esta tomando mas tiempo de lo esperado. Revisa el estado antes de intentarlo nuevamente.',
    String connectionMessage =
        'No pudimos conectar con la tienda. Revisa tu internet e intenta nuevamente.',
  }) async {
    Object? lastError;
    http.Response? lastResponse;
    final requestHeaders = _withIdempotencyHeaders(
      headers,
      idempotencyKey ?? newIdempotencyKey(prefix: 'habito-shop'),
    );

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final response = await _client
            .post(uri, headers: requestHeaders, body: body)
            .timeout(timeout);

        if (!_shouldRetryPostResponse(response.statusCode) ||
            attempt == attempts - 1) {
          return response;
        }

        lastResponse = response;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on HandshakeException catch (e) {
        lastError = e;
      }

      if (attempt < attempts - 1) {
        await Future<void>.delayed(_postBackoffDelay(attempt));
      }
    }

    if (lastResponse != null) return lastResponse;
    if (lastError is TimeoutException) throw Exception(timeoutMessage);
    throw Exception(connectionMessage);
  }

  static Future<http.Response> _retryingMultipartPost(
    Uri uri, {
    required Map<String, String> headers,
    required String fileField,
    required String filePath,
    Duration timeout = _timeout,
    int attempts = 3,
    String? idempotencyKey,
    String timeoutMessage =
        'La operacion esta tomando mas tiempo de lo esperado. Revisa el estado antes de intentarlo nuevamente.',
    String connectionMessage =
        'No pudimos conectar con la tienda. Revisa tu internet e intenta nuevamente.',
  }) async {
    Object? lastError;
    http.Response? lastResponse;
    final requestHeaders = _withIdempotencyHeaders(
      headers,
      idempotencyKey ?? newIdempotencyKey(prefix: 'habito-shop-upload'),
    );

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(requestHeaders)
          ..files.add(await http.MultipartFile.fromPath(fileField, filePath));

        final streamed = await _client.send(request).timeout(timeout);
        final response = await http.Response.fromStream(streamed);

        if (!_shouldRetryPostResponse(response.statusCode) ||
            attempt == attempts - 1) {
          return response;
        }

        lastResponse = response;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on HandshakeException catch (e) {
        lastError = e;
      }

      if (attempt < attempts - 1) {
        await Future<void>.delayed(_postBackoffDelay(attempt));
      }
    }

    if (lastResponse != null) return lastResponse;
    if (lastError is TimeoutException) throw Exception(timeoutMessage);
    throw Exception(connectionMessage);
  }

  static Map<String, dynamic> _normalizeWooProduct(
    Map<String, dynamic> product,
  ) {
    final prices = _asMap(product['prices']);
    final minorUnit = int.tryParse(
          prices['currency_minor_unit']?.toString() ?? '',
        ) ??
        2;

    String normalizePrice(dynamic raw) {
      final cents = int.tryParse(raw?.toString() ?? '');
      if (cents == null) return '0';
      final base = minorUnit <= 0 ? 1 : (10).pow(minorUnit).toInt();
      return (cents / base).toStringAsFixed(minorUnit);
    }

    final images = product['images'] is List
        ? List<dynamic>.from(product['images'])
        : <dynamic>[];
    final categories = product['categories'] is List
        ? List<dynamic>.from(product['categories'])
        : <dynamic>[];

    return _normalizeProductPayload({
      'id': product['id'],
      'name': product['name'],
      'slug': product['slug'],
      'description': product['description'],
      'short_description': product['short_description'],
      'price': normalizePrice(prices['price']),
      'regular_price': normalizePrice(prices['regular_price']),
      'sale_price': normalizePrice(prices['sale_price']),
      'price_including_tax': _priceIncludingTaxFromProduct(
        product,
        normalizePrice(prices['price']),
        explicitValues: [
          product['price_including_tax'],
          product['priceIncludingTax'],
          product['display_price'],
        ],
      ),
      'regular_price_including_tax': _priceIncludingTaxFromProduct(
        product,
        normalizePrice(prices['regular_price']),
        explicitValues: [
          product['regular_price_including_tax'],
          product['regularPriceIncludingTax'],
        ],
      ),
      'sale_price_including_tax': _priceIncludingTaxFromProduct(
        product,
        normalizePrice(prices['sale_price']),
        explicitValues: [
          product['sale_price_including_tax'],
          product['salePriceIncludingTax'],
        ],
      ),
      'display_price': _priceIncludingTaxFromProduct(
        product,
        normalizePrice(prices['price']),
        explicitValues: [
          product['display_price'],
          product['price_including_tax'],
          product['priceIncludingTax'],
        ],
      ),
      'display_prices_include_tax': true,
      'in_stock': product['is_in_stock'] == true,
      'status': product['status']?.toString(),
      'catalog_visibility':
          product['catalog_visibility']?.toString() ?? 'visible',
      'visible_for_sale': _isProductVisibleForSale(product, search: ''),
      'purchasable': _parseBool(
            product['purchasable'] ?? product['is_purchasable'],
          ) ??
          true,
      'tax_status': product['tax_status'],
      'tax_class': product['tax_class'],
      'taxable': _parseBool(product['taxable'] ?? product['is_taxable']) ??
          (product['tax_status']?.toString().toLowerCase() == 'taxable'),
      'prices_include_tax': _parseBool(
            product['prices_include_tax'] ?? product['price_includes_tax'],
          ) ??
          false,
      'iva_type': _normalizeIvaType(product),
      'iva_label': _normalizeIvaLabel(product),
      'iva_rate_percent': _normalizeIvaRate(product),
      'tax_rate_percent': _normalizeIvaRate(product),
      'tax_rates': product['tax_rates'] is List
          ? List<dynamic>.from(product['tax_rates'])
          : <dynamic>[],
      'sku': product['sku'],
      'images': images.map((image) {
        final map = _asMap(image);
        return {
          'id': map['id'],
          'src': map['src'] ?? map['thumbnail'],
        };
      }).toList(),
      'categories': categories.map((category) {
        final map = _asMap(category);
        return {
          'id': map['id'],
          'name': map['name'],
          'slug': map['slug'],
        };
      }).toList(),
    });
  }

  static Map<String, dynamic> _normalizeProductPayload(
    Map<String, dynamic> product,
  ) {
    final normalized = Map<String, dynamic>.from(product);
    final price = _firstNonEmpty([
      normalized['price']?.toString(),
      normalized['regular_price']?.toString(),
      normalized['regularPrice']?.toString(),
    ]);
    final regularPrice = _firstNonEmpty([
      normalized['regular_price']?.toString(),
      normalized['regularPrice']?.toString(),
      price,
    ]);
    final salePrice = _firstNonEmpty([
      normalized['sale_price']?.toString(),
      normalized['salePrice']?.toString(),
    ]);

    normalized['price_including_tax'] = _priceIncludingTaxFromProduct(
      normalized,
      price,
      explicitValues: [
        normalized['price_including_tax'],
        normalized['priceIncludingTax'],
        normalized['display_price'],
      ],
    );
    normalized['regular_price_including_tax'] = _priceIncludingTaxFromProduct(
      normalized,
      regularPrice,
      explicitValues: [
        normalized['regular_price_including_tax'],
        normalized['regularPriceIncludingTax'],
      ],
    );
    if (salePrice.isNotEmpty) {
      normalized['sale_price_including_tax'] = _priceIncludingTaxFromProduct(
        normalized,
        salePrice,
        explicitValues: [
          normalized['sale_price_including_tax'],
          normalized['salePriceIncludingTax'],
        ],
      );
    }
    normalized['display_price'] = _priceIncludingTaxFromProduct(
      normalized,
      price,
      explicitValues: [
        normalized['display_price'],
        normalized['price_including_tax'],
        normalized['priceIncludingTax'],
      ],
    );
    normalized['display_prices_include_tax'] = true;
    if (_hasWarehouseStockPayload(normalized)) {
      normalized['warehouse_stock'] = _normalizeWarehouseStockList(
        normalized['warehouse_stock'] ?? normalized['warehouseStock'],
      );
      normalized['warehouse_stock_enabled'] = _parseBool(
            normalized['warehouse_stock_enabled'] ??
                normalized['warehouseStockEnabled'],
          ) ??
          normalized['warehouse_stock'] is List;
    }
    normalized['iva_rate_percent'] = _normalizeIvaRate(normalized);
    normalized['tax_rate_percent'] = _normalizeIvaRate(normalized);
    normalized['iva_type'] = _normalizeIvaType(normalized);
    normalized['iva_label'] = _normalizeIvaLabel(normalized);
    return normalized;
  }

  static bool _isVisibleCategory(Map<String, dynamic> item) {
    final id = _parseInt(item['id']) ?? 0;
    final name = (item['name'] ?? '').toString().trim();
    final slug = (item['slug'] ?? '').toString().trim().toLowerCase();
    return id > 0 &&
        name.isNotEmpty &&
        !_isExcludedStoreCategorySlug(slug) &&
        slug != 'uncategorized' &&
        slug != 'sin-categorizar';
  }

  static void _sortCategories(List<Map<String, dynamic>> categories) {
    categories.sort((a, b) {
      final countA = _parseInt(a['count']) ?? 0;
      final countB = _parseInt(b['count']) ?? 0;
      final countCompare = countB.compareTo(countA);
      if (countCompare != 0) return countCompare;
      return (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          );
    });
  }

  static List<Map<String, dynamic>> _filterVisibleProducts(
    List<Map<String, dynamic>> products, {
    required String search,
  }) {
    return products
        .where((product) => _isProductVisibleForSale(product, search: search))
        .toList();
  }

  static List<Map<String, dynamic>> _normalizeProductList(
    List<Map<String, dynamic>> products,
  ) {
    return products.map(_normalizeProductPayload).toList();
  }

  static bool _isProductVisibleForSale(
    Map<String, dynamic> product, {
    required String search,
  }) {
    if (_hasExcludedStoreCategory(product)) return false;

    final explicit = _parseBool(
      product['visible_for_sale'] ??
          product['visibleForSale'] ??
          product['is_visible'] ??
          product['isVisible'],
    );
    if (explicit == false) return false;

    final status = (product['status'] ?? '').toString().toLowerCase().trim();
    if (status.isNotEmpty && status != 'publish' && status != 'published') {
      return false;
    }

    final visibility = (product['catalog_visibility'] ??
            product['catalogVisibility'] ??
            product['visibility'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();

    if (visibility == 'hidden' || visibility == 'none') return false;
    if (search.trim().isEmpty && visibility == 'search') return false;
    if (search.trim().isNotEmpty && visibility == 'catalog') return false;

    return true;
  }

  static bool _hasExcludedStoreCategory(Map<String, dynamic> product) {
    final categories = product['categories'] is List
        ? List<dynamic>.from(product['categories'])
        : const <dynamic>[];

    for (final item in categories) {
      final category = _asMap(item);
      final slug = (category['slug'] ?? '').toString().trim().toLowerCase();
      if (_isExcludedStoreCategorySlug(slug)) {
        return true;
      }
    }

    return false;
  }

  static bool _hasWarehouseStockPayload(Map<String, dynamic> product) {
    return product.containsKey('warehouse_stock') ||
        product.containsKey('warehouseStock');
  }

  static List<Map<String, dynamic>> _normalizeWarehouseStockList(
      dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value.whereType<Map>().map((item) {
      final map = _asMap(item);
      final quantity = _parseDouble(
        map['quantity'] ??
            map['stock_quantity'] ??
            map['stockQuantity'] ??
            map['qty'],
      );

      return {
        'id': _parseInt(map['id']) ?? 0,
        'external_id':
            (map['external_id'] ?? map['externalId'] ?? '').toString(),
        'code': (map['code'] ?? '').toString(),
        'name': (map['name'] ?? '').toString(),
        'slug': (map['slug'] ?? '').toString(),
        'address_line_1':
            (map['address_line_1'] ?? map['addressLine1'] ?? '').toString(),
        'city': (map['city'] ?? '').toString(),
        'state': (map['state'] ?? '').toString(),
        'country': (map['country'] ?? '').toString(),
        'postal_code':
            (map['postal_code'] ?? map['postalCode'] ?? '').toString(),
        'quantity': quantity,
        'in_stock':
            _parseBool(map['in_stock'] ?? map['inStock']) ?? quantity > 0,
        'is_default':
            _parseBool(map['is_default'] ?? map['isDefault']) ?? false,
      };
    }).toList();
  }

  static bool _isExcludedStoreCategorySlug(String slug) {
    return _excludedStoreCategorySlugs.contains(slug.trim().toLowerCase());
  }

  static String _normalizeIvaType(Map<String, dynamic> product) {
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

    final rate = _normalizeIvaRate(product);
    if (rate > 0) return (rate - 15).abs() < 0.01 ? 'iva_15' : 'iva_other';

    final taxable = _parseBool(product['taxable'] ?? product['is_taxable']);
    final taxStatus =
        (product['tax_status'] ?? product['taxStatus'] ?? '').toString();
    final taxClass = (product['tax_class'] ?? product['taxClass'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if ((taxable == true || taxStatus.toLowerCase().trim() == 'taxable') &&
        (taxClass.isEmpty || taxClass == 'standard')) {
      return 'iva_15';
    }
    if (taxable == true || taxStatus.toLowerCase().trim() == 'taxable') {
      return 'iva_0';
    }

    return 'no_iva';
  }

  static String _normalizeIvaLabel(Map<String, dynamic> product) {
    final explicit =
        (product['iva_label'] ?? product['ivaLabel'] ?? product['tax_label'])
            ?.toString()
            .trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final type = _normalizeIvaType(product);
    if (type == 'iva_15') return 'IVA 15%';
    if (type == 'iva_0') return 'IVA 0%';
    if (type == 'iva_other') {
      final rate = _normalizeIvaRate(product);
      return rate > 0 ? 'IVA ${rate.toStringAsFixed(2)}%' : 'IVA';
    }
    return 'No grava IVA';
  }

  static String _priceIncludingTaxFromProduct(
    Map<String, dynamic> product,
    String rawPrice, {
    List<dynamic> explicitValues = const [],
  }) {
    final explicit = _firstNonEmpty(
      explicitValues.map((value) => value?.toString()).toList(),
    );
    final price = _parseDouble(rawPrice);
    final rate = _normalizeIvaRate(product);
    final pricesIncludeTax = _parseBool(
          product['prices_include_tax'] ?? product['price_includes_tax'],
        ) ??
        false;
    final displayPriceIncludesTax = _parseBool(
          product['display_prices_include_tax'] ??
              product['displayPricesIncludeTax'] ??
              product['price_including_tax_is_display'],
        ) ??
        false;

    if (explicit.isNotEmpty) {
      final explicitPrice = _parseDouble(explicit);
      if (displayPriceIncludesTax && explicitPrice > 0) {
        return _formatCommercialDisplayPrice(explicitPrice);
      }
      final shouldRecalculate = price > 0 &&
          explicitPrice > 0 &&
          explicitPrice <= price &&
          !pricesIncludeTax &&
          rate > 0;
      if (!shouldRecalculate) return explicit;
    }

    if (price <= 0 || pricesIncludeTax || rate <= 0) {
      final fallback = explicit.isNotEmpty ? explicit : rawPrice;
      final fallbackPrice = _parseDouble(fallback);
      return fallbackPrice > 0
          ? _formatCommercialDisplayPrice(fallbackPrice)
          : fallback;
    }
    return _formatCommercialDisplayPrice(price * (1 + (rate / 100)));
  }

  static String _formatCommercialDisplayPrice(double price) {
    final nearestWhole = price.roundToDouble();
    if (nearestWhole > price && (nearestWhole - price).abs() <= 0.011) {
      return nearestWhole.toStringAsFixed(2);
    }
    return price.toStringAsFixed(2);
  }

  static double _normalizeIvaRate(Map<String, dynamic> product) {
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

    final taxable = _parseBool(product['taxable'] ?? product['is_taxable']);
    final taxStatus =
        (product['tax_status'] ?? product['taxStatus'] ?? '').toString();
    final taxClass = (product['tax_class'] ?? product['taxClass'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if ((taxable == true || taxStatus.toLowerCase().trim() == 'taxable') &&
        (taxClass.isEmpty || taxClass == 'standard')) {
      return 15;
    }

    return 0;
  }

  static List<dynamic> _extractOrderItems(Map<String, dynamic> data) {
    final rootCandidates = [
      data['orders'],
      data['items'],
      data['data'],
    ];

    for (final candidate in rootCandidates) {
      if (candidate is List) return List<dynamic>.from(candidate);
      final map = _asMap(candidate);
      final nestedCandidates = [
        map['items'],
        map['orders'],
        map['data'],
      ];
      for (final nested in nestedCandidates) {
        if (nested is List) return List<dynamic>.from(nested);
      }
    }

    return <dynamic>[];
  }

  static List<dynamic> _extractPaymentMethodItems(Map<String, dynamic> data) {
    final rootCandidates = [
      data['payment_methods'],
      data['methods'],
      data['items'],
      data['data'],
    ];

    for (final candidate in rootCandidates) {
      if (candidate is List) return List<dynamic>.from(candidate);
      final map = _asMap(candidate);
      final nestedCandidates = [
        map['payment_methods'],
        map['methods'],
        map['items'],
        map['data'],
      ];
      for (final nested in nestedCandidates) {
        if (nested is List) return List<dynamic>.from(nested);
      }
    }

    return <dynamic>[];
  }

  static Map<String, dynamic> _extractCreatedOrder(Map<String, dynamic> data) {
    final payload = _asMap(data['data']);
    for (final candidate in [
      payload['order'],
      payload['item'],
      payload['data'],
      payload,
      data['order'],
      data,
    ]) {
      final map = _asMap(candidate);
      if (map.isNotEmpty &&
          (map['id'] != null ||
              map['number'] != null ||
              map['status'] != null)) {
        return map;
      }
    }

    return payload;
  }

  static Map<String, dynamic> _normalizeOrder(Map<String, dynamic> order) {
    final billing = _asMap(order['billing']);
    final shipping = _asMap(order['shipping']);
    final metaData = order['meta_data'] is List
        ? List<dynamic>.from(order['meta_data'])
        : order['metaData'] is List
            ? List<dynamic>.from(order['metaData'])
            : <dynamic>[];
    final metaLookup = _flattenMetaData(metaData);
    final shippingLines = order['shipping_lines'] is List
        ? List<dynamic>.from(order['shipping_lines'])
        : <dynamic>[];
    final lineItems = order['line_items'] is List
        ? List<dynamic>.from(order['line_items'])
        : order['items'] is List
            ? List<dynamic>.from(order['items'])
            : <dynamic>[];
    final rawStatus = _firstNonEmpty([
      order['status']?.toString(),
      order['order_status']?.toString(),
    ]);
    final normalizedStatus = _normalizeOrderStatus(rawStatus);
    final rawDate = _firstNonEmpty([
      order['date_created']?.toString(),
      order['dateCreated']?.toString(),
      order['created_at']?.toString(),
    ]);
    final orderDate = _parseOrderDate(rawDate);
    final fulfillmentMethod = _normalizeFulfillmentMethod(
      _firstNonEmpty([
        order['fulfillment_method']?.toString(),
        order['fulfillmentMethod']?.toString(),
        order['app_fulfillment_method']?.toString(),
        metaLookup['_habito_app_fulfillment_method'],
      ]),
    );
    final pickupLocationId =
        _parseInt(order['pickup_location_id'] ?? order['pickupLocationId']) ??
            _parseInt(metaLookup['_habito_app_pickup_location_id']) ??
            0;
    final pickupLocationName = _firstNonEmpty([
      order['pickup_location_name']?.toString(),
      order['pickupLocationName']?.toString(),
      metaLookup['_habito_app_pickup_location_name'],
    ]);

    final normalizedLineItems = lineItems.whereType<Map>().map((line) {
      final map = _asMap(line);
      return {
        ...map,
        'name': _firstNonEmpty([
          map['name']?.toString(),
          map['product_name']?.toString(),
        ]),
        'quantity': _parseInt(map['quantity']) ?? 1,
        'total': _firstNonEmpty([
          map['total']?.toString(),
          map['subtotal']?.toString(),
          map['price']?.toString(),
        ]),
        'subtotal_tax': _firstNonEmpty([
          map['subtotal_tax']?.toString(),
          map['subtotalTax']?.toString(),
        ]),
        'total_tax': _firstNonEmpty([
          map['total_tax']?.toString(),
          map['totalTax']?.toString(),
        ]),
      };
    }).toList();

    return {
      ...order,
      'id': _parseInt(order['id']) ?? 0,
      'number': _firstNonEmpty([
        order['number']?.toString(),
        order['order_number']?.toString(),
        order['id']?.toString(),
      ]),
      'status': normalizedStatus,
      'status_raw': rawStatus,
      'status_normalized': normalizedStatus,
      'status_display': _orderStatusDisplay(
        normalizedStatus,
        fallback: rawStatus,
      ),
      'status_description': _orderStatusDescription(normalizedStatus),
      'status_lifecycle': _orderStatusLifecycle(normalizedStatus),
      'is_closed': _isClosedOrderStatus(normalizedStatus),
      'date_created': rawDate,
      'date_created_display': _formatOrderDate(rawDate),
      'date_created_epoch': orderDate?.millisecondsSinceEpoch ?? 0,
      'customer_id':
          _parseInt(order['customer_id'] ?? order['customerId']) ?? 0,
      'billing': billing,
      'shipping': shipping,
      'meta_data': metaData,
      'line_items': normalizedLineItems,
      'shipping_lines': shippingLines,
      'tax_lines': order['tax_lines'] is List
          ? List<dynamic>.from(order['tax_lines'])
          : <dynamic>[],
      'shipping_total': _firstNonEmpty([
        order['shipping_total']?.toString(),
        order['shippingTotal']?.toString(),
        _sumShippingLines(shippingLines),
      ]),
      'total_tax': _firstNonEmpty([
        order['total_tax']?.toString(),
        order['totalTax']?.toString(),
      ]),
      'payment_title': _firstNonEmpty([
        order['payment_title']?.toString(),
        order['payment_method_title']?.toString(),
        order['paymentMethodTitle']?.toString(),
      ]),
      'payment_method': _firstNonEmpty([
        order['payment_method']?.toString(),
        order['paymentMethod']?.toString(),
      ]),
      'payment_proof': _asMap(order['payment_proof'] ?? order['paymentProof']),
      'fulfillment_method': fulfillmentMethod,
      'fulfillment_display':
          fulfillmentMethod == 'pickup' ? 'Retiro en tienda' : 'Envio local',
      'pickup_location_id': pickupLocationId,
      'pickup_location_name': pickupLocationName,
      'total': _firstNonEmpty([
        order['total']?.toString(),
        order['order_total']?.toString(),
        order['orderTotal']?.toString(),
      ]),
    };
  }

  static String _normalizeOrderStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) return 'pending';

    switch (normalized) {
      case 'pending':
      case 'pending-payment':
      case 'awaiting-payment':
      case 'checkout-draft':
      case 'draft':
        return 'pending';
      case 'on-hold':
      case 'onhold':
      case 'hold':
        return 'on-hold';
      case 'processing':
      case 'in-progress':
      case 'inprogress':
        return 'processing';
      case 'completed':
      case 'complete':
        return 'completed';
      case 'cancelled':
      case 'canceled':
      case 'trash':
        return 'cancelled';
      case 'failed':
      case 'payment-failed':
        return 'failed';
      case 'refunded':
      case 'refund':
      case 'partially-refunded':
      case 'partial-refund':
        return 'refunded';
      default:
        return normalized;
    }
  }

  static String _orderStatusDisplay(
    String status, {
    String fallback = '',
  }) {
    switch (status) {
      case 'pending':
        return 'Pendiente de pago';
      case 'on-hold':
        return 'En validación';
      case 'processing':
        return 'Preparando pedido';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'failed':
        return 'Pago fallido';
      case 'refunded':
        return 'Reembolsado';
      default:
        final cleaned = fallback.trim().isNotEmpty ? fallback.trim() : status;
        return cleaned.isEmpty ? 'Pendiente' : cleaned;
    }
  }

  static String _orderStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Tu pedido ya fue recibido y está pendiente de pago o confirmación inicial.';
      case 'on-hold':
        return 'Estamos validando el pago o revisando los datos de esta compra.';
      case 'processing':
        return 'Tu pedido ya entró en preparación y avanza correctamente.';
      case 'completed':
        return 'Tu pedido fue completado con exito.';
      case 'cancelled':
        return 'Este pedido fue cancelado y ya no tendra nuevos avances.';
      case 'failed':
        return 'Hubo un problema al procesar el pago y el pedido no pudo avanzar.';
      case 'refunded':
        return 'Este pedido ya fue reembolsado.';
      default:
        return 'Estamos actualizando el estado de tu pedido.';
    }
  }

  static String _orderStatusLifecycle(String status) {
    switch (status) {
      case 'pending':
      case 'on-hold':
        return 'attention';
      case 'processing':
        return 'active';
      case 'completed':
        return 'completed';
      case 'cancelled':
      case 'failed':
      case 'refunded':
        return 'closed';
      default:
        return 'attention';
    }
  }

  static bool _isClosedOrderStatus(String status) {
    return const ['cancelled', 'failed', 'refunded', 'completed']
        .contains(status);
  }

  static Map<String, String> _flattenMetaData(List<dynamic> metaData) {
    final lookup = <String, String>{};

    for (final item in metaData.whereType<Map>()) {
      final map = _asMap(item);
      final key = (map['key'] ?? '').toString().trim();
      if (key.isEmpty) continue;
      lookup[key] = (map['value'] ?? '').toString().trim();
    }

    return lookup;
  }

  static String _normalizeFulfillmentMethod(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'pickup':
      case 'local-pickup':
      case 'localpickup':
      case 'retiro':
        return 'pickup';
      default:
        return 'delivery';
    }
  }

  static DateTime? _parseOrderDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    if (trimmed.contains(' ') && !trimmed.contains('T')) {
      return DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    }

    return null;
  }

  static String _formatOrderDate(String value) {
    final parsed = _parseOrderDate(value);
    if (parsed == null) {
      return value.split('T').first.split(' ').first;
    }

    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Map<String, dynamic> _normalizeLineItemPayload(
    Map<String, dynamic> item,
  ) {
    final productId = _parseInt(item['product_id'] ?? item['productId']) ?? 0;
    final quantity = _parseInt(item['quantity']) ?? 1;
    final variationId =
        _parseInt(item['variation_id'] ?? item['variationId']) ?? 0;

    return {
      'product_id': productId,
      if (variationId > 0) 'variation_id': variationId,
      'quantity': quantity < 1 ? 1 : quantity,
    };
  }

  static Map<String, dynamic> _removeEmpty(Map<String, dynamic> input) {
    return Map<String, dynamic>.fromEntries(
      input.entries.where((entry) => entry.value.toString().trim().isNotEmpty),
    );
  }

  static Map<String, dynamic> _removeNulls(Map<String, dynamic> input) {
    return Map<String, dynamic>.fromEntries(
      input.entries.where((entry) => entry.value != null),
    );
  }

  static String _formatAmount(double value) => value.toStringAsFixed(2);

  static double _amountNumber(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  static int? _firstPositiveInt(List<int?> values) {
    for (final value in values) {
      if (value != null && value > 0) return value;
    }
    return null;
  }

  static String _sumShippingLines(List<dynamic> shippingLines) {
    var total = 0.0;
    for (final line in shippingLines.whereType<Map>()) {
      final map = _asMap(line);
      total += double.tryParse(map['total']?.toString() ?? '') ?? 0;
    }
    return total > 0 ? _formatAmount(total) : '';
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int _score(Map<String, dynamic> product, String normalizedQuery) {
    final name = _normalize((product['name'] ?? '').toString());
    final slug = _normalize((product['slug'] ?? '').toString());
    final sku = _normalize((product['sku'] ?? '').toString());
    final categoryTerms = _categoryTerms(product);

    var score = 0;
    if (name == normalizedQuery) score += 1000;
    if (slug == normalizedQuery || sku == normalizedQuery) score += 700;
    if (name.startsWith(normalizedQuery)) score += 500;
    if (name.contains(normalizedQuery)) score += 250;
    if (slug.contains(normalizedQuery) || sku.contains(normalizedQuery)) {
      score += 180;
    }

    for (final token in name.split(' ')) {
      if (token.startsWith(normalizedQuery)) score += 120;
      if (_levenshtein(token, normalizedQuery) <= 1 &&
          normalizedQuery.length >= 4) {
        score += 80;
      }
    }

    for (final term in categoryTerms) {
      if (term == normalizedQuery) score += 620;
      if (term.startsWith(normalizedQuery)) score += 220;
      if (term.contains(normalizedQuery)) score += 120;

      for (final token in term.split(' ')) {
        if (token.startsWith(normalizedQuery)) score += 70;
      }
    }

    return score;
  }

  static int _scoreCategory(
    Map<String, dynamic> category,
    String normalizedQuery,
  ) {
    final name = _normalize((category['name'] ?? '').toString());
    final slug = _normalize((category['slug'] ?? '').toString());

    var score = 0;
    if (name == normalizedQuery) score += 1000;
    if (slug == normalizedQuery) score += 800;
    if (name.startsWith(normalizedQuery)) score += 500;
    if (name.contains(normalizedQuery)) score += 240;
    if (slug.contains(normalizedQuery)) score += 180;

    for (final token in name.split(' ')) {
      if (token.startsWith(normalizedQuery)) score += 110;
      if (_levenshtein(token, normalizedQuery) <= 1 &&
          normalizedQuery.length >= 4) {
        score += 70;
      }
    }

    return score;
  }

  static List<String> _categoryTerms(Map<String, dynamic> product) {
    final raw = product['categories'];
    if (raw is! List) return const <String>[];

    final terms = <String>{};
    for (final item in raw) {
      final category = _asMap(item);
      final name = _normalize((category['name'] ?? '').toString());
      final slug = _normalize((category['slug'] ?? '').toString());
      if (name.isNotEmpty) terms.add(name);
      if (slug.isNotEmpty) terms.add(slug);
    }
    return terms.toList();
  }

  static bool _productMatchesCategoryValue(
    Map<String, dynamic> product,
    String category,
  ) {
    final normalizedCategory = category.trim();
    if (normalizedCategory.isEmpty) return true;

    final categories = product['categories'];
    if (categories is! List) return false;

    for (final item in categories) {
      final raw = _asMap(item);
      final id = raw['id']?.toString().trim();
      final slug = raw['slug']?.toString().trim();
      final name = raw['name']?.toString().trim();
      if (normalizedCategory == id ||
          normalizedCategory == slug ||
          normalizedCategory == name) {
        return true;
      }
    }

    return false;
  }

  static String _normalize(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().trim().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }
    return previous[b.length];
  }

  static Future<void> _ensureLoaded() {
    _loadFuture ??= _loadCache();
    return _loadFuture!;
  }

  static Future<void> clearCache() async {
    _listCache.clear();
    _productCache.clear();
    _refreshingListKeys.clear();
    _refreshingProductIds.clear();
    _loadFuture = null;

    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Limpiar cache es una ayuda local; nunca debe bloquear la compra.
    }
  }

  static void _refreshListInBackground(
    String key,
    Future<void> Function() refresh,
  ) {
    if (!_refreshingListKeys.add(key)) return;

    unawaited(
      refresh().catchError((_) {}).whenComplete(() {
        _refreshingListKeys.remove(key);
      }),
    );
  }

  static void _refreshProductInBackground(int productId) {
    if (!_refreshingProductIds.add(productId)) return;

    unawaited(
      getProduct(productId: productId, forceRefresh: true)
          .catchError((_) => <String, dynamic>{})
          .whenComplete(() {
        _refreshingProductIds.remove(productId);
      }),
    );
  }

  static Future<void> _loadCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      if (_parseInt(data['version']) != _cacheSchemaVersion) return;

      final lists = _asMap(data['lists']);
      for (final entry in lists.entries) {
        final map = _asMap(entry.value);
        final expiresAt = DateTime.tryParse(
          map['expires_at']?.toString() ?? '',
        );
        final staleUntil = DateTime.tryParse(
              map['stale_until']?.toString() ?? '',
            ) ??
            expiresAt?.add(_staleListTtl);
        if (expiresAt == null ||
            staleUntil == null ||
            DateTime.now().isAfter(staleUntil)) {
          continue;
        }
        final items =
            map['data'] is List ? List<dynamic>.from(map['data']) : <dynamic>[];
        _listCache[entry.key] = _CacheEntry(
          items
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
          expiresAt,
          staleUntil,
        );
      }

      final products = _asMap(data['products']);
      for (final entry in products.entries) {
        final id = int.tryParse(entry.key);
        if (id == null) continue;
        final map = _asMap(entry.value);
        final expiresAt = DateTime.tryParse(
          map['expires_at']?.toString() ?? '',
        );
        final staleUntil = DateTime.tryParse(
              map['stale_until']?.toString() ?? '',
            ) ??
            expiresAt?.add(_staleProductTtl);
        if (expiresAt == null ||
            staleUntil == null ||
            DateTime.now().isAfter(staleUntil)) {
          continue;
        }
        _productCache[id] = _CacheEntry(
          _asMap(map['data']),
          expiresAt,
          staleUntil,
        );
      }
    } catch (_) {
      // Cache best effort.
    }
  }

  static Future<void> _persistCache() async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(
        jsonEncode({
          'version': _cacheSchemaVersion,
          'lists': _listCache.map(
            (key, value) => MapEntry(
              key,
              {
                'expires_at': value.expiresAt.toIso8601String(),
                'stale_until': value.staleUntil.toIso8601String(),
                'data': value.value,
              },
            ),
          ),
          'products': _productCache.map(
            (key, value) => MapEntry(
              key.toString(),
              {
                'expires_at': value.expiresAt.toIso8601String(),
                'stale_until': value.staleUntil.toIso8601String(),
                'data': value.value,
              },
            ),
          ),
        }),
      );
    } catch (_) {
      // Cache best effort.
    }
  }

  static Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir =
        Directory('${dir.path}${Platform.pathSeparator}shop_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}${Platform.pathSeparator}catalog.json');
  }

  static void _primeProductCache(List<Map<String, dynamic>> products) {
    final expiresAt = DateTime.now().add(_productTtl);
    final staleUntil = expiresAt.add(_staleProductTtl);
    for (final product in products) {
      final id = int.tryParse((product['id'] ?? '').toString());
      if (id != null && id > 0) {
        _productCache[id] = _CacheEntry(
          _cloneMap(product),
          expiresAt,
          staleUntil,
        );
      }
    }
  }

  static void _storeProduct(int id, Map<String, dynamic> product) {
    final expiresAt = DateTime.now().add(_productTtl);
    _productCache[id] = _CacheEntry(
      _cloneMap(product),
      expiresAt,
      expiresAt.add(_staleProductTtl),
    );
    unawaited(_persistCache());
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      throw Exception(
        FriendlyErrors.clean(
          response.body,
          statusCode: response.statusCode,
          fallback: 'Respuesta inesperada de la tienda.',
        ),
      );
    }
    throw Exception('Respuesta inesperada de la tienda.');
  }

  static String _extractMessage(Map<String, dynamic> data) {
    final message = data['message']?.toString() ??
        _asMap(data['error'])['message']?.toString() ??
        'No pudimos completar la operacion en la tienda.';
    return FriendlyErrors.checkout(message);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
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

  static List<Map<String, dynamic>> _cloneList(
    List<Map<String, dynamic>> items,
  ) {
    return items.map(_cloneMap).toList();
  }

  static Map<String, dynamic> _cloneMap(Map<String, dynamic> item) {
    return jsonDecode(jsonEncode(item)) as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> _mergeAndSortOrders(
    List<Map<String, dynamic>> orders,
  ) {
    final byKey = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      final id = _parseInt(order['id']) ?? 0;
      final number = (order['number'] ?? '').toString().trim();
      final key = id > 0
          ? 'id:$id'
          : number.isNotEmpty
              ? 'number:$number'
              : jsonEncode(order);
      byKey[key] = order;
    }

    final merged = byKey.values.map(_cloneMap).toList();
    merged.sort((a, b) {
      final aMillis = _parseInt(a['date_created_epoch']) ??
          _parseOrderDate((a['date_created'] ?? '').toString())
              ?.millisecondsSinceEpoch ??
          0;
      final bMillis = _parseInt(b['date_created_epoch']) ??
          _parseOrderDate((b['date_created'] ?? '').toString())
              ?.millisecondsSinceEpoch ??
          0;
      return bMillis.compareTo(aMillis);
    });
    return merged;
  }

  static Map<String, String> _defaultHeaders() => {
        'Accept': 'application/json',
      };

  static Map<String, String> _authHeaders(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, String> _jsonAuthHeaders(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, String> _withIdempotencyHeaders(
    Map<String, String> headers,
    String key,
  ) {
    return {
      ...headers,
      'Idempotency-Key': key,
      'X-Idempotency-Key': key,
      'X-Habito-Idempotency-Key': key,
    };
  }

  static bool _shouldRetryPostResponse(int statusCode) {
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  static Duration _postBackoffDelay(int attempt) {
    final multiplier = 1 << attempt;
    return Duration(milliseconds: 500 * multiplier);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  final DateTime staleUntil;

  const _CacheEntry(this.value, this.expiresAt, this.staleUntil);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isUsable => DateTime.now().isBefore(staleUntil);
}

class _RankedProduct {
  final Map<String, dynamic> product;
  final int score;

  const _RankedProduct(this.product, this.score);
}

class _RankedCategory {
  final Map<String, dynamic> category;
  final int score;

  const _RankedCategory(this.category, this.score);
}

extension on num {
  num pow(int exponent) {
    num result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}
