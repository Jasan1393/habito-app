class ShopPaymentMethod {
  final String id;
  final String title;
  final String description;
  final bool enabled;
  final bool requiresOnlinePayment;
  final bool canCreateManualOrder;
  final String flow;
  final String orderStatus;
  final Map<String, dynamic> bankDetails;

  const ShopPaymentMethod({
    required this.id,
    required this.title,
    required this.description,
    required this.enabled,
    required this.requiresOnlinePayment,
    required this.canCreateManualOrder,
    required this.flow,
    required this.orderStatus,
    required this.bankDetails,
  });

  static const bankTransfer = ShopPaymentMethod(
    id: 'bacs',
    title: 'Transferencia o depósito bancario',
    description:
        'Creamos el pedido y luego validas el pago con el equipo de Hábito.',
    enabled: true,
    requiresOnlinePayment: false,
    canCreateManualOrder: true,
    flow: 'manual_order',
    orderStatus: 'on-hold',
    bankDetails: {},
  );

  static const onSite = ShopPaymentMethod(
    id: 'cod',
    title: 'On-site (pagar en el sitio)',
    description: 'Confirma tu cita y paga directamente en la barberia.',
    enabled: true,
    requiresOnlinePayment: false,
    canCreateManualOrder: true,
    flow: 'manual_order',
    orderStatus: 'on-hold',
    bankDetails: {},
  );

  bool get isBankTransfer => id == 'bacs';
  bool get isOnSite => id == 'cod' || id == 'on_site' || id == 'onsite';

  bool get hasBankDetails => bankDetails.values.any(
        (value) => value != null && value.toString().trim().isNotEmpty,
      );

  factory ShopPaymentMethod.fromJson(Map<String, dynamic> json) {
    final id = _readString(json, [
      'id',
      'method_id',
      'payment_method',
      'paymentMethod',
    ]);
    final normalizedId = id.isEmpty ? bankTransfer.id : id;
    final requiresOnlinePayment = _readBool(
      json,
      [
        'requires_online_payment',
        'requiresOnlinePayment',
        'online',
      ],
      fallback: normalizedId.contains('payphone'),
    );

    final rawTitle = _readString(
      json,
      ['title', 'name', 'payment_title', 'paymentTitle'],
      fallback: _defaultTitle(normalizedId),
    );
    final rawDescription = _readString(
      json,
      ['description', 'subtitle', 'details'],
      fallback: _defaultDescription(normalizedId),
    );

    return ShopPaymentMethod(
      id: normalizedId,
      title: _normalizeTitle(normalizedId, rawTitle),
      description: _normalizeDescription(normalizedId, rawDescription),
      enabled: _readBool(json, ['enabled', 'is_enabled', 'active']),
      requiresOnlinePayment: requiresOnlinePayment,
      canCreateManualOrder: _readBool(
        json,
        ['can_create_manual_order', 'canCreateManualOrder'],
        fallback: !requiresOnlinePayment,
      ),
      flow: _readString(
        json,
        ['flow', 'type'],
        fallback: requiresOnlinePayment ? 'online' : 'manual_order',
      ),
      orderStatus: _readString(
        json,
        ['order_status', 'orderStatus', 'status'],
        fallback: _defaultOrderStatus(normalizedId),
      ),
      bankDetails: _readMap(json, [
        'bank_details',
        'bankDetails',
        'account_details',
        'accountDetails',
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'enabled': enabled,
      'requires_online_payment': requiresOnlinePayment,
      'can_create_manual_order': canCreateManualOrder,
      'flow': flow,
      'order_status': orderStatus,
      'bank_details': bankDetails,
    };
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static bool _readBool(
    Map<String, dynamic> json,
    List<String> keys, {
    bool fallback = true,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase().trim();
        if (['1', 'true', 'yes', 'on'].contains(normalized)) return true;
        if (['0', 'false', 'no', 'off'].contains(normalized)) return false;
      }
    }
    return fallback;
  }

  static String _defaultTitle(String id) {
    if (id == 'bacs') return bankTransfer.title;
    if (id == 'cod' || id == 'on_site' || id == 'onsite') {
      return onSite.title;
    }
    if (id.contains('payphone')) return 'Pago en línea';
    return 'Método de pago';
  }

  static String _defaultDescription(String id) {
    if (id == 'bacs') return bankTransfer.description;
    if (id == 'cod' || id == 'on_site' || id == 'onsite') {
      return onSite.description;
    }
    if (id.contains('payphone')) {
      return 'Pago en línea disponible próximamente.';
    }
    return 'Selecciona este método para confirmar tu pedido.';
  }

  static String _normalizeTitle(String id, String title) {
    final lower = title.trim().toLowerCase();
    if ((id == 'cod' || id == 'on_site' || id == 'onsite') &&
        (lower.isEmpty ||
            lower == 'cod' ||
            lower.contains('contra entrega') ||
            lower.contains('cash on delivery'))) {
      return onSite.title;
    }

    return title.trim().isNotEmpty ? title.trim() : _defaultTitle(id);
  }

  static String _normalizeDescription(String id, String description) {
    final lower = description.trim().toLowerCase();
    if ((id == 'cod' || id == 'on_site' || id == 'onsite') &&
        (lower.isEmpty ||
            lower.contains('recibirlo') ||
            lower.contains('delivery'))) {
      return onSite.description;
    }

    return description.trim().isNotEmpty
        ? description.trim()
        : _defaultDescription(id);
  }

  static String _defaultOrderStatus(String id) {
    return ['bacs', 'cod', 'on_site', 'onsite', 'cheque'].contains(id)
        ? 'on-hold'
        : 'pending';
  }
}
