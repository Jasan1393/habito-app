import 'package:flutter/material.dart';

/// GlobalKey que se asigna al [MaterialApp].
/// Permite navegar desde fuera del árbol de widgets
/// (ej. al recibir una notificación push con la app cerrada).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Canal liviano para pedir un cambio de pestana desde servicios globales
/// sin reiniciar el AuthGate mientras la app esta validando biometria.
final ValueNotifier<int?> appMainTabIndexRequest = ValueNotifier<int?>(null);

void requestMainTabNavigation(int index) {
  appMainTabIndexRequest.value = index;
}

int? consumeMainTabNavigationRequest() {
  final index = appMainTabIndexRequest.value;
  if (index != null) {
    appMainTabIndexRequest.value = null;
  }
  return index;
}
