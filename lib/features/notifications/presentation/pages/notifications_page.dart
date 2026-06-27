import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/notification_inbox_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  _NotificationListFilter _selectedFilter = _NotificationListFilter.all;
  int _deleteSnackBarSerial = 0;
  Timer? _deleteSnackBarTimer;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _deleteSnackBarController;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _deleteSnackBarTimer?.cancel();
    _deleteSnackBarController?.close();
    super.dispose();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> items;
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token != null && token.isNotEmpty && auth.isLoggedIn) {
      try {
        final remoteItems = await HabitoBookingApi.getNotificationHistory(
          token: token,
        );
        items = await NotificationInboxService.syncRemoteItems(remoteItems);
      } catch (_) {
        items = await NotificationInboxService.load();
      }
    } else {
      items = await NotificationInboxService.load();
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    await NotificationInboxService.markAllRead();
    await _load();
  }

  Future<void> _deleteNotification(
    Map<String, dynamic> item, {
    bool showUndo = true,
  }) async {
    final id = (item['id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final snapshot = Map<String, dynamic>.from(item);
    final nextItems = _items
        .where((current) => (current['id'] ?? '').toString() != id)
        .toList();

    if (mounted) {
      setState(() {
        _items = nextItems;
      });
    }

    await NotificationInboxService.deleteById(id);

    if (!mounted || !showUndo) return;

    final snackBarSerial = ++_deleteSnackBarSerial;
    _deleteSnackBarTimer?.cancel();
    _deleteSnackBarController?.close();

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
        controller;

    controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        content: const Text('Notificación eliminada.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            _deleteSnackBarTimer?.cancel();
            controller.close();
            await NotificationInboxService.record(
              title: (snapshot['title'] ?? 'Hábito').toString(),
              body: (snapshot['body'] ?? '').toString(),
              data: _asMap(snapshot['data']),
              messageId: id,
              receivedAt: DateTime.tryParse(
                (snapshot['received_at'] ?? '').toString(),
              ),
            );
            await _load();
          },
        ),
      ),
    );

    _deleteSnackBarController = controller;
    _deleteSnackBarTimer = Timer(const Duration(seconds: 3), () {
      if (snackBarSerial != _deleteSnackBarSerial) return;
      controller.close();
    });

    controller.closed.whenComplete(() {
      if (_deleteSnackBarController != controller) return;
      _deleteSnackBarTimer?.cancel();
      _deleteSnackBarTimer = null;
      _deleteSnackBarController = null;
    });
  }

  Future<void> _clearAll() async {
    final shouldClear = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Borrar historial'),
              content: const Text(
                'Se eliminarán todas las notificaciones guardadas en este dispositivo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Borrar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldClear) return;

    await NotificationInboxService.clear();
    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Historial borrado correctamente.')),
      );
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isNotEmpty) {
      await NotificationInboxService.markRead(id);
    }

    final data = _asMap(item['data']);
    final appointmentId = _parseInt(
      data['appointmentId'] ?? data['appointment_id'] ?? data['appointment'],
    );
    final bookingId = _parseInt(
      data['bookingId'] ?? data['booking_id'] ?? data['booking'],
    );
    final orderId = _parseInt(
      data['orderId'] ?? data['order_id'] ?? data['order'],
    );
    final type = (data['type'] ?? '').toString().toLowerCase();
    final targetScreen = _normalizeTargetScreen(
      data['target_screen'] ??
          data['targetScreen'] ??
          data['screen'] ??
          data['target'],
    );

    await _load();
    if (!mounted) return;

    if (appointmentId != null || bookingId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.pushAppointment,
        arguments: {
          'appointmentId': appointmentId,
          'bookingId': bookingId,
        },
      );
      return;
    }

    if (type.contains('order') || type.contains('pedido') || orderId != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.orders,
        arguments: {
          'selectedNavIndex': 1,
          'orderId': orderId,
          'openFromPush': true,
        },
      );
      return;
    }

    switch (targetScreen) {
      case 'shop':
        _openMainTab(1);
        return;
      case 'points':
        _openMainTab(3);
        return;
      case 'profile':
        _openMainTab(4);
        return;
      case 'home':
        _openMainTab(0);
        return;
      case 'bookings':
        Navigator.pushNamed(context, AppRoutes.bookings);
        return;
      case 'locations':
        Navigator.pushNamed(
          context,
          AppRoutes.locations,
          arguments: {'selectedNavIndex': 0},
        );
        return;
      case 'notifications':
        return;
      case 'orders':
        Navigator.pushNamed(
          context,
          AppRoutes.orders,
          arguments: {
            'selectedNavIndex': 1,
            'orderId': orderId,
            'openFromPush': true,
          },
        );
        return;
    }

    await _showNotificationPreview(item);
  }

  void _openMainTab(int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  Future<void> _showNotificationPreview(Map<String, dynamic> item) async {
    final dateLabel = _formatDate((item['received_at'] ?? '').toString());
    final meta = _NotificationMeta.fromItem(item);
    final title = (item['title'] ?? 'Hábito').toString();
    final body = (item['body'] ?? '').toString().trim();
    final previewText = body.isNotEmpty
        ? body
        : 'Mantente atento a las novedades y avisos importantes de tu cuenta.';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xl - AppSpacing.xs,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: AppIconSize.xxl - AppSpacing.xxs,
                    height: AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.full,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                Row(
                  children: [
                    Container(
                      width: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
                      height: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
                      decoration: BoxDecoration(
                        color: meta.iconBackground,
                        borderRadius: AppRadius.tile,
                      ),
                      child: Icon(meta.icon, color: meta.iconColor),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTextSize.section,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
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
                    if (meta.badgeLabel != null)
                      _MetaBadge(
                        label: meta.badgeLabel!,
                        background: meta.badgeBackground,
                        foreground: meta.badgeForeground,
                      ),
                    if (dateLabel.isNotEmpty)
                      const _MetaBadge(
                        label: 'Reciente',
                        background: AppColors.goldMuted,
                        foreground: AppColors.goldDeep,
                      ),
                  ],
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      color: AppColors.goldDeep,
                      fontSize: AppTextSize.bodySmall,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (meta.detailLine.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    meta.detailLine,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.cartItemGap),
                Text(
                  previewText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '';

    final now = DateTime.now();
    final local = parsed.toLocal();
    if (local.isBefore(DateTime(2024)) ||
        local.isAfter(now.add(const Duration(days: 1)))) {
      return '';
    }

    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return 'Hoy, $hour:$minute';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  List<Map<String, dynamic>> _filteredItems() {
    if (_selectedFilter == _NotificationListFilter.all) return _items;

    return _items.where((item) {
      final category = NotificationInboxService.categoryForItem(item);
      switch (_selectedFilter) {
        case _NotificationListFilter.all:
          return true;
        case _NotificationListFilter.appointments:
          return category == NotificationInboxService.categoryAppointment;
        case _NotificationListFilter.orders:
          return category == NotificationInboxService.categoryOrder;
        case _NotificationListFilter.promotions:
          return category == NotificationInboxService.categoryPromotion;
        case _NotificationListFilter.updates:
          return category == NotificationInboxService.categorySchedule ||
              category == NotificationInboxService.categoryAccount ||
              category == NotificationInboxService.categoryGeneral;
      }
    }).toList();
  }

  int _countForFilter(_NotificationListFilter filter) {
    if (filter == _NotificationListFilter.all) return _items.length;

    return _items.where((item) {
      final category = NotificationInboxService.categoryForItem(item);
      switch (filter) {
        case _NotificationListFilter.all:
          return true;
        case _NotificationListFilter.appointments:
          return category == NotificationInboxService.categoryAppointment;
        case _NotificationListFilter.orders:
          return category == NotificationInboxService.categoryOrder;
        case _NotificationListFilter.promotions:
          return category == NotificationInboxService.categoryPromotion;
        case _NotificationListFilter.updates:
          return category == NotificationInboxService.categorySchedule ||
              category == NotificationInboxService.categoryAccount ||
              category == NotificationInboxService.categoryGeneral;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => item['read'] != true).length;
    final visibleItems = _filteredItems();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: AppSpacing.none,
        title: const Text('Notificaciones'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: unreadCount == 0 ? null : _markAllRead,
              child: const Text(
                'Leer todo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          if (_items.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'clear_all') {
                  await _clearAll();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'clear_all',
                  child: Text('Borrar historial'),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: _load,
        child: _isLoading
            ? ListView(
                padding: EdgeInsets.all(AppSpacing.xl),
                children: const [
                  HabitoLoadingShimmer(
                    itemCount: 5,
                    itemHeight: 88,
                  ),
                ],
              )
            : _items.isEmpty
                ? ListView(
                    padding: AppSpacing.section,
                    children: const [
                      SizedBox(
                          height: AppSpacing.actionHeight + AppSpacing.xxs),
                      HabitoEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Sin notificaciones por ahora',
                        message:
                            'Aquí verás avisos de citas, pedidos, promociones y actividad importante.',
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: [
                      _NotificationsHero(unreadCount: unreadCount),
                      const SizedBox(height: AppSpacing.lg),
                      _NotificationFiltersRow(
                        selectedFilter: _selectedFilter,
                        counts: {
                          for (final filter in _NotificationListFilter.values)
                            filter: _countForFilter(filter),
                        },
                        onSelected: (filter) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl - AppSpacing.xs),
                      if (visibleItems.isEmpty)
                        _FilteredNotificationsEmptyView(
                          filter: _selectedFilter,
                        )
                      else
                        ...visibleItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Dismissible(
                              key: ValueKey((item['id'] ?? '').toString()),
                              direction: DismissDirection.horizontal,
                              background: const _SwipeDeleteBackground(
                                alignment: Alignment.centerLeft,
                                icon: Icons.delete_outline_rounded,
                              ),
                              secondaryBackground: const _SwipeDeleteBackground(
                                alignment: Alignment.centerRight,
                                icon: Icons.delete_outline_rounded,
                              ),
                              onDismissed: (_) {
                                _deleteNotification(item);
                              },
                              child: _NotificationCard(
                                item: item,
                                dateLabel: _formatDate(
                                  (item['received_at'] ?? '').toString(),
                                ),
                                onTap: () => _openNotification(item),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
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
    return int.tryParse(value.toString());
  }

  static String _normalizeTargetScreen(dynamic value) {
    final normalized =
        value?.toString().trim().toLowerCase().replaceAll('-', '_');

    switch (normalized) {
      case 'store':
      case 'tienda':
        return 'shop';
      case 'booking':
      case 'reservas':
      case 'citas':
        return 'bookings';
      case 'location':
      case 'branch':
      case 'sucursales':
        return 'locations';
      case 'notification':
        return 'notifications';
      case 'pedido':
        return 'orders';
      case 'inicio':
        return 'home';
      case 'perfil':
        return 'profile';
      case 'puntos':
        return 'points';
      default:
        return normalized ?? '';
    }
  }
}

enum _NotificationListFilter {
  all,
  appointments,
  orders,
  promotions,
  updates,
}

extension _NotificationListFilterInfo on _NotificationListFilter {
  String get label {
    switch (this) {
      case _NotificationListFilter.all:
        return 'Todas';
      case _NotificationListFilter.appointments:
        return 'Citas';
      case _NotificationListFilter.orders:
        return 'Pedidos';
      case _NotificationListFilter.promotions:
        return 'Promos';
      case _NotificationListFilter.updates:
        return 'Avisos';
    }
  }

  String get emptyTitle {
    switch (this) {
      case _NotificationListFilter.all:
        return 'Sin notificaciones por ahora';
      case _NotificationListFilter.appointments:
        return 'Sin avisos de citas';
      case _NotificationListFilter.orders:
        return 'Sin movimientos de pedidos';
      case _NotificationListFilter.promotions:
        return 'Sin promociones guardadas';
      case _NotificationListFilter.updates:
        return 'Sin avisos operativos';
    }
  }

  String get emptyMessage {
    switch (this) {
      case _NotificationListFilter.all:
        return 'Aquí verás avisos de citas, pedidos, promociones y actividad importante.';
      case _NotificationListFilter.appointments:
        return 'Cuando cambie una reserva o llegue un recordatorio, aparecerá aquí.';
      case _NotificationListFilter.orders:
        return 'Los cambios de estado de tus compras en tienda se mostrarán en esta sección.';
      case _NotificationListFilter.promotions:
        return 'Las ofertas y campañas nuevas aparecerán aquí cuando estén activas.';
      case _NotificationListFilter.updates:
        return 'Aquí reunimos cambios de horario, avisos de cuenta y otras novedades importantes.';
    }
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  final Alignment alignment;
  final IconData icon;

  const _SwipeDeleteBackground({
    required this.alignment,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: AppRadius.extraLarge,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isLeft ? AppSpacing.xl - AppSpacing.xs : AppSpacing.xl,
      ),
      alignment: alignment,
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft)
            const Text(
              'Borrar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (!isLeft) const SizedBox(width: AppSpacing.sm),
          Icon(icon, color: Colors.white),
          if (isLeft) const SizedBox(width: AppSpacing.sm),
          if (isLeft)
            const Text(
              'Borrar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationFiltersRow extends StatelessWidget {
  final _NotificationListFilter selectedFilter;
  final Map<_NotificationListFilter, int> counts;
  final ValueChanged<_NotificationListFilter> onSelected;

  const _NotificationFiltersRow({
    required this.selectedFilter,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppIconSize.pointsBadge,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _NotificationListFilter.values.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
        itemBuilder: (context, index) {
          final filter = _NotificationListFilter.values[index];
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.full,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  final int unreadCount;

  const _NotificationsHero({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl - AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.display,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.actionHeight,
            height: AppSpacing.actionHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: AppRadius.large,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.borderStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.cartItemGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Centro de actividad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.section,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + AppSpacing.xxs / 2),
                Text(
                  unreadCount == 0
                      ? 'Estás al día con tus avisos.'
                      : '$unreadCount aviso(s) sin leer.',
                  style: const TextStyle(
                    color: AppColors.border,
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

class _FilteredNotificationsEmptyView extends StatelessWidget {
  final _NotificationListFilter filter;

  const _FilteredNotificationsEmptyView({
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.section,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.hero,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
            color: AppColors.goldDeep,
          ),
          const SizedBox(height: AppSpacing.cartItemGap),
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

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String dateLabel;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = item['read'] != true;
    final title = (item['title'] ?? 'Hábito').toString();
    final body = (item['body'] ?? '').toString().trim();
    final meta = _NotificationMeta.fromItem(item);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.extraLarge,
        child: Ink(
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.extraLarge,
            border: Border.all(
              color: isUnread ? AppColors.secondary : AppColors.border,
              width: isUnread ? 1.3 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppIconSize.pointsBadge,
                height: AppIconSize.pointsBadge,
                decoration: BoxDecoration(
                  color: meta.iconBackground,
                  borderRadius: AppRadius.soft,
                ),
                child: Icon(meta.icon, color: meta.iconColor),
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
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: AppSpacing.sm + AppSpacing.xxs / 2,
                            height: AppSpacing.sm + AppSpacing.xxs / 2,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (meta.badgeLabel != null || meta.detailLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm - AppSpacing.xxs / 2,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (meta.badgeLabel != null)
                              _MetaBadge(
                                label: meta.badgeLabel!,
                                background: meta.badgeBackground,
                                foreground: meta.badgeForeground,
                              ),
                            if (meta.detailLine.isNotEmpty)
                              Text(
                                meta.detailLine,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: AppTextSize.bodySmall,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(
                          height: AppSpacing.sm - AppSpacing.xxs / 2),
                      Text(
                        body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (dateLabel.isNotEmpty) ...[
                      const SizedBox(
                          height: AppSpacing.sm + AppSpacing.xxs / 2),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppColors.goldDeep,
                          fontSize: AppTextSize.label,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _MetaBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.xs + AppSpacing.xxs / 2,
      ),
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

class _NotificationMeta {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String? badgeLabel;
  final Color badgeBackground;
  final Color badgeForeground;
  final String detailLine;

  const _NotificationMeta({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.badgeLabel,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.detailLine,
  });

  factory _NotificationMeta.fromItem(Map<String, dynamic> item) {
    final data = _asMap(item['data']);
    final category = NotificationInboxService.categoryForItem(item);
    final type = (data['type'] ?? '').toString().toLowerCase();
    final status = (data['status'] ?? '').toString().toLowerCase();
    final serviceName = (data['service_name'] ?? '').toString().trim();
    final locationName = (data['location_name'] ?? '').toString().trim();
    final providerName = (data['provider_name'] ?? '').toString().trim();
    final orderStatusDisplay = (data['status_display'] ??
            data['statusDisplay'] ??
            data['status_label'] ??
            '')
        .toString()
        .trim();
    final orderId = _parseInt(
      data['orderId'] ?? data['order_id'] ?? data['order'],
    );

    if (category == NotificationInboxService.categoryOrder ||
        type.contains('order') ||
        type.contains('pedido') ||
        orderId != null) {
      final orderParts = <String>[
        if (orderId != null && orderId > 0) 'Pedido #$orderId',
        if (orderStatusDisplay.isNotEmpty) orderStatusDisplay,
      ];
      return _NotificationMeta(
        icon: Icons.receipt_long_rounded,
        iconBackground: AppColors.infoSoft,
        iconColor: AppColors.infoDeep,
        badgeLabel: 'Pedido',
        badgeBackground: AppColors.infoSoft,
        badgeForeground: AppColors.infoDeep,
        detailLine: orderParts.isNotEmpty
            ? orderParts.join(' - ')
            : 'Movimiento de tienda',
      );
    }

    if (category == NotificationInboxService.categoryPromotion ||
        type.contains('promo') ||
        type.contains('offer')) {
      return const _NotificationMeta(
        icon: Icons.local_offer_outlined,
        iconBackground: AppColors.goldSurface,
        iconColor: AppColors.goldDeep,
        badgeLabel: 'Promo',
        badgeBackground: AppColors.goldSurface,
        badgeForeground: AppColors.goldDeep,
        detailLine: 'Novedades y beneficios para ti',
      );
    }

    if (category == NotificationInboxService.categorySchedule ||
        type.contains('schedule') ||
        type.contains('holiday')) {
      return const _NotificationMeta(
        icon: Icons.schedule_rounded,
        iconBackground: AppColors.goldMuted,
        iconColor: AppColors.warningDeep,
        badgeLabel: 'Horario',
        badgeBackground: AppColors.goldMuted,
        badgeForeground: AppColors.warningDeep,
        detailLine: 'Aviso operativo importante',
      );
    }

    if (category == NotificationInboxService.categoryAccount ||
        type.contains('account') ||
        type.contains('profile') ||
        type.contains('welcome')) {
      return const _NotificationMeta(
        icon: Icons.person_outline_rounded,
        iconBackground: AppColors.infoSoft,
        iconColor: AppColors.infoDeep,
        badgeLabel: 'Cuenta',
        badgeBackground: AppColors.infoSoft,
        badgeForeground: AppColors.infoDeep,
        detailLine: 'Actividad importante de tu perfil',
      );
    }

    final detailParts = <String>[
      if (serviceName.isNotEmpty) serviceName,
      if (providerName.isNotEmpty) providerName,
      if (locationName.isNotEmpty) locationName,
    ];
    final detailLine = detailParts.join(' - ');

    switch (status) {
      case 'approved':
      case 'confirmed':
        return _NotificationMeta(
          icon: Icons.check_circle_outline_rounded,
          iconBackground: AppColors.successSoft,
          iconColor: AppColors.success,
          badgeLabel: 'Confirmada',
          badgeBackground: AppColors.successSoft,
          badgeForeground: AppColors.success,
          detailLine: detailLine,
        );
      case 'canceled':
      case 'cancelled':
        return _NotificationMeta(
          icon: Icons.cancel_outlined,
          iconBackground: AppColors.dangerSoft,
          iconColor: AppColors.danger,
          badgeLabel: 'Cancelada',
          badgeBackground: AppColors.dangerSoft,
          badgeForeground: AppColors.danger,
          detailLine: detailLine,
        );
      case 'completed':
        return _NotificationMeta(
          icon: Icons.verified_rounded,
          iconBackground: AppColors.infoSoft,
          iconColor: AppColors.infoDeep,
          badgeLabel: 'Completada',
          badgeBackground: AppColors.infoSoft,
          badgeForeground: AppColors.infoDeep,
          detailLine: detailLine,
        );
      case 'rejected':
        return _NotificationMeta(
          icon: Icons.error_outline_rounded,
          iconBackground: AppColors.dangerSoft,
          iconColor: AppColors.danger,
          badgeLabel: 'Rechazada',
          badgeBackground: AppColors.dangerSoft,
          badgeForeground: AppColors.danger,
          detailLine: detailLine,
        );
      case 'pending':
        return _NotificationMeta(
          icon: Icons.schedule_rounded,
          iconBackground: AppColors.warningSoft,
          iconColor: AppColors.warningDeep,
          badgeLabel: 'Pendiente',
          badgeBackground: AppColors.warningSoft,
          badgeForeground: AppColors.warningDeep,
          detailLine: detailLine,
        );
      default:
        return _NotificationMeta(
          icon: Icons.notifications_none_rounded,
          iconBackground: AppColors.goldMuted,
          iconColor: AppColors.goldDeep,
          badgeLabel: detailLine.isNotEmpty ? 'Reserva' : 'Aviso',
          badgeBackground: AppColors.goldMuted,
          badgeForeground: AppColors.goldDeep,
          detailLine: detailLine,
        );
    }
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
    return int.tryParse(value.toString());
  }
}

class EmptyNotificationsView extends StatelessWidget {
  const EmptyNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.section,
      children: [
        const SizedBox(height: AppSpacing.actionHeight + AppSpacing.xxs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl + AppSpacing.xs),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.display,
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: AppSpacing.actionHeight,
                color: AppColors.goldDeep,
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                'Sin notificaciones por ahora',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTextSize.headlineSmall + AppSpacing.xxs / 2,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
              Text(
                'Aquí verás avisos de citas, pedidos, promociones y actividad importante.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
