# Patrones de rendimiento — Hábito

## Tabla de contenidos
1. Cache de catálogo (servicios, barberos, locaciones)
2. Cache de productos
3. Doble-fetch y `forceRefresh`
4. Imágenes con `cached_network_image`
5. Listas y grids
6. Memoización de parsers
7. Provider rebuilds (Selector)
8. HTTP: timeouts, retries, idempotency
9. Operaciones pesadas en `build()`
10. Liberar recursos en `dispose()`

---

## 1. Cache de catálogo

`HabitoBookingApi` (`lib/features/shop/data/services/habito_booking_api.dart`) ya tiene una caché bien diseñada con TTL fresh (10 min) + stale (7 días) + persistencia en disco. **No la rediseñes.** Solo arregla los abusos:

**Anti-patrón actual (`shop_page.dart:53`, `services_archive_page.dart:34`):**

```dart
// MAL — invalida también barberos y sucursales
HabitoBookingApi.clearCache();
final items = await HabitoBookingApi.getServices(forceRefresh: true);
```

**Patrón correcto** — agregar `clearServicesCache()` granular en la API:

```dart
// En HabitoBookingApi
static void clearServicesCache() {
  _cachedServices = null;
  _servicesCachedAt = null;
  _servicesRefreshFuture = null;
  unawaited(_persistCache());  // re-escribir solo lo que queda
}

static void clearEmployeesCache() { /* análogo */ }
static void clearLocationsCache() { /* análogo */ }
```

Luego en los call sites:

```dart
// shop_page.dart:53
HabitoBookingApi.clearServicesCache();
final items = await HabitoBookingApi.getServices(forceRefresh: true);
```

Mantén `clearCache()` como atajo solo para logout (donde sí se quiere invalidar todo).

## 2. Cache de productos

`HabitoShopApi` (`habito_shop_api.dart`) tiene su propia caché con `_cacheSchemaVersion = 9`. Cuando cambies el shape del payload, **incrementa la versión** para invalidar la caché de los usuarios automáticamente:

```dart
static const int _cacheSchemaVersion = 10;  // de 9 a 10
```

## 3. Doble-fetch y `forceRefresh`

Patrón roto en `cart_page.dart:41-78` y `locations_page.dart:60-101`:

```dart
// MAL — dos fetch garantizados aunque la caché esté fresca
final cached = await HabitoBookingApi.getCachedLocations();
if (cached.isNotEmpty) {
  setState(() => _locations = cached);
}
unawaited(HabitoBookingApi.getLocations(forceRefresh: true));  // siempre dispara
```

**Patrón correcto:**

```dart
final cached = await HabitoBookingApi.getCachedLocations();
final cachedAt = HabitoBookingApi.locationsCachedAt;  // exponer el getter
final isFresh = cachedAt != null &&
    DateTime.now().difference(cachedAt) < const Duration(minutes: 5);

if (cached.isNotEmpty && isFresh) {
  setState(() => _locations = cached);
  return;  // confiar en la caché fresca, no refetch
}

if (cached.isNotEmpty) {
  setState(() => _locations = cached);  // mostrar mientras refresca
}
final fresh = await HabitoBookingApi.getLocations(forceRefresh: true);
if (mounted) setState(() => _locations = fresh);
```

## 4. Imágenes

**Anti-patrón:**

```dart
CachedNetworkImage(imageUrl: url)  // decodifica full-size
```

**Patrón:** siempre con `memCacheWidth/Height` proporcional al tamaño visible.

```dart
// En HabitoCachedNetworkImage (lib/shared/widgets/habito_cached_network_image.dart)
HabitoCachedNetworkImage(
  imageUrl: url,
  width: 120,
  height: 120,
  // memCacheWidth interno = 240 (2x para retina)
)
```

Modificar `HabitoCachedNetworkImage` para que reciba `width`/`height` y calcule `memCacheWidth = (width * MediaQuery.devicePixelRatioOf(context)).round()` internamente.

**Asset estático pesado** — `assets/images/services/Corte de Cabello.png` (1.9 MB) tiene que comprimirse fuera de Flutter (con un editor de imagen). Target: <300 KB. Idealmente WebP. La skill no lo puede hacer; solo recordar al usuario que ejecute la compresión y reemplace el asset.

## 5. Listas y grids

**Anti-patrón:**

```dart
ListView(children: items.map((i) => Card(...)).toList())  // construye todo
```

**Patrón:**

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (_, i) => _ItemCard(item: items[i]),
  // Para grids grandes con scroll vertical:
  addAutomaticKeepAlives: false,
  addRepaintBoundaries: true,
)
```

Para `GridView`:

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 0.72,
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.md,
  ),
  itemCount: products.length,
  itemBuilder: (_, i) => _ProductCard(product: products[i]),
  addAutomaticKeepAlives: false,
  addRepaintBoundaries: true,
)
```

## 6. Memoización de parsers

**Anti-patrón:** `extractServiceImageUrl(service)` (32 candidatos) llamado en cada frame.

**Patrón:** memoizar dentro del propio mapa al normalizar (no por cada render).

```dart
// En HabitoBookingApi.extractServiceImageUrl, al final:
static String extractServiceImageUrl(Map<String, dynamic> service) {
  final cached = service['_resolvedImage'];
  if (cached is String) return cached;
  
  final result = _resolveImageUrl(service);  // lógica actual
  service['_resolvedImage'] = result;
  return result;
}
```

Aplica el mismo patrón a cualquier "extract*" / "normalize*" pesado que se ejecute por item.

## 7. Provider rebuilds

**Anti-patrón:** `context.watch<ShopProvider>()` en el body principal de una página.

```dart
// MAL — toda la página rebuild al cambiar cartCount
@override
Widget build(BuildContext context) {
  final shop = context.watch<ShopProvider>();
  return Scaffold(...);
}
```

**Patrón:** `Selector<P, T>` solo donde se usa el dato.

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppTopHeader(
      cartCount: context.select<ShopProvider, int>((s) => s.cartCount),
    ),
    body: ...,
  );
}
```

O `Selector` cuando el computed value es complejo:

```dart
Selector<ShopProvider, ({int count, double total})>(
  selector: (_, s) => (count: s.cartCount, total: s.subtotal),
  builder: (_, data, __) => CartBadge(count: data.count, total: data.total),
)
```

## 8. HTTP: timeouts, retries, idempotency

**Patrón para retries con backoff exponencial:**

```dart
// Ya existe _getDecodedWithRetry en habito_booking_api.dart pero usa delay lineal.
// Patrón correcto:
Future<Map<String, dynamic>> _retryingPost(
  Uri uri, {
  required Map<String, String> headers,
  required Object body,
  required Duration timeout,
  String? idempotencyKey,
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final response = await http.post(
        uri,
        headers: {
          ...headers,
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
        body: body,
      ).timeout(timeout);
      return _decodeResponse(response);
    } on TimeoutException catch (e) {
      lastError = e;
    } on http.ClientException catch (e) {
      lastError = e;
    }
    if (attempt < maxAttempts - 1) {
      // Exponencial: 500ms, 1s, 2s
      final delay = Duration(milliseconds: 500 * (1 << attempt));
      await Future<void>.delayed(delay);
    }
  }
  if (lastError is TimeoutException) {
    throw Exception('La operación demoró demasiado. Intenta nuevamente.');
  }
  throw Exception('No pudimos conectar con el servidor. Revisa tu internet.');
}
```

**Idempotency key:** generar UUID v4 en cliente (no agregar dependencia `uuid` — usar el random + hex builtin):

```dart
String _newIdempotencyKey() {
  final r = Random.secure();
  String hex(int n) => List.generate(n, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
}
```

Usar para `createBooking`, `createOrder`, `cancelBooking`, `rescheduleAppointment`.

## 9. Operaciones pesadas en `build()`

**Anti-patrones a buscar:**

- `final filtered = products.where(...).toList()` dentro de `build`
- `jsonDecode(...)` dentro de `build`
- `DateTime.parse(...)` dentro de `build` (parsea por frame)
- Sort de listas dentro de `build`

**Patrón:** cachear el resultado en `State` y recalcular solo cuando cambien las dependencias.

```dart
class _Page extends StatefulWidget { ... }
class _PageState extends State<_Page> {
  late List<Product> _filtered;
  String _query = '';
  
  void _applyFilter(String query) {
    setState(() {
      _query = query;
      _filtered = widget.products.where((p) => p.matches(query)).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(itemCount: _filtered.length, ...);
  }
}
```

## 10. Liberar recursos en `dispose()`

Checklist al modificar un `StatefulWidget`:

- `TextEditingController` → `dispose()`
- `ScrollController` → `dispose()`
- `AnimationController` → `dispose()`
- `FocusNode` → `dispose()`
- `StreamSubscription` → `cancel()`
- `Timer` → `cancel()`
- Listeners agregados con `addListener` → `removeListener` antes del dispose

Patrón:

```dart
@override
void dispose() {
  _firstNameController.dispose();
  _phoneController.dispose();
  _scrollController.dispose();
  _orderHighlightTimer?.cancel();
  super.dispose();
}
```

---

## Reglas rápidas de profiling

Antes de optimizar algo "porque parece lento":

1. Confirma con el usuario en qué pantalla/acción específica se siente lento.
2. Si el problema es scroll, primero revisa imágenes (memCacheWidth) y `addRepaintBoundaries`.
3. Si el problema es navegar a una pantalla, primero revisa fetches paralelos y `Future.wait`.
4. Si el problema es escribir en un input, revisa los listeners y debounce.
5. **No micro-optimices** sin medir. `const` constructors importan en árboles grandes, no en widgets de 5 hojas.
