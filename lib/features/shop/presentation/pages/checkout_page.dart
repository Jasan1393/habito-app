import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/ecuador_data.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../points/provider/points_provider.dart';
import '../../data/services/habito_shop_api.dart';
import '../../models/shop_payment_method.dart';
import '../../provider/shop_provider.dart';
import 'orders_page.dart';

const Map<String, List<String>> _ecuadorLocations = {
  'Azuay': [
    'Cuenca',
    'Camilo Ponce Enriquez',
    'Chordeleg',
    'El Pan',
    'Giron',
    'Guachapala',
    'Gualaceo',
    'Nabon',
    'Ona',
    'Paute',
    'Pucara',
    'San Fernando',
    'Santa Isabel',
    'Sevilla de Oro',
    'Sigsig',
  ],
  'Bolivar': [
    'Guaranda',
    'Caluma',
    'Chillanes',
    'Chimbo',
    'Echeandia',
    'Las Naves',
    'San Miguel',
  ],
  'Canar': [
    'Azogues',
    'Biblian',
    'Canar',
    'Deleg',
    'El Tambo',
    'La Troncal',
    'Suscal',
  ],
  'Carchi': [
    'Tulcan',
    'Bolivar',
    'Espejo',
    'Mira',
    'Montufar',
    'San Pedro de Huaca',
  ],
  'Chimborazo': [
    'Riobamba',
    'Alausi',
    'Chambo',
    'Chunchi',
    'Colta',
    'Cumanda',
    'Guamote',
    'Guano',
    'Pallatanga',
    'Penipe',
  ],
  'Cotopaxi': [
    'Latacunga',
    'La Mana',
    'Pangua',
    'Pujili',
    'Salcedo',
    'Saquisili',
    'Sigchos',
  ],
  'El Oro': [
    'Machala',
    'Arenillas',
    'Atahualpa',
    'Balsas',
    'Chilla',
    'El Guabo',
    'Huaquillas',
    'Las Lajas',
    'Marcabeli',
    'Pasaje',
    'Pinas',
    'Portovelo',
    'Santa Rosa',
    'Zaruma',
  ],
  'Esmeraldas': [
    'Esmeraldas',
    'Atacames',
    'Eloy Alfaro',
    'Muisne',
    'Quininde',
    'Rioverde',
    'San Lorenzo',
  ],
  'Galapagos': [
    'San Cristobal',
    'Isabela',
    'Santa Cruz',
  ],
  'Guayas': [
    'Guayaquil',
    'Alfredo Baquerizo Moreno',
    'Balao',
    'Balzar',
    'Colimes',
    'Daule',
    'Duran',
    'El Empalme',
    'El Triunfo',
    'General Antonio Elizalde',
    'Isidro Ayora',
    'Lomas de Sargentillo',
    'Marcelino Mariduena',
    'Milagro',
    'Naranjal',
    'Naranjito',
    'Nobol',
    'Palestina',
    'Pedro Carbo',
    'Playas',
    'Salitre',
    'Samborondon',
    'Santa Lucia',
    'Simon Bolivar',
    'Yaguachi',
  ],
  'Imbabura': [
    'Ibarra',
    'Antonio Ante',
    'Cotacachi',
    'Otavalo',
    'Pimampiro',
    'San Miguel de Urcuqui',
  ],
  'Loja': [
    'Loja',
    'Calvas',
    'Catamayo',
    'Celica',
    'Chaguarpamba',
    'Espindola',
    'Gonzanama',
    'Macara',
    'Olmedo',
    'Paltas',
    'Pindal',
    'Puyango',
    'Quilanga',
    'Saraguro',
    'Sozoranga',
    'Zapotillo',
  ],
  'Los Rios': [
    'Babahoyo',
    'Baba',
    'Buena Fe',
    'Mocache',
    'Montalvo',
    'Palenque',
    'Pueblo Viejo',
    'Quevedo',
    'Quinsaloma',
    'Urdaneta',
    'Valencia',
    'Ventanas',
    'Vinces',
  ],
  'Manabi': [
    'Portoviejo',
    'Bolivar',
    'Chone',
    'El Carmen',
    'Flavio Alfaro',
    'Jama',
    'Jaramijo',
    'Jipijapa',
    'Junin',
    'Manta',
    'Montecristi',
    'Olmedo',
    'Pajan',
    'Pedernales',
    'Pichincha',
    'Puerto Lopez',
    'Rocafuerte',
    'San Vicente',
    'Santa Ana',
    'Sucre',
    'Tosagua',
    '24 de Mayo',
  ],
  'Morona Santiago': [
    'Morona',
    'Gualaquiza',
    'Huamboya',
    'Limon Indanza',
    'Logrono',
    'Pablo Sexto',
    'Palora',
    'San Juan Bosco',
    'Santiago',
    'Sucua',
    'Taisha',
    'Tiwintza',
  ],
  'Napo': [
    'Tena',
    'Archidona',
    'Carlos Julio Arosemena Tola',
    'El Chaco',
    'Quijos',
  ],
  'Orellana': [
    'Francisco de Orellana',
    'Aguarico',
    'La Joya de los Sachas',
    'Loreto',
  ],
  'Pastaza': [
    'Pastaza',
    'Arajuno',
    'Mera',
    'Santa Clara',
  ],
  'Pichincha': [
    'Quito',
    'Cayambe',
    'Mejia',
    'Pedro Moncayo',
    'Pedro Vicente Maldonado',
    'Puerto Quito',
    'Ruminahui',
    'San Miguel de los Bancos',
  ],
  'Santa Elena': [
    'Santa Elena',
    'La Libertad',
    'Salinas',
  ],
  'Santo Domingo de los Tsachilas': [
    'Santo Domingo',
    'La Concordia',
  ],
  'Sucumbios': [
    'Lago Agrio',
    'Cascales',
    'Cuyabeno',
    'Gonzalo Pizarro',
    'Putumayo',
    'Shushufindi',
    'Sucumbios',
  ],
  'Tungurahua': [
    'Ambato',
    'Banos de Agua Santa',
    'Cevallos',
    'Mocha',
    'Patate',
    'Quero',
    'San Pedro de Pelileo',
    'Santiago de Pillaro',
    'Tisaleo',
  ],
  'Zamora Chinchipe': [
    'Zamora',
    'Centinela del Condor',
    'Chinchipe',
    'El Pangui',
    'Nangaritza',
    'Palanda',
    'Paquisha',
    'Yacuambi',
    'Yantzaza',
  ],
};

class CheckoutPage extends StatefulWidget {
  final String? initialCustomerNote;
  final String? headerMessage;

  const CheckoutPage({
    super.key,
    this.initialCustomerNote,
    this.headerMessage,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _billingNameController = TextEditingController();
  final _billingEmailController = TextEditingController();
  final _billingPhoneController = TextEditingController();
  final _documentController = TextEditingController();
  final _addressController = TextEditingController();
  final _address2Controller = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _pickupLocations = [];
  bool _isLoadingPickupLocations = false;
  bool _isBillingEditing = false;
  bool _usePoints = false;
  String _documentType = 'cedula';
  String _selectedProvince = 'Guayas';
  String _selectedCanton = 'Guayaquil';
  String _selectedPaymentMethodId = ShopPaymentMethod.bankTransfer.id;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _billingNameController.text = _initialBillingName(user);
    _billingEmailController.text = user?.email ?? '';
    _billingPhoneController.text = user?.phone ?? '';
    _documentType = _normalizeDocumentType(user?.identificationType);
    _documentController.text = user?.taxNumber ?? '';
    _selectedProvince = kEcuadorProvinces.contains(user?.province)
        ? user!.province
        : 'Guayas';
    _selectedCanton = _resolveInitialCanton(
      province: _selectedProvince,
      city: user?.city ?? '',
    );
    _addressController.text = user?.address ?? '';
    _noteController.text = widget.initialCustomerNote ?? '';
    Future.microtask(_loadPaymentMethods);
    Future.microtask(_loadPickupLocations);
    Future.microtask(_loadPointsSummaryIfNeeded);
  }

  Future<void> _loadPointsSummaryIfNeeded() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    await context.read<PointsProvider>().load(forceRefresh: true);
  }

  @override
  void dispose() {
    _billingNameController.dispose();
    _billingEmailController.dispose();
    _billingPhoneController.dispose();
    _documentController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\$${value.toStringAsFixed(0)}';
    }
    return '\$${value.toStringAsFixed(2)}';
  }

  String _formatShipping(double value) {
    return value <= 0 ? 'Gratis' : _formatPrice(value);
  }

  String _initialBillingName(AuthUser? user) {
    if (user == null) return '';

    if (user.contactType == 'business' && user.businessName.trim().isNotEmpty) {
      return user.businessName.trim();
    }

    if (user.displayName.trim().isNotEmpty) {
      return user.displayName.trim();
    }

    return '${user.firstName} ${user.lastName}'.trim();
  }

  String _normalizeDocumentType(String? value) {
    const allowed = <String>{
      'cedula',
      'ruc',
      'pasaporte',
    };
    return allowed.contains(value) ? value! : 'cedula';
  }

  String _resolveInitialCanton({
    required String province,
    required String city,
  }) {
    final cantons = _ecuadorLocations[province] ?? const <String>[];
    final normalizedCity = city.trim().toLowerCase();

    for (final canton in cantons) {
      if (canton.toLowerCase() == normalizedCity) {
        return canton;
      }
    }

    return cantons.isNotEmpty ? cantons.first : city.trim();
  }

  _CheckoutPointsState _resolvePointsState(
    AuthProvider auth, [
    PointsProvider? pointsProvider,
  ]) {
    final user = auth.user;
    final summary = pointsProvider?.summary;

    return _CheckoutPointsState(
      enabled: summary?.enabled ?? user?.pointsEnabled ?? false,
      redeemEnabled:
          summary?.redeemEnabled ?? user?.pointsRedeemEnabled ?? false,
      redeemProductsEnabled: summary?.redeemProductsEnabled ??
          user?.pointsRedeemProductsEnabled ??
          false,
      redeemBookingsEnabled: summary?.redeemBookingsEnabled ??
          user?.pointsRedeemBookingsEnabled ??
          false,
      balance: summary?.balance ?? user?.pointsBalance ?? 0,
      rate: summary?.redeemPointsPerUsd ??
          user?.pointsRedeemPointsPerUsd ??
          100,
      minPoints:
          summary?.redeemMinPoints ?? user?.pointsRedeemMinPoints ?? 1,
      maxPercent:
          summary?.redeemMaxPercent ?? user?.pointsRedeemMaxPercent ?? 100,
      label: (summary?.label ?? user?.pointsLabel ?? 'Puntos').trim(),
    );
  }

  double _pointsToUse(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    final pointsState = _resolvePointsState(auth, pointsProvider);
    if (!pointsState.enabled ||
        !pointsState.redeemEnabled ||
        !pointsState.redeemProductsEnabled ||
        total <= 0) {
      return 0;
    }

    final rate = pointsState.rate > 0 ? pointsState.rate : 100.0;
    final maxPercent = pointsState.maxPercent.clamp(0, 100).toDouble();
    final maxDiscount = total * (maxPercent / 100);
    final maxPointsByTotal = maxDiscount * rate;
    final points = pointsState.balance < maxPointsByTotal
        ? pointsState.balance
        : maxPointsByTotal;

    if (points < pointsState.minPoints) return 0;
    return double.parse(points.toStringAsFixed(2));
  }

  double _pointsDiscount(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    final points = _pointsToUse(auth, total, pointsProvider);
    final pointsState = _resolvePointsState(auth, pointsProvider);
    final rate = pointsState.rate > 0 ? pointsState.rate : 100;
    if (points <= 0 || rate <= 0) return 0;
    final discount = points / rate;
    return discount > total ? total : double.parse(discount.toStringAsFixed(2));
  }

  Future<void> _loadPaymentMethods() async {
    final shop = context.read<ShopProvider>();
    await shop.loadPaymentMethods();

    if (!mounted) return;

    final methods = shop.paymentMethods.where((method) => method.enabled);
    final selectedExists = methods.any(
      (method) => method.id == _selectedPaymentMethodId,
    );

    if (!selectedExists && methods.isNotEmpty) {
      setState(() {
        _selectedPaymentMethodId = methods.first.id;
      });
    }
  }

  Future<void> _loadPickupLocations() async {
    if (_isLoadingPickupLocations) return;
    setState(() {
      _isLoadingPickupLocations = true;
    });

    try {
      final cached = await HabitoShopApi.getWarehouses();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _pickupLocations = cached
              .whereType<Map>()
              .map(
                  (item) => _normalizeLocation(Map<String, dynamic>.from(item)))
              .where((item) => item['id'] != null)
              .toList();
        });
      }

      final fresh = await HabitoShopApi.getWarehouses(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _pickupLocations = fresh
            .whereType<Map>()
            .map((item) => _normalizeLocation(Map<String, dynamic>.from(item)))
            .where((item) => item['id'] != null)
            .toList();
      });
    } catch (_) {
      // El checkout puede continuar con envío aunque las sucursales no carguen.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPickupLocations = false;
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

  List<String> get _availableCantons =>
      _ecuadorLocations[_selectedProvince] ?? const <String>[];

  void _selectProvince(String? province) {
    if (province == null || province == _selectedProvince) return;
    final cantons = _ecuadorLocations[province] ?? const <String>[];
    setState(() {
      _selectedProvince = province;
      _selectedCanton = cantons.isNotEmpty ? cantons.first : '';
    });
  }

  void _selectCanton(String? canton) {
    if (canton == null) return;
    setState(() {
      _selectedCanton = canton;
    });
  }

  List<String> _splitCustomerName(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return ['', ''];
    if (list.length == 1) return [list.first, ''];
    return [list.first, list.skip(1).join(' ')];
  }

  bool _isValidDocument(String value) {
    final text = value.trim();
    final digits = text.replaceAll(RegExp(r'\D'), '');

    if (_documentType == 'ruc') return digits.length == 13;
    if (_documentType == 'pasaporte') return text.length >= 5;
    return digits.length == 10;
  }

  bool _isValidEmail(String value) {
    final text = value.trim();
    return text.contains('@') && text.contains('.');
  }

  List<String> _missingCheckoutInfo(ShopFulfillmentMethod fulfillmentMethod) {
    final missing = <String>[];
    final name = _billingNameController.text.trim();
    final email = _billingEmailController.text.trim();
    final phoneDigits =
        _billingPhoneController.text.replaceAll(RegExp(r'\D'), '');
    final documentLabel = _documentLabel;
    final document = _documentController.text.trim();

    if (name.isEmpty) missing.add('nombre de facturación');
    if (email.isEmpty) {
      missing.add('correo electrónico');
    } else if (!_isValidEmail(email)) {
      missing.add('correo electrónico válido');
    }
    if (phoneDigits.length < 7) missing.add('número de teléfono');
    if (document.isEmpty) {
      missing.add(documentLabel);
    } else if (!_isValidDocument(document)) {
      missing.add('$documentLabel válido');
    }

    if (fulfillmentMethod == ShopFulfillmentMethod.delivery) {
      if (_selectedProvince.trim().isEmpty) missing.add('provincia');
      if (_selectedCanton.trim().isEmpty) missing.add('cantón');
      if (_addressController.text.trim().isEmpty) {
        missing.add('dirección de entrega');
      }
    } else if (context.read<ShopProvider>().pickupLocationName.isEmpty) {
      missing.add('sucursal preferida de retiro');
    }

    return missing;
  }

  String get _documentLabel {
    return kIdentificationTypeLabels[_documentType] ?? 'documento';
  }

  void _showMissingCheckoutInfo(List<String> missing) {
    if (missing.isEmpty) return;
    final hasBillingIssue = missing.any(
      (item) =>
          item.contains('facturación') ||
          item.contains('correo') ||
          item.contains('teléfono') ||
          item.contains('cédula') ||
          item.contains('RUC'),
    );
    if (hasBillingIssue && !_isBillingEditing) {
      setState(() {
        _isBillingEditing = true;
      });
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Text('Falta completar: ${missing.join(', ')}.'),
        ),
      );
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

  ShopPaymentMethod _selectedPaymentMethod(
    List<ShopPaymentMethod> methods,
  ) {
    for (final method in methods) {
      if (method.id == _selectedPaymentMethodId && method.enabled) {
        return method;
      }
    }

    for (final method in methods) {
      if (method.enabled) return method;
    }

    return ShopPaymentMethod.bankTransfer;
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final shop = context.read<ShopProvider>();
    final pointsProvider = context.read<PointsProvider>();
    final selectedPaymentMethod = _selectedPaymentMethod(shop.paymentMethods);
    final fulfillmentMethod = shop.fulfillmentMethod;

    final missingInfo = _missingCheckoutInfo(fulfillmentMethod);
    if (missingInfo.isNotEmpty) {
      _formKey.currentState!.validate();
      _showMissingCheckoutInfo(missingInfo);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showMissingCheckoutInfo(['revisa los datos marcados en rojo']);
      return;
    }
    if (!auth.isLoggedIn || auth.user == null || auth.token == null) return;

    if (fulfillmentMethod == ShopFulfillmentMethod.pickup &&
        shop.pickupLocationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la sucursal preferida de retiro.'),
        ),
      );
      return;
    }

    if (fulfillmentMethod == ShopFulfillmentMethod.delivery &&
        (_selectedProvince.isEmpty || _selectedCanton.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona provincia y cantón para el envío.'),
        ),
      );
      return;
    }

    if (!selectedPaymentMethod.canCreateManualOrder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedPaymentMethod.title} estará disponible pronto para pedidos desde la app.',
          ),
        ),
      );
      return;
    }

    final nameParts = _splitCustomerName(_billingNameController.text);
    final redeemPoints = _usePoints
        ? _pointsToUse(
            auth,
            shop.orderTotalFor(fulfillmentMethod),
            pointsProvider,
          )
        : 0.0;
    final order = await shop.checkout(
      token: auth.token!,
      user: auth.user!,
      firstName: nameParts[0],
      lastName: nameParts[1],
      billingName: _billingNameController.text.trim(),
      billingEmail: _billingEmailController.text.trim(),
      billingPhone: _billingPhoneController.text.trim(),
      documentType: _documentType,
      documentNumber: _documentController.text.trim(),
      address: fulfillmentMethod == ShopFulfillmentMethod.pickup
          ? 'Retiro en tienda'
          : _addressController.text.trim(),
      address2: fulfillmentMethod == ShopFulfillmentMethod.pickup
          ? ''
          : _address2Controller.text.trim(),
      city: fulfillmentMethod == ShopFulfillmentMethod.pickup
          ? 'Retiro en tienda'
          : _selectedCanton,
      state: fulfillmentMethod == ShopFulfillmentMethod.pickup
          ? ''
          : _selectedProvince,
      customerNote: _noteController.text.trim(),
      paymentMethod: selectedPaymentMethod,
      fulfillmentMethod: fulfillmentMethod,
      redeemPoints: redeemPoints,
    );

    if (!mounted) return;

    if (order == null) {
      final error = shop.checkoutError ?? 'No pudimos crear tu pedido.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (redeemPoints > 0) {
      unawaited(auth.refreshProfile());
      unawaited(pointsProvider.refresh());
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu pedido fue creado correctamente.'),
      ),
    );

    final createdOrderId = _parseInt(order['id'] ?? order['order_id']);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrdersPage(
          selectedNavIndex: 1,
          initialOrderId: createdOrderId != null && createdOrderId > 0
              ? createdOrderId
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ShopProvider, AuthProvider>(
      builder: (context, shop, auth, _) {
        final pointsProvider = context.watch<PointsProvider>();
        final pointsState = _resolvePointsState(auth, pointsProvider);
        final paymentMethods = shop.paymentMethods
            .where((method) => method.enabled)
            .toList(growable: false);
        final selectedPaymentMethod = _selectedPaymentMethod(paymentMethods);
        final fulfillmentMethod = shop.fulfillmentMethod;
        final shippingTotal = shop.shippingTotalFor(fulfillmentMethod);
        final orderTotal = shop.orderTotalFor(fulfillmentMethod);
        final pointsToUse = _pointsToUse(auth, orderTotal, pointsProvider);
        final pointsDiscount =
            _usePoints ? _pointsDiscount(auth, orderTotal, pointsProvider) : 0.0;
        final payableTotal =
            (orderTotal - pointsDiscount).clamp(0, double.infinity).toDouble();
        final taxLabel = shop.taxBreakdownLabel;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            title: const Text('Checkout'),
          ),
          bottomNavigationBar: HabitoBottomNavigationBar(
            selectedIndex: 1,
            onDestinationSelected: _goToMainTab,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if ((widget.headerMessage ?? '').trim().isNotEmpty) ...[
                _InlineInfoCard(message: widget.headerMessage!),
                const SizedBox(height: 16),
              ],
              _CheckoutSummaryHeader(
                itemCount: shop.cartCount,
                total: _formatPrice(orderTotal),
                deliveryLabel: fulfillmentMethod.title,
                deliveryValue: _formatShipping(shippingTotal),
              ),
              const SizedBox(height: 12),
              _CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...shop.cartItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity} x ${item.name}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatPrice(item.total),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    _CheckoutRow(
                      label: 'Productos',
                      value: _formatPrice(shop.subtotal),
                    ),
                    if (shop.hasIvaBreakdown) ...[
                      const SizedBox(height: 10),
                      _CheckoutRow(
                        label: taxLabel,
                        value: _formatPrice(shop.taxTotal),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _CheckoutRow(
                      label: fulfillmentMethod.title,
                      value: _formatShipping(shippingTotal),
                    ),
                    const Divider(height: 24),
                    if (pointsDiscount > 0) ...[
                      _CheckoutRow(
                        label: 'Puntos',
                        value: '-${_formatPrice(pointsDiscount)}',
                      ),
                      const SizedBox(height: 10),
                    ],
                    _CheckoutRow(
                      label: 'Total',
                      value: _formatPrice(payableTotal),
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
                if (pointsToUse > 0) ...[
                  _PointsRedeemTile(
                    enabled: _usePoints,
                    pointsLabel: pointsState.label,
                    points: pointsToUse,
                    discount: _pointsDiscount(
                      auth,
                      orderTotal,
                      pointsProvider,
                    ),
                    balance: pointsState.balance,
                    onChanged: (value) {
                      setState(() {
                        _usePoints = value;
                    });
                  },
                  formatPrice: _formatPrice,
                ),
                const SizedBox(height: 20),
              ],
              _SectionHeader(
                title: 'Entrega',
                subtitle:
                    'Elige si prefieres recibir el pedido o retirarlo en tienda.',
              ),
              const SizedBox(height: 14),
              _CheckoutCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FulfillmentMethodTile(
                        method: ShopFulfillmentMethod.delivery,
                        selected:
                            fulfillmentMethod == ShopFulfillmentMethod.delivery,
                        price: _formatShipping(
                          shop.shippingTotalFor(ShopFulfillmentMethod.delivery),
                        ),
                        onTap: () {
                          _handleFulfillmentMethodSelection(
                            shop,
                            ShopFulfillmentMethod.delivery,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _FulfillmentMethodTile(
                        method: ShopFulfillmentMethod.pickup,
                        selected:
                            fulfillmentMethod == ShopFulfillmentMethod.pickup,
                        price: _formatShipping(
                          shop.shippingTotalFor(ShopFulfillmentMethod.pickup),
                        ),
                        onTap: () {
                          _handleFulfillmentMethodSelection(
                            shop,
                            ShopFulfillmentMethod.pickup,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _HabitoBillingDetailsForm(
                        isEditing: _isBillingEditing,
                        documentType: _documentType,
                        nameController: _billingNameController,
                        emailController: _billingEmailController,
                        phoneController: _billingPhoneController,
                        documentController: _documentController,
                        onToggleEditing: () {
                          setState(() {
                            _isBillingEditing = !_isBillingEditing;
                          });
                        },
                        onDocumentTypeChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _documentType = value;
                          });
                        },
                        documentValidator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Ingresa tu ${kIdentificationTypeLabels[_documentType] ?? 'documento'}.';
                          }
                          if (!_isValidDocument(text)) {
                            if (_documentType == 'ruc') {
                              return 'El RUC debe tener 13 digitos.';
                            }
                            if (_documentType == 'pasaporte') {
                              return 'Ingresa un pasaporte valido.';
                            }
                            return 'La cedula debe tener 10 digitos.';
                          }
                          return null;
                        },
                      ),
                      if (fulfillmentMethod ==
                          ShopFulfillmentMethod.delivery) ...[
                        const SizedBox(height: 18),
                        _ShippingAddressForm(
                          selectedProvince: _selectedProvince,
                          selectedCanton: _selectedCanton,
                          cantons: _availableCantons,
                          addressController: _addressController,
                          address2Controller: _address2Controller,
                          onProvinceChanged: _selectProvince,
                          onCantonChanged: _selectCanton,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        _PickupLocationSelector(
                          locationName: shop.pickupLocationName,
                          selectedPickupLocation: shop.pickupLocation,
                          pickupLocations: _pickupLocations,
                          isLoadingLocations: _isLoadingPickupLocations,
                          onSelectPickupLocation: (location) =>
                              _handlePickupLocationSelection(shop, location),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Nota del pedido',
                          hintText: 'Indicaciones adicionales o referencia',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Pago',
                subtitle: 'Selecciona la forma de confirmar este pedido.',
              ),
              const SizedBox(height: 14),
              _CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.isLoadingPaymentMethods) ...[
                      const LinearProgressIndicator(
                        minHeight: 3,
                        color: Color(0xFFD4AF37),
                        backgroundColor: Color(0xFFF1EBDD),
                      ),
                      const SizedBox(height: 14),
                    ],
                    ...paymentMethods.map(
                      (method) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PaymentMethodTile(
                          method: method,
                          selected: selectedPaymentMethod.id == method.id,
                          enabled: method.canCreateManualOrder,
                          onTap: () {
                            setState(() {
                              _selectedPaymentMethodId = method.id;
                            });
                          },
                        ),
                      ),
                    ),
                    if (shop.paymentMethodsError != null) ...[
                      Text(
                        'No pudimos actualizar los métodos de pago. Usamos transferencia como respaldo.',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.9,
                          ),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7F4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF9C7732),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El stock y los datos del pedido se validan al momento de crear la orden para mantener una compra correcta.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: shop.isCreatingOrder ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: shop.isCreatingOrder
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Confirmar pedido ${_formatPrice(payableTotal)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
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

class _PointsRedeemTile extends StatelessWidget {
  final bool enabled;
  final String pointsLabel;
  final double points;
  final double discount;
  final double balance;
  final ValueChanged<bool> onChanged;
  final String Function(double value) formatPrice;

  const _PointsRedeemTile({
    required this.enabled,
    required this.pointsLabel,
    required this.points,
    required this.discount,
    required this.balance,
    required this.onChanged,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return _CheckoutCard(
      child: SwitchListTile.adaptive(
        value: enabled,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: const Color(0xFFD4AF37),
        activeTrackColor: const Color(0xFFE8D79D),
        onChanged: onChanged,
        title: Text(
          'Usar $pointsLabel',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${points.toStringAsFixed(points == points.roundToDouble() ? 0 : 2)} de ${balance.toStringAsFixed(balance == balance.roundToDouble() ? 0 : 2)} $pointsLabel disponibles · descuento ${formatPrice(discount)}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummaryHeader extends StatelessWidget {
  final int itemCount;
  final String total;
  final String deliveryLabel;
  final String deliveryValue;

  const _CheckoutSummaryHeader({
    required this.itemCount,
    required this.total,
    required this.deliveryLabel,
    required this.deliveryValue,
  });

  @override
  Widget build(BuildContext context) {
    final productLabel = itemCount == 1 ? '1 producto' : '$itemCount productos';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Resumen',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CheckoutInfoPill(label: total, dark: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Revisa productos, entrega y pago antes de confirmar.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CheckoutInfoPill(label: productLabel),
              const SizedBox(width: 6),
              Flexible(
                child: _CheckoutInfoPill(
                  label: '$deliveryLabel $deliveryValue',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckoutInfoPill extends StatelessWidget {
  final String label;
  final bool dark;

  const _CheckoutInfoPill({
    required this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : const Color(0xFFF7F0DE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark ? AppColors.primary : const Color(0xFFE8D79D),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: dark ? const Color(0xFFE7D39A) : const Color(0xFF7A5B1B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
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

class _CheckoutCard extends StatelessWidget {
  final Widget child;

  const _CheckoutCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _CheckoutRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(
            fontSize: highlight ? 20 : 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InlineInfoCard extends StatelessWidget {
  final String message;

  const _InlineInfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D8C4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: Color(0xFF9C7732),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentMethodTile extends StatelessWidget {
  final ShopFulfillmentMethod method;
  final bool selected;
  final String price;
  final VoidCallback onTap;

  const _FulfillmentMethodTile({
    required this.method,
    required this.selected,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = method == ShopFulfillmentMethod.delivery
        ? Icons.local_shipping_outlined
        : Icons.storefront_rounded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF7F0DE) : const Color(0xFFF8F7F4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFD4AF37) : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? const Color(0xFFD4AF37) : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFFE7D39A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          method.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        price,
                        style: const TextStyle(
                          color: Color(0xFF9C7732),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    method.description,
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
    );
  }
}

class _PickupLocationSelector extends StatelessWidget {
  final String locationName;
  final Map<String, dynamic>? selectedPickupLocation;
  final List<Map<String, dynamic>> pickupLocations;
  final bool isLoadingLocations;
  final ValueChanged<Map<String, dynamic>?> onSelectPickupLocation;

  const _PickupLocationSelector({
    required this.locationName,
    required this.selectedPickupLocation,
    required this.pickupLocations,
    required this.isLoadingLocations,
    required this.onSelectPickupLocation,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLocationId = _parseInt(selectedPickupLocation?['id']);
    final dropdownValue = pickupLocations.any(
      (location) => _parseInt(location['id']) == selectedLocationId,
    )
        ? selectedLocationId
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF9C7732)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locationName.isEmpty
                      ? 'Indica tu sucursal preferida para coordinar el retiro. No se cobrará envío.'
                      : 'Retiro preferido en $locationName. Te avisaremos cuando el pedido esté listo.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    onSelectPickupLocation(selected.isEmpty ? null : selected);
                  },
          ),
          if (isLoadingLocations) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFD4AF37),
              backgroundColor: Color(0xFFF1EBDD),
            ),
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

class _PaymentMethodTile extends StatelessWidget {
  final ShopPaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = method.requiresOnlinePayment
        ? 'Pago en línea'
        : method.id == 'bacs'
            ? 'Transferencia'
            : 'Disponible';

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF7F0DE) : const Color(0xFFF8F7F4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? const Color(0xFFD4AF37) : const Color(0xFFE4DED2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : enabled
                        ? Icons.radio_button_off_outlined
                        : Icons.lock_outline_rounded,
                color: selected
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFF7A7268),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            method.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7D39A).withValues(
                              alpha: 0.24,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Color(0xFF7A5B1B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      enabled
                          ? method.description
                          : '${method.description} Estará disponible pronto para pedidos desde la app.',
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

// ignore: unused_element
class _BillingDetailsForm extends StatelessWidget {
  final bool isEditing;
  final String documentType;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController documentController;
  final VoidCallback onToggleEditing;
  final ValueChanged<String?> onDocumentTypeChanged;
  final String? Function(String?) documentValidator;

  const _BillingDetailsForm({
    required this.isEditing,
    required this.documentType,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.documentController,
    required this.onToggleEditing,
    required this.onDocumentTypeChanged,
    required this.documentValidator,
  });

  @override
  Widget build(BuildContext context) {
    final documentLabel = documentType == 'ruc' ? 'RUC' : 'Cédula';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Datos de facturación',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleEditing,
                icon: Icon(
                  isEditing ? Icons.check_rounded : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(isEditing ? 'Listo' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: nameController,
            readOnly: !isEditing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: documentType == 'ruc'
                  ? 'Razón social o nombre'
                  : 'Nombre del cliente',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Ingresa el nombre para facturación.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            readOnly: !isEditing,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Ingresa el correo electrónico.';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Ingresa un correo válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            readOnly: !isEditing,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Número de teléfono',
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 7) return 'Ingresa un teléfono válido.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: documentType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de documento',
            ),
            items: const [
              DropdownMenuItem(
                value: 'cedula',
                child: Text('Cédula'),
              ),
              DropdownMenuItem(
                value: 'ruc',
                child: Text('RUC / Empresa'),
              ),
            ],
            onChanged: onDocumentTypeChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: documentController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: documentLabel,
              helperText: documentType == 'ruc'
                  ? 'Selecciona RUC si la compra es para empresa.'
                  : 'Por defecto se usa cédula para la compra.',
            ),
            validator: documentValidator,
          ),
        ],
      ),
    );
  }
}

class _HabitoBillingDetailsForm extends StatelessWidget {
  final bool isEditing;
  final String documentType;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController documentController;
  final VoidCallback onToggleEditing;
  final ValueChanged<String?> onDocumentTypeChanged;
  final String? Function(String?) documentValidator;

  const _HabitoBillingDetailsForm({
    required this.isEditing,
    required this.documentType,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.documentController,
    required this.onToggleEditing,
    required this.onDocumentTypeChanged,
    required this.documentValidator,
  });

  @override
  Widget build(BuildContext context) {
    final documentLabel =
        kIdentificationTypeLabels[documentType] ?? 'Documento';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Datos de facturacion',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleEditing,
                icon: Icon(
                  isEditing ? Icons.check_rounded : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(isEditing ? 'Listo' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: nameController,
            readOnly: !isEditing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: documentType == 'ruc'
                  ? 'Razon social o nombre'
                  : 'Nombre del cliente',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Ingresa el nombre para facturacion.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            readOnly: !isEditing,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electronico',
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Ingresa el correo electronico.';
              if (!text.contains('@') || !text.contains('.')) {
                return 'Ingresa un correo valido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            readOnly: !isEditing,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Numero de telefono',
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.length < 7) return 'Ingresa un telefono valido.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: documentType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de documento',
            ),
            items: const [
              DropdownMenuItem(
                value: 'cedula',
                child: Text('Cedula'),
              ),
              DropdownMenuItem(
                value: 'ruc',
                child: Text('RUC'),
              ),
              DropdownMenuItem(
                value: 'pasaporte',
                child: Text('Pasaporte'),
              ),
            ],
            onChanged: onDocumentTypeChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: documentController,
            keyboardType: documentType == 'pasaporte'
                ? TextInputType.text
                : TextInputType.number,
            decoration: InputDecoration(
              labelText: documentLabel,
              helperText: documentType == 'ruc'
                  ? 'Usa RUC si la compra es para empresa.'
                  : documentType == 'pasaporte'
                      ? 'Ingresa el numero de pasaporte.'
                      : 'Por defecto se usa cedula para la compra.',
            ),
            validator: documentValidator,
          ),
        ],
      ),
    );
  }
}

class _ShippingAddressForm extends StatelessWidget {
  final String selectedProvince;
  final String selectedCanton;
  final List<String> cantons;
  final TextEditingController addressController;
  final TextEditingController address2Controller;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onCantonChanged;

  const _ShippingAddressForm({
    required this.selectedProvince,
    required this.selectedCanton,
    required this.cantons,
    required this.addressController,
    required this.address2Controller,
    required this.onProvinceChanged,
    required this.onCantonChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos de envío',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedProvince,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Provincia',
            ),
            items: _ecuadorLocations.keys
                .map(
                  (province) => DropdownMenuItem(
                    value: province,
                    child: Text(province, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Selecciona la provincia.';
              }
              return null;
            },
            onChanged: onProvinceChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: cantons.contains(selectedCanton)
                ? selectedCanton
                : (cantons.isNotEmpty ? cantons.first : null),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cantón',
            ),
            items: cantons
                .map(
                  (canton) => DropdownMenuItem(
                    value: canton,
                    child: Text(canton, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Selecciona el cantón.';
              }
              return null;
            },
            onChanged: onCantonChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Dirección de entrega',
              hintText: 'Calle principal, numeración, sector',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Ingresa la dirección de entrega.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: address2Controller,
            decoration: const InputDecoration(
              labelText: 'Referencia',
              hintText: 'Casa, local, edificio o punto de referencia',
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPointsState {
  final bool enabled;
  final bool redeemEnabled;
  final bool redeemProductsEnabled;
  final bool redeemBookingsEnabled;
  final double balance;
  final double rate;
  final double minPoints;
  final double maxPercent;
  final String label;

  const _CheckoutPointsState({
    required this.enabled,
    required this.redeemEnabled,
    required this.redeemProductsEnabled,
    required this.redeemBookingsEnabled,
    required this.balance,
    required this.rate,
    required this.minPoints,
    required this.maxPercent,
    required this.label,
  });
}
