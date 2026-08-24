import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/ecuador_data.dart';
import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/validators/ecuador_id_validator.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/habito_bank_data_sheet.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../points/points_calculator.dart';
import '../../../points/provider/points_provider.dart';
import '../../data/services/habito_shop_api.dart';
import '../../models/cart_validation.dart';
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
  bool _isSubmittingCheckout = false;
  bool _usePoints = false;
  String _documentType = 'cedula';
  String _selectedProvince = 'Azuay';
  String _selectedCanton = 'Cuenca';
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
    _selectedProvince =
        kEcuadorProvinces.contains(user?.province) ? user!.province : 'Azuay';
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

  PointsRedemptionState _resolvePointsState(
    AuthProvider auth, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.resolveState(
      user: auth.user,
      summary: pointsProvider?.summary,
      reservedPoints: pointsProvider?.reservedPoints ?? 0,
    );
  }

  double _pointsToUse(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.calculate(
      state: _resolvePointsState(auth, pointsProvider),
      context: PointsRedemptionContext.order,
      total: total,
    ).pointsToUse;
  }

  double _pointsDiscount(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.calculate(
      state: _resolvePointsState(auth, pointsProvider),
      context: PointsRedemptionContext.order,
      total: total,
    ).discount;
  }

  Future<void> _loadPaymentMethods() async {
    final shop = context.read<ShopProvider>();
    await shop.loadPaymentMethods(forceRefresh: true);

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

  List<String> _missingCheckoutInfo(ShopFulfillmentMethod fulfillmentMethod) {
    final missing = <String>[];
    if (fulfillmentMethod == ShopFulfillmentMethod.pickup &&
        context.read<ShopProvider>().pickupLocationName.isEmpty) {
      missing.add('sucursal preferida de retiro');
    }
    return missing;
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
    final messenger = ScaffoldMessenger.of(context);
    final selectedPaymentMethod = _selectedPaymentMethod(shop.paymentMethods);
    final fulfillmentMethod = shop.fulfillmentMethod;

    if (_isSubmittingCheckout || shop.isCreatingOrder) return;

    final formState = _formKey.currentState;
    if (formState == null) {
      _showMissingCheckoutInfo([
        'espera a que se carguen los datos de facturacion',
      ]);
      return;
    }

    if (!formState.validate()) {
      _showMissingCheckoutInfo(['revisa los datos marcados en rojo']);
      return;
    }

    final missingInfo = _missingCheckoutInfo(fulfillmentMethod);
    if (missingInfo.isNotEmpty) {
      _showMissingCheckoutInfo(missingInfo);
      return;
    }

    if (!auth.isLoggedIn || auth.user == null || auth.token == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Inicia sesión para confirmar tu pedido.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingCheckout = true;
    });

    void stopSubmitting() {
      if (mounted) {
        setState(() {
          _isSubmittingCheckout = false;
        });
      }
    }

    try {
      final validation = await shop.validateCartForCheckout(
        token: auth.token!,
        fulfillmentMethod: fulfillmentMethod,
      );
      if (!mounted) return;
      if (validation.shouldInterruptCheckout) {
        if (_usePoints) {
          setState(() {
            _usePoints = false;
          });
        }
        stopSubmitting();
        await _showCartValidationDialog(validation);
        return;
      }
    } catch (e) {
      stopSubmitting();
      messenger.showSnackBar(
        SnackBar(content: Text(FriendlyErrors.checkout(e))),
      );
      return;
    }

    final orderTotal = shop.orderTotalFor(fulfillmentMethod);
    var redeemPoints = 0.0;
    var redeemDiscount = 0.0;
    String? pointsReservationId;

    if (_usePoints) {
      try {
        await pointsProvider.refresh();
        if (!mounted) return;

        final quote = await pointsProvider.quoteRedemption(
          context: 'order',
          amount: orderTotal,
        );

        if (!quote.canRedeem) {
          setState(() {
            _usePoints = false;
            _isSubmittingCheckout = false;
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                quote.message.isNotEmpty
                    ? quote.message
                    : 'Tus puntos ya no están disponibles para este pedido.',
              ),
            ),
          );
          return;
        }

        redeemPoints = quote.points;
        redeemDiscount = quote.discount;

        pointsReservationId = 'order-${DateTime.now().microsecondsSinceEpoch}';
        final reserved = pointsProvider.reserveRedemption(
          id: pointsReservationId,
          context: 'order',
          points: redeemPoints,
        );
        if (!reserved) {
          setState(() {
            _usePoints = false;
            _isSubmittingCheckout = false;
          });
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Ya hay un canje de puntos en proceso. Espera unos segundos e intenta nuevamente.',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        stopSubmitting();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              FriendlyErrors.points(e),
            ),
          ),
        );
        return;
      }
    }

    final pointsCoverTotal = redeemDiscount + 0.001 >= orderTotal;
    final payableTotal =
        (orderTotal - redeemDiscount).clamp(0, double.infinity).toDouble();

    if (!selectedPaymentMethod.canCreateManualOrder && !pointsCoverTotal) {
      if (pointsReservationId != null) {
        pointsProvider.releaseReservation(pointsReservationId);
      }
      stopSubmitting();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${selectedPaymentMethod.title} estará disponible pronto para pedidos desde la app.',
          ),
        ),
      );
      return;
    }

    final nameParts = _splitCustomerName(_billingNameController.text);
    Map<String, dynamic>? order;
    try {
      order = await shop.checkout(
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
        redeemAmount: redeemDiscount,
      );
    } catch (e) {
      if (pointsReservationId != null) {
        pointsProvider.releaseReservation(pointsReservationId);
      }
      if (!mounted) return;
      stopSubmitting();
      messenger.showSnackBar(
        SnackBar(content: Text(FriendlyErrors.checkout(e))),
      );
      return;
    }

    if (!mounted) {
      if (pointsReservationId != null) {
        pointsProvider.releaseReservation(pointsReservationId);
      }
      return;
    }

    if (order == null) {
      if (pointsReservationId != null) {
        pointsProvider.releaseReservation(pointsReservationId);
      }
      final error = FriendlyErrors.checkout(
        shop.checkoutError ?? 'No pudimos crear tu pedido.',
      );
      stopSubmitting();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          content: Text(error),
          action: SnackBarAction(
            label: 'Reiniciar carrito',
            onPressed: () {
              unawaited(
                  context.read<ShopProvider>().repairLocalCheckoutState());
            },
          ),
        ),
      );
      return;
    }

    if (redeemPoints > 0) {
      unawaited(auth.refreshProfile());
      unawaited(pointsProvider.refresh());
      if (pointsReservationId != null) {
        pointsProvider.releaseReservation(pointsReservationId);
      }
    }

    stopSubmitting();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu pedido fue creado correctamente.'),
      ),
    );

    final createdOrderId = _parseInt(order['id'] ?? order['order_id']);
    final orderNumber = _orderNumberFrom(order, fallbackId: createdOrderId);

    if (selectedPaymentMethod.isBankTransfer && payableTotal > 0.009) {
      await HabitoBankDataSheet.show(
        context,
        bankDetails: selectedPaymentMethod.bankDetails,
        orderNumber: orderNumber,
        amountLabel: _formatPrice(payableTotal),
      );
      if (!mounted) return;
    }

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

  String _orderNumberFrom(Map<String, dynamic> order, {int? fallbackId}) {
    final raw = order['number'] ??
        order['order_number'] ??
        order['orderNumber'] ??
        order['invoice_no'] ??
        order['id'] ??
        fallbackId;
    final text = raw?.toString().trim() ?? '';
    if (text.isNotEmpty) return '#$text';
    return 'reciente';
  }

  Future<void> _showCartValidationDialog(
    ShopCartValidationResult validation,
  ) async {
    final visibleItems = validation.visibleItems;
    final title = validation.canCheckout
        ? 'Tu carrito necesita actualizarse'
        : 'Revisa tu carrito antes de pagar';
    final message = validation.message.isNotEmpty
        ? validation.message
        : validation.canCheckout
            ? 'Actualizamos cantidades o precios con la información más reciente de la tienda. Revisa el nuevo total antes de confirmar.'
            : 'Algunos productos ya no están disponibles para finalizar el pedido.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (visibleItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ...visibleItems.map(_CartValidationItemTile.new),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                validation.canCheckout
                    ? 'Revisar totales actualizados'
                    : 'Entendido',
              ),
            ),
          ],
        );
      },
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
        final isSubmittingCheckout =
            _isSubmittingCheckout || shop.isCreatingOrder;
        final shippingTotal = shop.shippingTotalFor(fulfillmentMethod);
        final orderTotal = shop.orderTotalFor(fulfillmentMethod);
        final pointsToUse = _pointsToUse(auth, orderTotal, pointsProvider);
        final projectedPointsDiscount =
            _pointsDiscount(auth, orderTotal, pointsProvider);
        final pointsDiscount = _usePoints ? projectedPointsDiscount : 0.0;
        final payableTotal =
            (orderTotal - pointsDiscount).clamp(0, double.infinity).toDouble();
        final canTogglePoints =
            !isSubmittingCheckout && !pointsProvider.hasPointsReservation;
        final projectedPayableTotal = (orderTotal - projectedPointsDiscount)
            .clamp(0, double.infinity)
            .toDouble();
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
                const SizedBox(height: AppSpacing.lg),
              ],
              _CheckoutSummaryHeader(
                itemCount: shop.cartCount,
                total: _formatPrice(orderTotal),
                deliveryLabel: fulfillmentMethod.title,
                deliveryValue: _formatShipping(shippingTotal),
              ),
              const SizedBox(height: AppSpacing.md),
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
                            const SizedBox(width: AppSpacing.md),
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
                    const Divider(height: AppSpacing.divider),
                    _CheckoutRow(
                      label: 'Productos',
                      value: _formatPrice(shop.subtotal),
                    ),
                    if (shop.hasIvaBreakdown) ...[
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                      _CheckoutRow(
                        label: taxLabel,
                        value: _formatPrice(shop.taxTotal),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    _CheckoutRow(
                      label: fulfillmentMethod.title,
                      value: _formatShipping(shippingTotal),
                    ),
                    const Divider(height: AppSpacing.divider),
                    if (pointsDiscount > 0) ...[
                      _CheckoutRow(
                        label: 'Descuento por puntos',
                        value: '-${_formatPrice(pointsDiscount)}',
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    ],
                    _CheckoutRow(
                      label: 'Total',
                      value: _formatPrice(payableTotal),
                      highlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              if (pointsToUse > 0) ...[
                _PointsRedeemTile(
                  enabled: _usePoints,
                  pointsLabel: pointsState.label,
                  points: pointsToUse,
                  discount: projectedPointsDiscount,
                  total: orderTotal,
                  payableTotal: projectedPayableTotal,
                  balance: pointsState.balance,
                  interactive: canTogglePoints,
                  onChanged: (value) {
                    setState(() {
                      _usePoints = value;
                    });
                  },
                  formatPrice: _formatPrice,
                ),
                const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              ],
              _SectionHeader(
                title: 'Entrega',
                subtitle:
                    'Elige si prefieres recibir el pedido o retirarlo en tienda.',
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
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
                      const SizedBox(height: AppSpacing.md),
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
                      const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
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
                          return EcuadorIdValidator.validate(
                            identificationType: _documentType,
                            value: value,
                            emptyMessage:
                                'Ingresa tu ${kIdentificationTypeLabels[_documentType] ?? 'documento'}.',
                          );
                        },
                      ),
                      if (fulfillmentMethod ==
                          ShopFulfillmentMethod.delivery) ...[
                        const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
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
                        const SizedBox(height: AppSpacing.md),
                        _PickupLocationSelector(
                          locationName: shop.pickupLocationName,
                          selectedPickupLocation: shop.pickupLocation,
                          pickupLocations: _pickupLocations,
                          isLoadingLocations: _isLoadingPickupLocations,
                          onSelectPickupLocation: (location) =>
                              _handlePickupLocationSelection(shop, location),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _noteController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: 3,
                        maxLength: FormValidators.longTextMaxLength,
                        decoration: const InputDecoration(
                          labelText: 'Nota del pedido',
                          hintText: 'Indicaciones adicionales o referencia',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              _SectionHeader(
                title: 'Pago',
                subtitle: 'Selecciona la forma de confirmar este pedido.',
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
              _CheckoutCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shop.isLoadingPaymentMethods) ...[
                      const LinearProgressIndicator(
                        minHeight: AppSpacing.progress,
                        color: AppColors.secondary,
                        backgroundColor: AppColors.goldMuted,
                      ),
                      const SizedBox(height: AppSpacing.md + AppSpacing.xs),
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
                      const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                    ],
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.large,
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.goldDeep,
                          ),
                          SizedBox(width: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
              SizedBox(
                height: AppSpacing.actionHeight,
                child: ElevatedButton(
                  onPressed: isSubmittingCheckout ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.large,
                    ),
                  ),
                  child: isSubmittingCheckout
                      ? const SizedBox(
                          width: AppIconSize.spinner,
                          height: AppIconSize.spinner,
                          child: CircularProgressIndicator(
                            strokeWidth: AppSpacing.progressStroke,
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
  final double total;
  final double payableTotal;
  final double balance;
  final bool interactive;
  final ValueChanged<bool> onChanged;
  final String Function(double value) formatPrice;

  const _PointsRedeemTile({
    required this.enabled,
    required this.pointsLabel,
    required this.points,
    required this.discount,
    required this.total,
    required this.payableTotal,
    required this.balance,
    this.interactive = true,
    required this.onChanged,
    required this.formatPrice,
  });

  String _formatPoints(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final pointsText = _formatPoints(points);
    final balanceText = _formatPoints(balance);
    final isFullPayment = payableTotal <= 0.009;
    final statusLabel = enabled ? 'Descuento activo' : 'Activar descuento';
    final textTheme = Theme.of(context).textTheme;

    return _CheckoutCard(
      child: InkWell(
        onTap: interactive ? () => onChanged(!enabled) : null,
        borderRadius: AppRadius.card,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.goldSurface : AppColors.surfaceMuted,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: enabled ? AppColors.secondary : AppColors.border,
              width: enabled ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppIconSize.pointsBadge,
                    height: AppIconSize.pointsBadge,
                    decoration: BoxDecoration(
                      color:
                          enabled ? AppColors.secondary : AppColors.goldMuted,
                      borderRadius: AppRadius.medium,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: enabled ? Colors.white : AppColors.goldDeep,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usar $pointsLabel',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.progress),
                        Text(
                          '$pointsText de $balanceText puntos disponibles',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    statusLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: enabled
                          ? AppColors.goldDeep
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    activeThumbColor: AppColors.secondary,
                    activeTrackColor: AppColors.goldSoft,
                    onChanged: interactive ? onChanged : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 430;
                  final metricWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 3;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PointsCheckoutMetric(
                        width: metricWidth,
                        label: 'Ahorras',
                        value: formatPrice(discount),
                        valueColor: AppColors.success,
                      ),
                      _PointsCheckoutMetric(
                        width: metricWidth,
                        label: enabled ? 'Pagaras' : 'Pagarias',
                        value: formatPrice(payableTotal),
                        valueColor: isFullPayment
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                      _PointsCheckoutMetric(
                        width: metricWidth,
                        label: 'Total original',
                        value: formatPrice(total),
                        valueColor: AppColors.textSecondary,
                      ),
                    ],
                  );
                },
              ),
              if (isFullPayment) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Con este canje el pedido queda cubierto al 100%.',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsCheckoutMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color valueColor;

  const _PointsCheckoutMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.medium,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
                  'Resumen',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _CheckoutInfoPill(label: total, dark: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              _CheckoutInfoPill(label: productLabel),
              const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
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
    );
  }
}

class _CartValidationItemTile extends StatelessWidget {
  final ShopCartValidationItem item;

  const _CartValidationItemTile(this.item);

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (item.removed)
        'Producto retirado del carrito'
      else if (item.hasQuantityChanged)
        'Cantidad: ${item.requestedQuantity} -> ${item.finalQuantity}',
      if (item.hasPriceChanged)
        'Precio: ${_formatCurrency(item.oldUnitPrice!)} -> ${_formatCurrency(item.newUnitPrice!)}',
      if (item.availableQuantity != null && !item.removed)
        'Disponible: ${item.availableQuantity}',
      if (item.message.isNotEmpty) item.message,
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: item.isBlocking ? AppColors.dangerSoft : AppColors.goldMuted,
        borderRadius: AppRadius.large,
        border: Border.all(
          color: item.isBlocking ? AppColors.danger : AppColors.goldSoft,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isBlocking
                ? Icons.error_outline_rounded
                : Icons.sync_alt_rounded,
            color: item.isBlocking ? AppColors.danger : AppColors.goldDeep,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    details.join('\n'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
        borderRadius: AppRadius.extraLarge,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardSoft,
      ),
      child: child,
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;

  const _CheckoutRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
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
            color: valueColor ?? AppColors.textPrimary,
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
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: AppColors.goldDeep,
          ),
          const SizedBox(width: AppSpacing.md),
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
      borderRadius: AppRadius.large,
      child: Container(
        padding: const EdgeInsets.all(15),
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
            Container(
              width: AppIconSize.optionBadge,
              height: AppIconSize.optionBadge,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.medium,
              ),
              child: Icon(icon,
                  color: AppColors.goldSoft, size: AppIconSize.spinner),
            ),
            const SizedBox(width: AppSpacing.md),
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
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
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
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.goldDeep),
              const SizedBox(width: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            const LinearProgressIndicator(
              minHeight: AppSpacing.progress,
              color: AppColors.secondary,
              backgroundColor: AppColors.goldMuted,
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
      borderRadius: AppRadius.large,
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
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
                selected
                    ? Icons.radio_button_checked
                    : enabled
                        ? Icons.radio_button_off_outlined
                        : Icons.lock_outline_rounded,
                color: selected ? AppColors.secondary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
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
                        const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.goldSoft.withValues(
                              alpha: 0.24,
                            ),
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            badgeText,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.goldDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
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
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.large,
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
                  size: AppIconSize.action,
                ),
                label: Text(isEditing ? 'Listo' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          TextFormField(
            controller: nameController,
            readOnly: !isEditing,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: documentType == 'ruc'
                ? const [AutofillHints.organizationName]
                : const [AutofillHints.name],
            maxLength: FormValidators.longTextMaxLength,
            decoration: InputDecoration(
              labelText: documentType == 'ruc'
                  ? 'Razón social o nombre'
                  : 'Nombre del cliente',
            ),
            validator: (value) => FormValidators.requiredMaxLength(
              value,
              field: 'el nombre para facturación',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: emailController,
            readOnly: !isEditing,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
            ),
            validator: FormValidators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: phoneController,
            readOnly: !isEditing,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Número de teléfono',
            ),
            validator: FormValidators.phone,
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: documentController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username],
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
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.large,
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
                  size: AppIconSize.action,
                ),
                label: Text(isEditing ? 'Listo' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          TextFormField(
            controller: nameController,
            readOnly: !isEditing,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: documentType == 'ruc'
                ? const [AutofillHints.organizationName]
                : const [AutofillHints.name],
            maxLength: FormValidators.longTextMaxLength,
            decoration: InputDecoration(
              labelText: documentType == 'ruc'
                  ? 'Razón social o nombre'
                  : 'Nombre del cliente',
            ),
            validator: (value) => FormValidators.requiredMaxLength(
              value,
              field: 'el nombre para facturación',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: emailController,
            readOnly: !isEditing,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
            ),
            validator: FormValidators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: phoneController,
            readOnly: !isEditing,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Número de teléfono',
            ),
            validator: FormValidators.phone,
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
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
                child: Text('RUC'),
              ),
              DropdownMenuItem(
                value: 'pasaporte',
                child: Text('Pasaporte'),
              ),
            ],
            onChanged: onDocumentTypeChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: documentController,
            keyboardType: documentType == 'pasaporte'
                ? TextInputType.text
                : TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(
              labelText: documentLabel,
              helperText: documentType == 'ruc'
                  ? 'Usa RUC si la compra es para empresa.'
                  : documentType == 'pasaporte'
                      ? 'Ingresa el número de pasaporte.'
                      : 'Por defecto se usa cédula para la compra.',
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
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.large,
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
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: addressController,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.fullStreetAddress],
            maxLength: FormValidators.longTextMaxLength,
            decoration: const InputDecoration(
              labelText: 'Dirección de entrega',
              hintText: 'Calle principal, numeración, sector',
            ),
            validator: (value) => FormValidators.requiredMaxLength(
              value,
              field: 'la dirección de entrega',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: address2Controller,
            keyboardType: TextInputType.streetAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.fullStreetAddress],
            maxLength: FormValidators.longTextMaxLength,
            decoration: const InputDecoration(
              labelText: 'Referencia',
              hintText: 'Casa, local, edificio o punto de referencia',
            ),
            validator: (value) => FormValidators.maxLength(
              value,
              max: FormValidators.longTextMaxLength,
              field: 'la referencia',
            ),
          ),
        ],
      ),
    );
  }
}
