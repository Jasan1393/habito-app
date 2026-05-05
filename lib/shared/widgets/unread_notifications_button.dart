import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/notification_inbox_service.dart';
import '../../core/theme/app_colors.dart';

class UnreadNotificationsButton extends StatefulWidget {
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color badgeBackgroundColor;
  final Color badgeForegroundColor;
  final String tooltip;
  final BorderRadius borderRadius;

  const UnreadNotificationsButton({
    super.key,
    this.size = 44,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.badgeBackgroundColor = const Color(0xFFD4AF37),
    this.badgeForegroundColor = Colors.black,
    this.tooltip = 'Notificaciones',
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<UnreadNotificationsButton> createState() =>
      _UnreadNotificationsButtonState();
}

class _UnreadNotificationsButtonState extends State<UnreadNotificationsButton> {
  @override
  void initState() {
    super.initState();
    Future.microtask(NotificationInboxService.refreshUnreadCount);
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, AppRoutes.notifications);
    await NotificationInboxService.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationInboxService.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        return Tooltip(
          message: widget.tooltip,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: widget.backgroundColor,
                borderRadius: widget.borderRadius,
                child: InkWell(
                  onTap: _openNotifications,
                  borderRadius: widget.borderRadius,
                  child: SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: widget.foregroundColor,
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.badgeBackgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: widget.badgeForegroundColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
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
