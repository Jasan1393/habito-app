# Patrones de UX — Hábito

## Tabla de contenidos
1. Estados (loading / empty / error / success)
2. Mensajes amables al usuario
3. Formularios
4. Confirmaciones y acciones destructivas
5. Feedback de acciones
6. Persistencia del carrito
7. Deep links y navegación
8. Accesibilidad mínima
9. Tildes y español de Ecuador
10. Datos bancarios y métodos de pago

---

## 1. Estados

Toda pantalla con datos del backend debe modelar 4 estados explícitos: **loading inicial**, **vacío**, **error**, **datos**. No mezclar:

```dart
@override
Widget build(BuildContext context) {
  final state = context.watch<MyProvider>();
  
  if (state.isLoading && state.items.isEmpty) {
    return const _SkeletonList();  // o const HabitoLoadingShimmer
  }
  
  if (state.error != null && state.items.isEmpty) {
    return HabitoErrorState(
      title: 'No pudimos cargar el contenido',
      subtitle: _friendlyError(state.error!),
      onRetry: state.refresh,
    );
  }
  
  if (state.items.isEmpty) {
    return const HabitoEmptyState(
      icon: Icons.inbox_outlined,
      title: 'Aún no hay nada por aquí',
      subtitle: 'Cuando reserves o compres algo aparecerá aquí.',
    );
  }
  
  return RefreshIndicator(
    onRefresh: state.refresh,
    child: ListView.builder(...),
  );
}
```

**Regla**: si la lista tiene datos cacheados pero el fetch en background falla, no mostrar pantalla de error — mostrar la lista cacheada con un banner discreto arriba ("No pudimos actualizar; mostrando última versión guardada").

## 2. Mensajes amables al usuario

Todo mensaje que viene del backend debe pasar por un mapper antes de tocar la UI. Patrón:

```dart
String _friendlyBookingError(Object error) {
  final raw = error.toString().toLowerCase();
  
  if (raw.contains('sesi') || raw.contains('token') || raw.contains('401')) {
    return 'Tu sesión venció. Inicia sesión nuevamente.';
  }
  if (raw.contains('timeout') || raw.contains('socket') || raw.contains('connection')) {
    return 'No pudimos conectar. Revisa tu internet e intenta nuevamente.';
  }
  if (raw.contains('slot') && raw.contains('taken')) {
    return 'Ese horario ya no está disponible. Elige otro.';
  }
  if (raw.contains('insufficient') && raw.contains('points')) {
    return 'No tienes suficientes puntos para esta operación.';
  }
  if (raw.contains('500') || raw.contains('internal')) {
    return 'El servidor está teniendo problemas. Intenta en unos minutos.';
  }
  
  // Fallback: limpiar prefijo "Exception:" pero NO mostrar stack traces
  return error
      .toString()
      .replaceFirst('Exception:', '')
      .replaceFirst(RegExp(r'\bSQLSTATE\b.*'), '')
      .trim();
}
```

Crear un `_friendlyXxxError` por cada operación crítica:
- `_friendlyAvailabilityError` (ya existe en `bookings_page.dart`)
- `_friendlyBookingError` (ya existe)
- `_friendlyCancelError` (FALTA — agregarlo en `appointment_detail_page.dart`)
- `_friendlyRescheduleError` (FALTA)
- `_friendlyCheckoutError` (FALTA en `checkout_page.dart` o `shop_provider.dart`)
- `_friendlyPaymentProofError` (FALTA en `orders_page.dart`)
- `_friendlyPointsError` (FALTA en `points_page.dart`)

**Regla:** nunca mostrar `response.body` raw. Saneo en `_decodeResponse` debe garantizarlo.

## 3. Formularios

### Campos obligatorios

Todo `TextFormField` necesita:

```dart
TextFormField(
  controller: _emailCtrl,
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,  // o done si es el último
  autofillHints: const [AutofillHints.email],
  decoration: const InputDecoration(
    labelText: 'Correo electrónico',
    hintText: 'tu@correo.com',
  ),
  validator: _validateEmail,  // del helper compartido
)
```

Mapeo `keyboardType` / `autofillHints` por tipo de campo:

| Campo | keyboardType | autofillHints |
|---|---|---|
| Nombre | `name` | `givenName` |
| Apellido | `name` | `familyName` |
| Correo | `emailAddress` | `email` |
| Teléfono | `phone` | `telephoneNumber` |
| Contraseña | `visiblePassword` | `password` |
| Nueva contraseña | `visiblePassword` | `newPassword` |
| Cédula / RUC | `number` | `username` (no hay hint específico, evitar) |
| Dirección | `streetAddress` | `streetAddressLine1` |
| Ciudad | `name` | `addressCity` |

### Validador de cédula ecuatoriana (módulo 11)

Crear `lib/core/validators/ecuador_id_validator.dart`:

```dart
class EcuadorIdValidator {
  EcuadorIdValidator._();
  
  /// Valida cédula ecuatoriana de 10 dígitos con módulo 11.
  static bool isValidCedula(String input) {
    final digits = input.trim();
    if (digits.length != 10) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return false;
    
    final province = int.parse(digits.substring(0, 2));
    if (province < 1 || province > 24) return false;
    
    final third = int.parse(digits[2]);
    if (third < 0 || third > 5) return false;  // personas naturales
    
    const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      var product = int.parse(digits[i]) * coefficients[i];
      if (product >= 10) product -= 9;
      sum += product;
    }
    final verifier = (10 - (sum % 10)) % 10;
    return verifier == int.parse(digits[9]);
  }
  
  /// Valida RUC ecuatoriano de 13 dígitos.
  /// Personas naturales: 10 dígitos válidos + "001".
  /// Sociedades públicas: tercer dígito 6, módulo 11 con coef [3,2,7,6,5,4,3,2].
  /// Sociedades privadas / extranjeras: tercer dígito 9, módulo 11 con coef [4,3,2,7,6,5,4,3,2].
  static bool isValidRuc(String input) {
    final digits = input.trim();
    if (digits.length != 13) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return false;
    if (!digits.endsWith('001') && !digits.endsWith('002')) return false;  // sucursales
    
    final third = int.parse(digits[2]);
    
    if (third < 6) {
      // RUC de persona natural = cédula + 001
      return isValidCedula(digits.substring(0, 10));
    }
    
    if (third == 6) {
      // Sociedad pública
      const coefs = [3, 2, 7, 6, 5, 4, 3, 2];
      return _modulo11(digits.substring(0, 9), coefs, expectedVerifierAt: 8);
    }
    
    if (third == 9) {
      // Sociedad privada / extranjera
      const coefs = [4, 3, 2, 7, 6, 5, 4, 3, 2];
      return _modulo11(digits.substring(0, 10), coefs, expectedVerifierAt: 9);
    }
    
    return false;
  }
  
  static bool _modulo11(String digits, List<int> coefs, {required int expectedVerifierAt}) {
    var sum = 0;
    for (var i = 0; i < coefs.length; i++) {
      sum += int.parse(digits[i]) * coefs[i];
    }
    final remainder = sum % 11;
    final verifier = remainder == 0 ? 0 : 11 - remainder;
    if (verifier == 10) return false;  // RUC inválido
    return verifier == int.parse(digits[expectedVerifierAt]);
  }
}
```

Y un helper de validador para forms:

```dart
String? validateEcuadorDocument(String? value, String type) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Ingresa tu documento';
  
  if (type == 'cedula') {
    if (!EcuadorIdValidator.isValidCedula(v)) {
      return 'Cédula inválida';
    }
  } else if (type == 'ruc') {
    if (!EcuadorIdValidator.isValidRuc(v)) {
      return 'RUC inválido';
    }
  } else if (type == 'pasaporte') {
    if (v.length < 6) return 'Pasaporte muy corto';
  }
  return null;
}
```

### Validador de email estricto

```dart
String? validateEmail(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return 'Ingresa tu correo';
  // Regex razonable: usuario@dominio.tld
  final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  if (!regex.hasMatch(v)) return 'Correo inválido';
  return null;
}
```

## 4. Confirmaciones y acciones destructivas

**Regla:** toda acción destructiva (eliminar producto del carrito, cancelar cita, eliminar cuenta) requiere confirmación. Patrón:

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Cancelar cita'),
    content: const Text('Esta acción cancelará tu cita. ¿Deseas continuar?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('No'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.pop(ctx, true),
        child: const Text('Sí, cancelar'),
      ),
    ],
  ),
);
if (confirmed != true) return;
```

Para acciones reversibles rápidamente (quitar producto del carrito), usar `Dismissible` + SnackBar con "Deshacer" en lugar de un dialog completo.

## 5. Feedback de acciones

- **Acción exitosa rápida** (agregar al carrito, marcar leído): SnackBar 2s.
- **Acción exitosa importante** (creó la reserva, creó la orden): BottomSheet o pantalla de confirmación con resumen.
- **Acción en progreso**: spinner inline en el botón (deshabilita el botón).
- **Acción pendiente externa** (esperando comprobante): card de estado en la lista de órdenes / detalle.

Patrón de botón con loading:

```dart
ElevatedButton(
  onPressed: _isSubmitting ? null : _handleSubmit,
  child: _isSubmitting
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
        )
      : const Text('Confirmar reserva'),
)
```

## 6. Persistencia del carrito

**Falta hoy.** Cuando se implemente (`shop_provider.dart`):

1. Agregar `shared_preferences` al `pubspec.yaml` (pedir permiso al usuario antes).
2. En `ShopProvider`:

```dart
class ShopProvider extends ChangeNotifier {
  static const _kCartStorageKey = 'habito.cart.v1';
  
  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCartStorageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _cartItems
        ..clear()
        ..addAll((data['items'] as List).map(_cartItemFromJson));
      _fulfillmentMethod = ShopFulfillmentMethod.values.firstWhere(
        (m) => m.name == data['fulfillment'],
        orElse: () => ShopFulfillmentMethod.delivery,
      );
      _pickupLocation = data['pickup'] as Map<String, dynamic>?;
      notifyListeners();
    } catch (_) {
      await prefs.remove(_kCartStorageKey);
    }
  }
  
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCartStorageKey, jsonEncode({
      'items': _cartItems.map(_cartItemToJson).toList(),
      'fulfillment': _fulfillmentMethod.name,
      'pickup': _pickupLocation,
    }));
  }
  
  // Llamar _persist() después de cada notifyListeners() relevante
  // (con debounce de 1s para no escribir cada tap del stepper):
  Timer? _persistDebounce;
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 1), _persist);
  }
}
```

3. Llamar `shop.hydrate()` en `main.dart` antes del `runApp`, o en el `AuthGatePage` cuando el usuario ya esté logueado.

## 7. Deep links y navegación

Hoy las rutas vienen de push notifications (`pushAppointment`, `orders` con `initialOrderId`). Patrón al agregar nuevas:

1. Definir constante en `AppRoutes`.
2. Parsear argumentos con `_parseInt`/`_parseBool` defensivos.
3. Si la pantalla requiere sesión, redirigir a login si no hay token.
4. Si la pantalla requiere data del backend, mostrar loading + manejar error.

Ejemplo de patrón seguro (ya implementado en `push_appointment_loader_page.dart`):

```dart
// 1. Mostrar loading
// 2. Esperar a que la sesión esté cargada (await auth.bootstrap())
// 3. Si no hay sesión, navegar a login con returnRoute
// 4. Hacer fetch del recurso
// 5. Si éxito → pushReplacement al detail
// 6. Si error → mostrar pantalla de error con botón "Volver al inicio"
```

## 8. Accesibilidad mínima

- **Tamaño de tap**: 48×48 dp mínimo. Los steppers de cantidad en el carrito están en 34×34 — corregir a 44×44.
- **Tooltips** en botones que solo tienen icono.
- **Semantics labels** en imágenes informativas:

```dart
Semantics(
  label: 'Foto del producto: ${product.name}',
  image: true,
  child: HabitoCachedNetworkImage(...),
)
```

- **Contraste**: verificar con cualquier checker que `AppColors.textSecondary` sobre `AppColors.background` cumpla AA (4.5:1).
- **No deshabilitar el ajuste de tamaño de fuente del sistema**: nunca usar `MediaQuery.textScalerOf` con `clamp` agresivo.

## 9. Tildes y español de Ecuador

Cuando edites cualquier string de UI, corrige tildes faltantes:

| Mal | Bien |
|---|---|
| Aun | Aún |
| Si | Sí (cuando es afirmación) |
| modulo | módulo |
| esta | está (verbo) |
| accion | acción |
| vencio | venció |
| paso | pasó |
| Todavia | Todavía |
| apareceran | aparecerán |
| anticipacion | anticipación |
| veras | verás |
| sucursal | sucursal (sin tilde, ok) |

## 10. Datos bancarios y métodos de pago

**Hoy** la app solo tiene transferencia bancaria como método de pago, pero **no muestra los datos de la cuenta** al usuario. Tras crear una orden con `bacs`, mostrar un BottomSheet o pantalla con:

```
Cuenta beneficiaria:
  Banco: Banco Pichincha
  Tipo: Cuenta corriente
  Número: XXXXXXXXXX
  Titular: HÁBITO BARBERÍA S.A.
  RUC: XXXXXXXXX001
  Correo para comprobante: pagos@habitobarberia.com

[Botón: Copiar número de cuenta]
[Botón: Abrir WhatsApp +593 XX XXX XXXX]
[Botón: Subir comprobante ahora]
```

Datos a obtener del usuario o del backend (debería venir del endpoint `/shop/payment-methods`). Si no viene, hardcodear como `AppConfig.bankDetails` mientras se gestiona en backend.

---

## Cuándo bloquear UI vs solo deshabilitar

- **Operación rápida (<2s)**: deshabilitar el botón con spinner inline. UI sigue interactuable.
- **Operación crítica con dinero (createBooking, createOrder)**: deshabilitar el botón + posiblemente cubrir la pantalla con un overlay no-cancelable mientras se procesa. Nunca permitir un segundo tap.
- **Navegación con fetch (`PushAppointmentLoaderPage`)**: pantalla intermedia con spinner centrado y opción de cancelar/volver.
