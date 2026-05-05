import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class HabitoBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const HabitoBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: AppColors.primary,
      indicatorColor: const Color(0xFFE7D39A),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? const Color(0xFFE7D39A) : Colors.white70,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        );
      }),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.home, color: AppColors.primary),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.shopping_bag, color: AppColors.primary),
          label: 'Tienda',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
          label: 'Citas',
        ),
        NavigationDestination(
          icon: Icon(Icons.stars_outlined, color: Colors.white70),
          selectedIcon: Icon(Icons.stars, color: AppColors.primary),
          label: 'Puntos',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, color: Colors.white70),
          selectedIcon: Icon(Icons.person, color: AppColors.primary),
          label: 'Perfil',
        ),
      ],
    );
  }
}
