import 'package:flutter/widgets.dart';

typedef MainTabSelector = Future<void> Function(
  int index, {
  bool refreshMyAppointments,
});

class MainNavigationScope extends InheritedWidget {
  final MainTabSelector selectTab;

  const MainNavigationScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  static MainNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavigationScope>();
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) {
    return selectTab != oldWidget.selectTab;
  }
}
