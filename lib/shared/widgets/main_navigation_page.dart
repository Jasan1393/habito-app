import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_navigator.dart';
import '../../core/services/app_update_service.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/bookings/presentation/pages/my_appointments_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/points/presentation/pages/points_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/shop/presentation/pages/shop_page.dart';
import 'habito_bottom_navigation_bar.dart';
import 'main_navigation_scope.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialIndex;
  final Map<String, dynamic>? myAppointmentsArguments;

  const MainNavigationPage({
    super.key,
    this.initialIndex = 1,
    this.myAppointmentsArguments,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  late int _currentIndex;
  late final List<Widget?> _pages;
  bool _didScheduleAppUpdateCheck = false;

  static const List<int> _protectedIndexes = [2, 3];

  @override
  void initState() {
    super.initState();
    _currentIndex = _normalizeIndex(consumeMainTabNavigationRequest()) ??
        _normalizeIndex(widget.initialIndex) ??
        0;
    _pages = List<Widget?>.filled(5, null);
    _pages[_currentIndex] = _buildPage(_currentIndex);
    appMainTabIndexRequest.addListener(_handleExternalTabRequest);
  }

  @override
  void dispose() {
    appMainTabIndexRequest.removeListener(_handleExternalTabRequest);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_didScheduleAppUpdateCheck) {
      _didScheduleAppUpdateCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppUpdateService.maybePromptForUpdate(context);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MainNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = _normalizeIndex(widget.initialIndex) ?? 0;
      _pages[_currentIndex] ??= _buildPage(_currentIndex);
    }
  }

  void _handleExternalTabRequest() {
    final index = _normalizeIndex(consumeMainTabNavigationRequest());
    if (!mounted || index == null) return;

    setState(() {
      _currentIndex = index;
      _pages[index] ??= _buildPage(index);
    });
  }

  int? _normalizeIndex(int? index) {
    if (index == null || index < 0 || index > 4) return null;
    return index;
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const ShopPage();
      case 2:
        return MyAppointmentsPage(
          initialArguments: widget.myAppointmentsArguments,
        );
      case 3:
        return const PointsPage();
      case 4:
        return const ProfilePage();
      default:
        return const HomePage();
    }
  }

  Future<void> _onDestinationSelected(
    int index, {
    bool refreshMyAppointments = false,
  }) async {
    final auth = context.read<AuthProvider>();
    final requiresAuth = _protectedIndexes.contains(index);

    setState(() {
      _currentIndex = index;
      if (requiresAuth && !auth.isLoggedIn) return;

      if (refreshMyAppointments && index == 2) {
        _pages[index] = _buildPage(index);
      } else {
        _pages[index] ??= _buildPage(index);
      }
    });
  }

  Widget _resolvePage(int index, bool isLoggedIn) {
    if (_protectedIndexes.contains(index) && !isLoggedIn) {
      return const LoginPage(popOnSuccess: false);
    }

    return _pages[index] ??= _buildPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AuthProvider, bool>(
      (auth) => auth.isLoggedIn,
    );

    return MainNavigationScope(
      selectTab: _onDestinationSelected,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List<Widget>.generate(
            _pages.length,
            (index) => _resolvePage(index, isLoggedIn),
          ),
        ),
        bottomNavigationBar: HabitoBottomNavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
        ),
      ),
    );
  }
}
