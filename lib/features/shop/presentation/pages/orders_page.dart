import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../../shared/widgets/habito_payment_proof_picker.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../provider/shop_provider.dart';
import 'cart_page.dart';
import 'products_archive_page.dart';

class OrdersPage extends StatefulWidget {
  final int selectedNavIndex;
  final int? initialOrderId;
  final bool openFromPush;

  const OrdersPage({
    super.key,
    this.selectedNavIndex = 4,
    this.initialOrderId,
    this.openFromPush = false,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _orderCardKeys = <int, GlobalKey>{};

  int? _highlightedOrderId;
  bool _didFocusInitialOrder = false;
  _OrdersFilter _selectedFilter = _OrdersFilter.all;

  @override
  void initState() {
    super.initState();
    _highlightedOrderId = _normalizedInitialOrderId;
    Future.microtask(() => _loadOrders(forceRefresh: true));
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOrderId != widget.initialOrderId) {
      _didFocusInitialOrder = false;
      _highlightedOrderId = _normalizedInitialOrderId;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int? get _normalizedInitialOrderId {
    final orderId = widget.initialOrderId;
    if (orderId == null || orderId <= 0) return null;
    return orderId;
  }

  Future<void> _loadOrders({bool forceRefresh = false}) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn || auth.token == null) return;
    await context.read<ShopProvider>().loadOrders(
          token: auth.token!,
          forceRefresh: forceRefresh,
        );
  }

  Future<void> _selectAndUploadPaymentProof(Map<String, dynamic> order) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final orderId = _parseInt(order['id']);

    if (token == null || token.trim().isEmpty || orderId <= 0) {
      _showSnack('No pudimos identificar el pedido.');
      return;
    }

    final selectedProof = await HabitoPaymentProofPicker.pickAndConfirm(
      context,
      showMessage: _showSnack,
    );

    if (selectedProof == null) return;
    if (!mounted) return;

    final ok = await context.read<ShopProvider>().uploadPaymentProof(
          token: token,
          orderId: orderId,
          filePath: selectedProof.path,
        );

    if (!mounted) return;

    if (ok) {
      _showSnack('Comprobante recibido. Lo validaremos muy pronto.');
      return;
    }

    _showSnack(
      FriendlyErrors.paymentProof(
        context.read<ShopProvider>().paymentProofError ??
            'No pudimos subir el comprobante.',
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  GlobalKey _keyForOrder(int orderId) {
    return _orderCardKeys.putIfAbsent(orderId, GlobalKey.new);
  }

  void _focusInitialOrderIfNeeded(List<Map<String, dynamic>> orders) {
    final targetOrderId = _normalizedInitialOrderId;
    if (_didFocusInitialOrder || targetOrderId == null) return;

    _didFocusInitialOrder = true;
    final orderExists =
        orders.any((order) => _parseInt(order['id']) == targetOrderId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!orderExists) {
        _showSnack(
            'No encontramos el pedido #$targetOrderId en tu historial actual.');
        return;
      }

      _focusOrder(targetOrderId);
    });
  }

  Future<void> _focusOrder(int orderId) async {
    final key = _orderCardKeys[orderId];
    final contextForCard = key?.currentContext;

    if (contextForCard != null) {
      await Scrollable.ensureVisible(
        contextForCard,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    } else if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }

    if (!mounted) return;
    setState(() {
      _highlightedOrderId = orderId;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _highlightedOrderId != orderId) return;
      setState(() {
        _highlightedOrderId = null;
      });
    });
  }

  String _formatMoney(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed == parsed.roundToDouble()) {
      return '\$${parsed.toStringAsFixed(0)}';
    }
    return '\$${parsed.toStringAsFixed(2)}';
  }

  String _statusKey(Map<String, dynamic> order) {
    final raw = [
      order['status_normalized'],
      order['status'],
      order['status_raw'],
    ]
        .map((value) => value?.toString().trim().toLowerCase() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'pending');

    switch (raw) {
      case 'canceled':
        return 'cancelled';
      default:
        return raw;
    }
  }

  Color _statusColor(Map<String, dynamic> order) {
    switch (_statusKey(order)) {
      case 'completed':
        return AppColors.success;
      case 'processing':
        return AppColors.successDeep;
      case 'cancelled':
        return AppColors.danger;
      case 'failed':
        return AppColors.warningDeep;
      case 'refunded':
        return AppColors.textSecondary;
      case 'on-hold':
      case 'pending':
        return AppColors.goldDeep;
      default:
        return AppColors.goldDeep;
    }
  }

  String _statusLabel(Map<String, dynamic> order) {
    final display = (order['status_display'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    switch (_statusKey(order)) {
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
      case 'refunded':
        return 'Reembolsado';
      case 'failed':
        return 'Pago fallido';
      default:
        final raw =
            (order['status_raw'] ?? order['status'] ?? '').toString().trim();
        return raw.isNotEmpty ? raw : 'Pendiente';
    }
  }

  String _statusDescription(Map<String, dynamic> order) {
    final description = (order['status_description'] ?? '').toString().trim();
    if (description.isNotEmpty) return description;

    switch (_statusKey(order)) {
      case 'pending':
        return 'Tu pedido está pendiente de pago o confirmación inicial.';
      case 'on-hold':
        return 'Estamos validando el pago o revisando los datos del pedido.';
      case 'processing':
        return 'Tu compra ya entró en preparación.';
      case 'completed':
        return 'El pedido ya fue completado.';
      case 'cancelled':
        return 'El pedido fue cancelado.';
      case 'refunded':
        return 'El pedido ya fue reembolsado.';
      case 'failed':
        return 'No se pudo procesar el pago de este pedido.';
      default:
        return 'Estamos actualizando el estado de tu pedido.';
    }
  }

  String _formatOrderDate(Map<String, dynamic> order) {
    final display = (order['date_created_display'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    final raw = (order['date_created'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    return raw.split('T').first.split(' ').first;
  }

  String _statusLifecycle(Map<String, dynamic> order) {
    final lifecycle =
        (order['status_lifecycle'] ?? '').toString().trim().toLowerCase();
    if (lifecycle.isNotEmpty) return lifecycle;

    switch (_statusKey(order)) {
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

  List<Map<String, dynamic>> _filteredOrders(
      List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      switch (_selectedFilter) {
        case _OrdersFilter.all:
          return true;
        case _OrdersFilter.active:
          return _isActiveOrder(order);
        case _OrdersFilter.completed:
          return _statusKey(order) == 'completed';
        case _OrdersFilter.closed:
          return _isClosedOrder(order);
      }
    }).toList();
  }

  int _countForFilter(List<Map<String, dynamic>> orders, _OrdersFilter filter) {
    return orders.where((order) {
      switch (filter) {
        case _OrdersFilter.all:
          return true;
        case _OrdersFilter.active:
          return _isActiveOrder(order);
        case _OrdersFilter.completed:
          return _statusKey(order) == 'completed';
        case _OrdersFilter.closed:
          return _isClosedOrder(order);
      }
    }).length;
  }

  bool _isActiveOrder(Map<String, dynamic> order) {
    final status = _statusKey(order);
    return status == 'pending' || status == 'on-hold' || status == 'processing';
  }

  bool _isClosedOrder(Map<String, dynamic> order) {
    final status = _statusKey(order);
    return status == 'cancelled' || status == 'failed' || status == 'refunded';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ShopProvider>(
      builder: (context, auth, shop, _) {
        final visibleOrders = _filteredOrders(shop.orders);
        if (!shop.isLoadingOrders && shop.ordersError == null) {
          _focusInitialOrderIfNeeded(shop.orders);
        }

        if (!auth.isLoggedIn) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppTopHeader(
              searchHint: 'Buscar productos',
              cartCount: shop.cartCount,
              onSearchTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductsArchivePage(),
                  ),
                );
              },
              onCartTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
            ),
            bottomNavigationBar: HabitoBottomNavigationBar(
              selectedIndex: widget.selectedNavIndex,
              onDestinationSelected: _goToMainTab,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.display,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 52,
                        color: AppColors.goldDeep,
                      ),
                      const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                      const Text(
                        'Inicia sesión para ver tus pedidos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTextSize.headlineMedium,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                      const Text(
                        'Aquí verás el historial completo de compras realizadas en la tienda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.pushNamed(
                              context,
                              AppRoutes.login,
                            );

                            if (!context.mounted) return;
                            final currentAuth = context.read<AuthProvider>();
                            if (currentAuth.isLoggedIn &&
                                currentAuth.token != null) {
                              await _loadOrders(forceRefresh: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.tile,
                            ),
                          ),
                          child: const Text(
                            'Iniciar sesión',
                            style: TextStyle(fontWeight: FontWeight.w800),
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppTopHeader(
            searchHint: 'Buscar productos',
            cartCount: shop.cartCount,
            onSearchTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductsArchivePage(),
                ),
              );
            },
            onCartTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
          bottomNavigationBar: HabitoBottomNavigationBar(
            selectedIndex: widget.selectedNavIndex,
            onDestinationSelected: _goToMainTab,
          ),
          body: RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: () => _loadOrders(forceRefresh: true),
            child: shop.isLoadingOrders && shop.orders.isEmpty
                ? ListView(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    children: const [
                      HabitoLoadingShimmer(
                        itemCount: 4,
                        itemHeight: 138,
                      ),
                    ],
                  )
                : shop.ordersError != null && shop.orders.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          HabitoErrorState(
                            title: 'No pudimos cargar tus pedidos',
                            message: shop.ordersError!,
                            onRetry: () => _loadOrders(forceRefresh: true),
                          ),
                        ],
                      )
                    : shop.orders.isEmpty
                        ? ListView(
                            padding: EdgeInsets.all(AppSpacing.xl),
                            children: const [
                              SizedBox(
                                  height: AppSpacing.xxxl +
                                      AppSpacing.xl -
                                      AppSpacing.xs),
                              HabitoEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'Todavía no tienes pedidos',
                                message:
                                    'Cuando completes una compra en la tienda, aparecerán aquí todos los detalles.',
                              ),
                            ],
                          )
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              _OrdersHero(totalOrders: shop.orders.length),
                              if (_highlightedOrderId != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                _FocusedOrderBanner(
                                  orderId: _highlightedOrderId!,
                                  openedFromPush: widget.openFromPush,
                                ),
                              ],
                              const SizedBox(
                                  height: AppSpacing.xl - AppSpacing.xxs),
                              _OrdersHeader(
                                visibleCount: visibleOrders.length,
                                totalCount: shop.orders.length,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _OrdersFiltersRow(
                                selectedFilter: _selectedFilter,
                                counts: {
                                  for (final filter in _OrdersFilter.values)
                                    filter:
                                        _countForFilter(shop.orders, filter),
                                },
                                onSelected: (filter) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                              ),
                              const SizedBox(
                                  height: AppSpacing.md + AppSpacing.xxs),
                              if (visibleOrders.isEmpty)
                                _FilteredOrdersEmptyView(
                                  filter: _selectedFilter,
                                )
                              else
                                ...visibleOrders.map(
                                  (order) => Padding(
                                    key: _keyForOrder(_parseInt(order['id'])),
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _OrderCard(
                                      order: order,
                                      highlighted: _parseInt(order['id']) ==
                                          _highlightedOrderId,
                                      isUploadingProof:
                                          shop.isUploadingPaymentProof(
                                        _parseInt(order['id']),
                                      ),
                                      onUploadProof: () =>
                                          _selectAndUploadPaymentProof(order),
                                      statusColor: _statusColor,
                                      statusLabel: _statusLabel,
                                      statusDescription: _statusDescription,
                                      statusLifecycle: _statusLifecycle,
                                      formatDate: _formatOrderDate,
                                      formatMoney: _formatMoney,
                                    ),
                                  ),
                                ),
                            ],
                          ),
          ),
        );
      },
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum _OrdersFilter {
  all,
  active,
  completed,
  closed,
}

extension _OrdersFilterInfo on _OrdersFilter {
  String get label {
    switch (this) {
      case _OrdersFilter.all:
        return 'Todos';
      case _OrdersFilter.active:
        return 'Activos';
      case _OrdersFilter.completed:
        return 'Completados';
      case _OrdersFilter.closed:
        return 'Cancelados / Reembolsados';
    }
  }

  String get emptyTitle {
    switch (this) {
      case _OrdersFilter.all:
        return 'Sin pedidos por ahora';
      case _OrdersFilter.active:
        return 'Sin pedidos activos';
      case _OrdersFilter.completed:
        return 'Sin pedidos completados';
      case _OrdersFilter.closed:
        return 'Sin pedidos cerrados';
    }
  }

  String get emptyMessage {
    switch (this) {
      case _OrdersFilter.all:
        return 'Cuando completes una compra en la tienda, la verás aquí con todo su detalle.';
      case _OrdersFilter.active:
        return 'Aquí aparecerán los pedidos pendientes, en validación o en preparación.';
      case _OrdersFilter.completed:
        return 'Aqui se guardan las compras que ya terminaron correctamente.';
      case _OrdersFilter.closed:
        return 'Aquí verás pedidos cancelados, fallidos o reembolsados.';
    }
  }
}

class _OrdersHero extends StatelessWidget {
  final int totalOrders;

  const _OrdersHero({required this.totalOrders});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.display,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: AppRadius.full,
            ),
            child: const Text(
              'Historial Habito',
              style: TextStyle(
                color: AppColors.borderStrong,
                fontSize: AppTextSize.label,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Tu historial de compras en una vista clara y elegante.',
            style: TextStyle(
              color: Colors.white,
              fontSize: AppTextSize.headlineSmall,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          const Text(
            'Sigue el estado de cada pedido y revisa rapidamente los productos comprados.',
            style: TextStyle(
              color: AppColors.border,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: AppRadius.card,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pedidos registrados',
                    style: TextStyle(
                      color: AppColors.border,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$totalOrders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.headlineMedium,
                    fontWeight: FontWeight.w900,
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

class _OrdersHeader extends StatelessWidget {
  final int visibleCount;
  final int totalCount;

  const _OrdersHeader({
    required this.visibleCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pedidos recientes',
          style: TextStyle(
            fontSize: AppTextSize.headlineSmall,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          totalCount == 0
              ? 'Desliza hacia abajo para actualizar el estado en tiempo real.'
              : '$visibleCount de $totalCount pedido(s) visibles en esta vista.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _OrdersFiltersRow extends StatelessWidget {
  final _OrdersFilter selectedFilter;
  final Map<_OrdersFilter, int> counts;
  final ValueChanged<_OrdersFilter> onSelected;

  const _OrdersFiltersRow({
    required this.selectedFilter,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _OrdersFilter.values.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
        itemBuilder: (context, index) {
          final filter = _OrdersFilter.values[index];
          final isSelected = filter == selectedFilter;
          final count = counts[filter] ?? 0;

          return ChoiceChip(
            label: Text('${filter.label} ($count)'),
            selected: isSelected,
            onSelected: (_) => onSelected(filter),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.full,
            ),
          );
        },
      ),
    );
  }
}

class _FilteredOrdersEmptyView extends StatelessWidget {
  final _OrdersFilter filter;

  const _FilteredOrdersEmptyView({
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.hero,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 46,
            color: AppColors.goldDeep,
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          Text(
            filter.emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppTextSize.section,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            filter.emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool highlighted;
  final Color Function(Map<String, dynamic> order) statusColor;
  final String Function(Map<String, dynamic> order) statusLabel;
  final String Function(Map<String, dynamic> order) statusDescription;
  final String Function(Map<String, dynamic> order) statusLifecycle;
  final String Function(Map<String, dynamic> order) formatDate;
  final String Function(dynamic value) formatMoney;
  final bool isUploadingProof;
  final VoidCallback onUploadProof;

  const _OrderCard({
    required this.order,
    required this.highlighted,
    required this.statusColor,
    required this.statusLabel,
    required this.statusDescription,
    required this.statusLifecycle,
    required this.formatDate,
    required this.formatMoney,
    required this.isUploadingProof,
    required this.onUploadProof,
  });

  @override
  Widget build(BuildContext context) {
    final currentStatusColor = statusColor(order);
    final currentStatusLabel = statusLabel(order);
    final currentStatusDescription = statusDescription(order);
    final currentLifecycle = statusLifecycle(order);
    final lineItems = order['line_items'] is List
        ? List<dynamic>.from(order['line_items'])
        : const <dynamic>[];
    final paymentTitle = _firstNonEmpty([
      order['payment_title']?.toString(),
      order['payment_method_title']?.toString(),
    ]);
    final paymentMethod = _firstNonEmpty([
      order['payment_method']?.toString(),
      order['paymentMethod']?.toString(),
    ]).toLowerCase();
    final paymentProof = _asMap(order['payment_proof']);
    final proofUrl = (paymentProof['url'] ?? '').toString().trim();
    final proofUploaded =
        paymentProof['uploaded'] == true || proofUrl.isNotEmpty;
    final isBankTransfer = paymentMethod == 'bacs' ||
        paymentTitle.toLowerCase().contains('transfer');
    final canUploadProof =
        isBankTransfer && !proofUploaded && !_isClosedStatus(order);
    final fulfillmentMethod =
        (order['fulfillment_method'] ?? '').toString().trim().toLowerCase();
    final fulfillmentDisplay = _firstNonEmpty([
      order['fulfillment_display']?.toString(),
      fulfillmentMethod == 'pickup' ? 'Retiro en tienda' : 'Envio local',
    ]);
    final pickupLocationName = _firstNonEmpty([
      order['pickup_location_name']?.toString(),
      order['pickupLocationName']?.toString(),
    ]);
    final shippingLines = order['shipping_lines'] is List
        ? List<dynamic>.from(order['shipping_lines'])
        : const <dynamic>[];
    final firstShippingLine = shippingLines.whereType<Map>().isNotEmpty
        ? _asMap(shippingLines.whereType<Map>().first)
        : <String, dynamic>{};
    final shippingTitle = _firstNonEmpty([
      firstShippingLine['method_title']?.toString(),
      firstShippingLine['methodTitle']?.toString(),
      firstShippingLine['name']?.toString(),
    ]);
    final shippingTotal = _firstNonEmpty([
      order['shipping_total']?.toString(),
      order['shippingTotal']?.toString(),
    ]);
    final totalTax = _firstNonEmpty([
      order['total_tax']?.toString(),
      order['totalTax']?.toString(),
    ]);
    final hasTax = (double.tryParse(totalTax) ?? 0) > 0;
    final lifecycleColor = _lifecycleColor(
      currentLifecycle,
      fallback: currentStatusColor,
    );
    final lifecycleLabel = _lifecycleLabel(currentLifecycle);
    final proofStatusLabel = isBankTransfer
        ? (proofUploaded ? 'Recibido' : 'Pendiente')
        : 'No requerido';
    final paymentSummary =
        paymentTitle.isNotEmpty ? paymentTitle : 'Por definir';
    final dispatchAssignmentStatus = _firstNonEmpty([
      order['dispatch_assignment_status']?.toString(),
      order['dispatchAssignmentStatus']?.toString(),
    ]).toLowerCase();
    final assignedWarehouseName = _firstNonEmpty([
      order['assigned_warehouse_name']?.toString(),
      order['assignedWarehouseName']?.toString(),
    ]);
    final assignedWarehouseCode = _firstNonEmpty([
      order['assigned_warehouse_code']?.toString(),
      order['assignedWarehouseCode']?.toString(),
    ]);
    final assignedWarehouseLabel = assignedWarehouseName.isNotEmpty
        ? assignedWarehouseCode.isNotEmpty
            ? '$assignedWarehouseName ($assignedWarehouseCode)'
            : assignedWarehouseName
        : '';
    final dispatchPendingReason = _dispatchPendingReason(
      _firstNonEmpty([
        order['dispatch_pending_reason']?.toString(),
        order['dispatchPendingReason']?.toString(),
      ]),
    );
    final dispatchLabel = _dispatchLabel(
      dispatchAssignmentStatus,
      fulfillmentMethod: fulfillmentMethod,
      assignedWarehouseLabel: assignedWarehouseLabel,
    );
    final dispatchBadgeColor = _dispatchBadgeColor(
      dispatchAssignmentStatus,
      fulfillmentMethod: fulfillmentMethod,
    );
    final totalItemsCount = lineItems.fold<int>(
      0,
      (total, line) => total + _parseInt(line['quantity']),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.goldSurface : Colors.white,
        borderRadius: AppRadius.extraLarge,
        border: Border.all(
          color: highlighted ? AppColors.secondary : AppColors.border,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: highlighted ? AppShadows.goldGlow : AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: AppRadius.full,
              ),
              child: const Text(
                'Pedido destacado',
                style: TextStyle(
                  color: AppColors.goldDeep,
                  fontSize: AppTextSize.labelSmall,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${order['number'] ?? order['id'] ?? ''}',
                      style: const TextStyle(
                        fontSize: AppTextSize.titleLarge,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs / 2),
                    Text(
                      formatDate(order),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (currentStatusDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                      Text(
                        currentStatusDescription,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: currentStatusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  currentStatusLabel,
                  style: TextStyle(
                    color: currentStatusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OrderMetaBadge(
                label: lifecycleLabel,
                background: lifecycleColor.withValues(alpha: 0.12),
                foreground: lifecycleColor,
              ),
              _OrderMetaBadge(
                label: fulfillmentDisplay,
                background: AppColors.goldMuted,
                foreground: AppColors.goldDeep,
              ),
              if (totalItemsCount > 0)
                _OrderMetaBadge(
                  label: '$totalItemsCount item(s)',
                  background: AppColors.surfaceMuted,
                  foreground: AppColors.textPrimary,
                ),
              if (dispatchLabel.isNotEmpty)
                _OrderMetaBadge(
                  label: dispatchLabel,
                  background: dispatchBadgeColor.withValues(alpha: 0.12),
                  foreground: dispatchBadgeColor,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...lineItems.take(3).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line['quantity'] ?? 1} x ${line['name'] ?? 'Producto'}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        formatMoney(line['total']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (lineItems.length > 3) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '+ ${lineItems.length - 3} producto(s) mas',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(height: AppSpacing.divider),
          _OrderInfoRow(
            label: 'Entrega',
            value: fulfillmentDisplay,
          ),
          if (pickupLocationName.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Sucursal',
              value: pickupLocationName,
            ),
          ],
          if (assignedWarehouseLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: fulfillmentMethod == 'pickup' ? 'Bodega retiro' : 'Bodega',
              value: assignedWarehouseLabel,
            ),
          ],
          if (dispatchLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Despacho',
              value: dispatchLabel,
            ),
          ],
          if (dispatchPendingReason.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Observacion',
              value: dispatchPendingReason,
            ),
          ],
          if (shippingTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Metodo',
              value: shippingTitle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          _OrderInfoRow(
            label: 'Costo de entrega',
            value: formatMoney(shippingTotal),
          ),
          if (hasTax) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'IVA',
              value: formatMoney(totalTax),
            ),
          ],
          if (paymentTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Pago',
              value: paymentSummary,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            _OrderInfoRow(
              label: 'Pago',
              value: paymentSummary,
            ),
          ],
          const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
          _OrderInfoRow(
            label: 'Comprobante',
            value: proofStatusLabel,
          ),
          if (isBankTransfer) ...[
            const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
            _PaymentProofPanel(
              uploaded: proofUploaded,
              uploadedAt: (paymentProof['uploaded_at'] ?? '').toString(),
              isUploading: isUploadingProof,
              canUpload: canUploadProof,
              onUpload: onUploadProof,
            ),
          ],
          const Divider(height: AppSpacing.divider),
          _OrderInfoRow(
            label: 'Total',
            value: formatMoney(order['total']),
            highlight: true,
          ),
        ],
      ),
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _lifecycleLabel(String lifecycle) {
    switch (lifecycle) {
      case 'active':
        return 'En curso';
      case 'completed':
        return 'Finalizado';
      case 'closed':
        return 'Cerrado';
      default:
        return 'Atencion';
    }
  }

  static Color _lifecycleColor(
    String lifecycle, {
    required Color fallback,
  }) {
    switch (lifecycle) {
      case 'active':
        return AppColors.successDeep;
      case 'completed':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return fallback;
    }
  }

  static String _dispatchLabel(
    String status, {
    required String fulfillmentMethod,
    required String assignedWarehouseLabel,
  }) {
    switch (status) {
      case 'pending':
        return 'Pendiente de bodega';
      case 'assigned':
        if (fulfillmentMethod == 'pickup') {
          return assignedWarehouseLabel.isNotEmpty
              ? 'Retiro listo'
              : 'Bodega retiro lista';
        }
        return assignedWarehouseLabel.isNotEmpty
            ? 'Bodega asignada'
            : 'Despacho asignado';
      default:
        if (fulfillmentMethod == 'pickup' &&
            assignedWarehouseLabel.isNotEmpty) {
          return 'Bodega retiro lista';
        }
        if (assignedWarehouseLabel.isNotEmpty) {
          return 'Bodega asignada';
        }
        return '';
    }
  }

  static Color _dispatchBadgeColor(
    String status, {
    required String fulfillmentMethod,
  }) {
    switch (status) {
      case 'pending':
        return AppColors.goldDeep;
      case 'assigned':
        return fulfillmentMethod == 'pickup'
            ? AppColors.successDeep
            : AppColors.success;
      default:
        return fulfillmentMethod == 'pickup'
            ? AppColors.successDeep
            : AppColors.textSecondary;
    }
  }

  static String _dispatchPendingReason(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';

    final lower = normalized.toLowerCase();
    if (lower.contains('shipping warehouse without enough stock') ||
        lower.contains('waiting for dispatch assignment')) {
      return 'La bodega principal de despacho no tiene stock suficiente. El pedido quedó pendiente para asignar otra bodega.';
    }
    if (lower.contains('awaiting dispatch warehouse assignment')) {
      return 'Estamos esperando asignar la bodega que preparará este pedido.';
    }
    return normalized;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _isClosedStatus(Map<String, dynamic> order) {
    if (order['is_closed'] == true) return true;
    final status = (order['status_normalized'] ?? order['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return ['cancelled', 'failed', 'refunded', 'completed'].contains(status);
  }
}

class _OrderMetaBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _OrderMetaBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: AppTextSize.labelSmall,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FocusedOrderBanner extends StatelessWidget {
  final int orderId;
  final bool openedFromPush;

  const _FocusedOrderBanner({
    required this.orderId,
    required this.openedFromPush,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.16),
              borderRadius: AppRadius.medium,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.goldDeep,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  openedFromPush
                      ? 'Abrimos tu pedido #$orderId desde la notificación.'
                      : 'Pedido #$orderId listo para revisar.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Lo dejamos resaltado unos segundos para ubicarlo más rápido.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
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

class _PaymentProofPanel extends StatelessWidget {
  final bool uploaded;
  final String uploadedAt;
  final bool isUploading;
  final bool canUpload;
  final VoidCallback onUpload;

  const _PaymentProofPanel({
    required this.uploaded,
    required this.uploadedAt,
    required this.isUploading,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = uploaded ? AppColors.success : AppColors.goldDeep;
    final title =
        uploaded ? 'Comprobante recibido' : 'Comprobante de transferencia';
    final description = uploaded
        ? 'Tu comprobante quedó adjunto al pedido para validación.'
        : 'Sube una foto clara del pago para que podamos confirmar tu compra.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.large,
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                uploaded
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_rounded,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (uploaded && uploadedAt.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        uploadedAt.split(' ').first,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!uploaded) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
              child: ElevatedButton.icon(
                onPressed: canUpload && !isUploading ? onUpload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: AppIconSize.quantityIcon,
                        height: AppIconSize.quantityIcon,
                        child: CircularProgressIndicator(
                          strokeWidth:
                              AppSpacing.progressStroke - AppSpacing.xxs / 10,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: AppIconSize.sm + AppSpacing.xxs / 2,
                      ),
                label: Text(
                  isUploading ? 'Subiendo...' : 'Subir comprobante',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OrdersErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const OrdersErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.display,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'No pudimos cargar tus pedidos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTextSize.headlineSmall,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.tile,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Reintentar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _OrderInfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 180,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: highlight ? 18 : 14,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
