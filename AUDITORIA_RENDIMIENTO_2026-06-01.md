---
name: Auditoría de rendimiento Hábito
description: Auditoría exhaustiva de cold start y rendimiento para la próxima release de Play Store
fecha: 2026-06-01
foco: Cold start y tiempo de arranque
version_actual: 3.0.10+29
play_store_estado: Publicada
auditorias_previas:
  - PLAN_OPTIMIZACION.md (2026-05-03)
  - ESTADO_OPTIMIZACION_2026-05-08.md (2026-05-08)
  - AUDITORIA_HABITO.md
  - AUDITORIA_AMELIA.md
  - AUDITORIA_CANCEL_REAGENDAR.md
  - AUDITORIA_PRODUCTOS_CARRITO_PAGO.md
  - AUDITORIA_PUNTOS.md
---

# Auditoría de rendimiento — App Hábito · 2026-06-01

## 0. Datos cuantitativos medidos

| Métrica | Valor | Observación |
|---|---|---|
| `flutter analyze` | **0 issues** | Limpio (151 s ejecución). |
| AAB release | **48.26 MB** | `build/app/outputs/bundle/release/app-release.aab` |
| APK fat release | **58.96 MB** | `build/app/outputs/flutter-apk/app-release.apk` |
| `libflutter.so` (arm64-v8a) | 10.79 MB | Engine Flutter |
| `libapp.so` (arm64-v8a) | 7.69 MB | Código Dart compilado AOT |
| ABIs nativas en AAB | arm64-v8a, armeabi-v7a, x86_64 | El AAB se split automáticamente al instalar |
| Assets Flutter totales | **151.6 KB** | Solo 5 imágenes — ya optimizado |
| `lib/` total .dart | ~50,000 LOC | 14 archivos > 700 líneas |
| Dependencias prod | **20 paquetes** | Razonable para una app de este tamaño |
| `cacheWidth/Height` o `memCacheWidth/Height` | **0 ocurrencias** | ⚠️ Hallazgo crítico para gama baja |
| `RepaintBoundary` explícitos | **0** | Aceptable; Flutter agrega los necesarios |
| Splits ABI configurados | **No** | Cada usuario descarga libs de su ABI vía AAB, pero el APK universal pesa 59 MB |

**Punto de partida**: el código está limpio (cero warnings), el design system está aplicado, los puntos críticos de robustez (idempotency, retry, persistencia de carrito) están en su lugar. Lo que queda es **eliminar el peso del cold start y el peso visible del APK**.

---

## 1. Resumen ejecutivo

La app está en **muy buen estado de calidad de código**. Las optimizaciones del 2026-05-08 fueron ejecutadas casi por completo. Los problemas de rendimiento **restantes** son específicos y medibles:

### Top 5 problemas críticos de cold start (orden de impacto)

| # | Problema | Impacto estimado | Esfuerzo |
|---|---|---|---|
| 1 | `main()` hace **4 awaits secuenciales** antes de `runApp()` | **600-1500 ms** en gama baja | 1h |
| 2 | `home_page` (primer tab visible) dispara request de empleados sin necesidad | 300-800 ms latencia hasta primer scroll útil | 30 min |
| 3 | **Ningún `cacheWidth`/`memCacheWidth`** en imágenes — decodifican a resolución completa | 30-100 MB picos de RAM en gama baja | 1h |
| 4 | `flutter_native_splash` legacy en lugar de **Android 12+ Splash API** | Doble splash visible (sistema + Flutter) en Android 12+ | 30 min |
| 5 | Sin **AAB ABI splits** explícitos + ningún `--obfuscate --split-debug-info` documentado en build | APK Play Store grande de descarga | 30 min |

**Estimación realista de ganancia**: cold start en gama media (Snapdragon 6xx) de **~3.2 s → ~1.8 s** con esta sola release. Tamaño descargable Play Store reducible **~15-25%** sin tocar funcionalidad.

---

## 2. Hallazgos detallados — Cold Start (FOCO)

### 2.1 [CRÍTICO] `main()` bloquea con 4 awaits secuenciales

📄 [lib/main.dart:20-62](lib/main.dart#L20)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: ...);     // ~150-400ms
  try { await AnalyticsService.initialize(); }    // ~50-200ms
  ...
  try { await PushNotificationService.initialize(); }  // ~200-600ms (¡FCM permission prompt!)
  try { await ReferralLinkService.initialize(); }      // ~100-400ms (lee initial link + install referrer + SharedPreferences)
  runApp(const HabitoApp());
}
```

**Por qué duele en cold start**:
- `WidgetsFlutterBinding.ensureInitialized()` + `Firebase.initializeApp()` son **obligatorios** antes de cualquier `runApp`. Los otros 3 NO lo son.
- `PushNotificationService.initialize()` hace `_fcm.requestPermission()`, `_fcm.setForegroundNotificationPresentationOptions()`, `_localNotif.initialize()`, `_fcm.getInitialMessage()` — todo en serie. En primera apertura puede mostrar el prompt de notificaciones, congelando la UI mientras el usuario decide.
- `ReferralLinkService.initialize()` llama `_appLinks.getInitialLink()` (IPC al sistema) + `_readInstallReferrerOnce()` (Google Play install referrer SDK, otro IPC bloqueante).

**Recomendación** (no aplicar aún — esto es solo el reporte):
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);   // Único bloqueante real

  FlutterError.onError = ...;
  PlatformDispatcher.instance.onError = ...;

  runApp(const HabitoApp());

  // El resto en background después del primer frame.
  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeBackgroundServices() async {
  await AnalyticsService.initialize();
  await PushNotificationService.initialize();
  await ReferralLinkService.initialize();
}
```

**Ganancia medible**: 400-1000 ms menos hasta que el usuario ve el splash de Flutter.

**Riesgo**: si `PushNotificationService.initialize()` reacciona a un push que abrió la app, hay que orquestar bien: hoy `_safeNavigateToPushAppointment` ya usa `WidgetsBinding.instance.addPostFrameCallback` con retry; el patrón aguanta diferir el init.

---

### 2.2 [CRÍTICO] Home (primer tab) carga empleados desde red de inmediato

📄 [lib/features/team/presentation/widgets/team_habito_home_section.dart:30-114](lib/features/team/presentation/widgets/team_habito_home_section.dart#L30)

```dart
@override
void initState() {
  super.initState();
  _loadBarbers();   // ← Llamado al primer build de HomePage
}

Future<void> _loadBarbers() async {
  final cachedEmployees = await HabitoBookingApi.getCachedEmployees();  // Lee cache disco
  // pinta cache si hay
  final employees = await HabitoBookingApi.getEmployees(forceRefresh: cachedEmployees.isNotEmpty);
  // pinta de nuevo
}
```

**Cadena**: `getCachedEmployees()` → `_ensureLoaded()` → `_loadCache()` → `getApplicationDocumentsDirectory()` (IPC) + `file.readAsString()` + `jsonDecode()`. Esto pasa **antes** del primer paint útil de la home.

Luego `HabitoBookingApi.getEmployees(forceRefresh: true)` golpea `/employees-enriched` con `_timeout=AppConfig.bookingTimeout`, **3 intentos** (`attempts: 3`).

**Por qué duele**: el usuario abre la app, ve un loading del componente "Team Hábito" en home — pero esa sección está debajo del fold. Aún así, la I/O y el work de network están corriendo, robando ciclos del isolate principal mientras se construye el resto del scroll.

**Recomendación**:
- Diferir `_loadBarbers()` con `WidgetsBinding.instance.addPostFrameCallback` (1 frame después).
- O mejor: solo mostrar la sección si hay cache, e ir a red **lazy** cuando el scroll se acerque.

**Ganancia**: 200-500 ms de jank menos durante el primer scroll.

---

### 2.3 [CRÍTICO] `ShopProvider().hydrate()` se ejecuta dentro de `create` de Provider

📄 [lib/main.dart:80-82](lib/main.dart#L80)

```dart
ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
  create: (_) => ShopProvider()..hydrate(),   // ⚠️ ShouldRebuild en cualquier rebuild
  update: (_, auth, shop) => (shop ?? (ShopProvider()..hydrate()))
    ..updateAuthState(isLoggedIn: auth.isLoggedIn),
),
```

`hydrate()` lee SharedPreferences (`habito_shop_cart_v1`). El `create` corre cuando el `MultiProvider` se monta — está OK. **Pero el fallback `?? (ShopProvider()..hydrate())` en `update`** es código muerto que podría disparar `hydrate()` un segundo (o tercer) tiempo si el `shop` viene null por alguna razón, creando un Provider huérfano.

**Recomendación**:
```dart
ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
  create: (_) => ShopProvider()..hydrate(),
  update: (_, auth, shop) {
    shop!.updateAuthState(isLoggedIn: auth.isLoggedIn);
    return shop;
  },
),
```

Idem para `PointsProvider`. El `?? PointsProvider()` también es defensivo innecesario que ensucia.

**Ganancia**: ~20-80 ms en arranque (los `hydrate()` van a disco) y elimina riesgo de double-init.

---

### 2.4 [ALTO] AuthGate hace **dos** lecturas de storage seguidas

📄 [lib/features/auth/presentation/pages/auth_gate_page.dart:80-104](lib/features/auth/presentation/pages/auth_gate_page.dart#L80)

```dart
Future<void> _bootstrapSession() async {
  final auth = context.read<AuthProvider>();
  final hasSavedSession = await auth.hasSavedSession();   // Lee token + user de secure storage
  await auth.init();                                      // Lee token + user + biometric flag DE NUEVO
  ...
}
```

`hasSavedSession()` y `init()` hacen ambos `_storage.getToken()` + `_storage.getUser()`. **El secure storage es lento en Android** (10-50 ms por llamada). Estás duplicando 2 llamadas a `flutter_secure_storage` que cada una abre el keystore.

Además dentro de `init()`:
```dart
final refreshedUser = await _api.getProfile(savedToken);   // Network bloqueante
await PushNotificationService.registerToken(authToken: savedToken);   // Network bloqueante
await _identifyAnalyticsUser(_user);                       // Crashlytics + Firebase + Facebook + TikTok
```

Tres llamadas en serie antes de marcar `_isInitialized = true`. Eso es **el tiempo entre el splash y el primer frame de Home** para un usuario ya logueado.

**Recomendación**:
1. Eliminar `hasSavedSession()` y simplemente leer el resultado de `init()` (que ya hace lo mismo).
2. Dentro de `init()`: persistir la sesión local **inmediatamente** y notificar listeners; lanzar `_refreshProfileAfterAuth` y `PushNotificationService.registerToken` en `unawaited`.

```dart
Future<void> init() async {
  if (_isInitialized) return;
  _isLoading = true;
  notifyListeners();

  _biometricEnabled = await _storage.isBiometricEnabled();
  _biometricAvailable = await BiometricService.isAvailable();
  final savedToken = await _storage.getToken();
  final savedUser = await _storage.getUser();

  if (savedToken != null && savedToken.isNotEmpty && savedUser != null) {
    _token = savedToken;
    _user = savedUser;
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();   // ⚡ Usuario ya entra a Home con la sesión cacheada

    // Background:
    unawaited(_refreshProfileAfterAuth(savedToken));
    unawaited(PushNotificationService.registerToken(authToken: savedToken));
    unawaited(_identifyAnalyticsUser(_user));
    return;
  }

  _isInitialized = true;
  _isLoading = false;
  notifyListeners();
}
```

**Ganancia**: 300-900 ms hasta primer pintado de Home para sesión existente.

---

### 2.5 [ALTO] Imágenes sin `cacheWidth`/`memCacheWidth` — golpe de memoria

📄 Verificado: **0 ocurrencias** en todo `lib/` de `cacheWidth`, `cacheHeight`, `memCacheWidth`, `memCacheHeight`.

Esto significa:
- Cada `CachedNetworkImage` decodifica las imágenes **a su resolución nativa**. Un JPG de barbero de 1200×1200 px en una tarjeta de 80×80 px en pantalla decodifica 5.76 millones de pixels en RAM en lugar de 25.6k.
- En `team_habito_home_section`, `shop_page`, `products_archive_page`, `bookings_page` — las imágenes son siempre miniaturas. Sin `memCacheWidth` cada imagen consume **35× más memoria** que la necesaria.
- En **gama baja (1-2 GB RAM)** esto es una causa frecuente de jank, GC pauses, y eventualmente OOM kill.

**Recomendación**: en `HabitoCachedNetworkImage` agregar:
```dart
HabitoCachedNetworkImage({
  ...
  this.targetWidth,   // px lógico esperado en pantalla
  this.targetHeight,
});

// En build:
final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
return CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: targetWidth != null ? (targetWidth! * dpr).round() : null,
  memCacheHeight: targetHeight != null ? (targetHeight! * dpr).round() : null,
  ...
);
```

Luego pasar `targetWidth: 90` (o el ancho real) en los call sites de listas. El esfuerzo es bajo, el impacto en gama baja es enorme.

**Ganancia**: -30 a -100 MB de RAM en pantallas con muchas imágenes. Menos GC, menos jank.

---

### 2.6 [ALTO] `flutter_native_splash` legacy + LaunchTheme Android

📄 [pubspec.yaml:54-58](pubspec.yaml#L54), [android/app/src/main/res/drawable/launch_background.xml](android/app/src/main/res/drawable/launch_background.xml)

Hoy se usan **dos splash distintos** (puede generar flash visible):
1. El sistema muestra `@style/LaunchTheme` con `drawable/launch_background.xml` (XML con bitmap).
2. Apenas Flutter arranca, muestra el splash configurado por `flutter_native_splash` (otro bitmap centrado).
3. Luego AuthGate pinta `_AuthSplashScreen` (un tercer splash con logo + CircularProgressIndicator).

En Android 12+, el sistema impone un **Splash Screen API** propio que ignora `windowBackground` salvo configuración explícita. Esto causa que en **Android 12+ los usuarios vean el ícono del launcher en círculo blanco** unos ms, después el splash de Flutter, después el `_AuthSplashScreen` con CircularProgressIndicator. Tres pantallas distintas en arranque.

**Recomendación**:
- Migrar a la **Android 12 Splash Screen API** vía `androidx.core:core-splashscreen` y el plugin `flutter_native_splash` versión >= 2.4 que ya tiene soporte (lo tienes en 2.4.6, **pero no hay sección `android_12:` en pubspec.yaml**, hay que añadirla).
- Hacer que el splash nativo se mantenga visible hasta que Flutter pinte el primer frame (`flutter_native_splash` soporta `keep_alive` y la API `FlutterSplashScreen.remove()`).
- Eliminar `_AuthSplashScreen`: aprovechar el splash nativo hasta que `AuthGate` decida si va a `MainNavigationPage` o `_BiometricGateScreen`.

**Ganancia**: 1 sola pantalla de splash en lugar de 3. Visualmente la app se siente "instantánea".

---

### 2.7 [MEDIO] No hay tree-shake estricto de fonts ni `--split-debug-info`

No se ven indicios de flags de build documentados (`--split-debug-info`, `--obfuscate`, `--tree-shake-icons`). Material Icons en Flutter sin `--tree-shake-icons` aporta ~1-1.5 MB a `libapp.so`.

**Recomendación** para el comando de build de release:
```bash
flutter build appbundle \
  --release \
  --tree-shake-icons \
  --obfuscate \
  --split-debug-info=./symbols/3.1.0
```

`--tree-shake-icons` ya está activado por defecto desde Flutter 3.x cuando se usa `MaterialIcons` directos (no a través de strings). Verificar con el reporte de `flutter build` (sale "Tree-shaking" en la salida si funciona).

Documentar el comando en `README.md` para que la próxima release lo use consistente.

**Ganancia**: -1 a -2 MB del AAB.

---

### 2.8 [MEDIO] ProGuard `-keep` demasiado amplio

📄 [android/app/proguard-rules.pro](android/app/proguard-rules.pro)

```
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.tiktok.** { *; }
-keep class com.facebook.** { *; }
-keep class androidx.lifecycle.** { *; }
```

Estos `-keep ... { *; }` desactivan minify/optimize para todas las clases de esos paquetes. Firebase + GMS solos son **~3-5 MB después de R8**. Si confiamos en los `consumer-proguard-rules` que ya incluyen las propias librerías, podemos relajar varias.

**Recomendación**: probar quitar los `-keep` redundantes (Firebase y GMS ya incluyen sus reglas en sus AARs) **en una build de prueba** y validar:
- Crashlytics envía crashes.
- FCM push abre la app.
- Facebook events y TikTok events siguen reportando.

Si no se rompen, los `-keep` pueden bajarse a `-dontwarn` y reglas más específicas.

**Ganancia**: -1 a -3 MB de `libapp.so` y mejor optimización agresiva de R8.

---

## 3. Hallazgos detallados — Rendimiento general

### 3.1 [ALTO] `getApplicationDocumentsDirectory()` repetido en cada operación de caché

📄 [habito_booking_api.dart:1819-1827](lib/features/shop/data/services/habito_booking_api.dart#L1819)

```dart
static Future<File> _cacheFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${dir.path}${Platform.pathSeparator}booking_cache');
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  return File('${cacheDir.path}${Platform.pathSeparator}catalog.json');
}
```

Cada `clearServicesCache()`, `clearEmployeesCache()`, `_persistCache()`, `_loadCache()` ejecuta IPC a `path_provider` + `cacheDir.exists()` + (a veces) `cacheDir.create()`. Lo mismo pasa en `notification_inbox_service.dart` con `_file()`.

**Recomendación**: cachear el `File` (o el `Directory`) en una variable estática:

```dart
static File? _cachedCacheFile;
static Future<File> _cacheFile() async {
  if (_cachedCacheFile != null) return _cachedCacheFile!;
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${dir.path}${Platform.pathSeparator}booking_cache');
  if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
  _cachedCacheFile = File('${cacheDir.path}${Platform.pathSeparator}catalog.json');
  return _cachedCacheFile!;
}
```

**Ganancia**: ahorra 10-30 ms por llamada × 10-20 llamadas por sesión = 100-600 ms acumulados.

---

### 3.2 [ALTO] `UnreadNotificationsButton` re-lee TODO el inbox solo para contar no leídos

📄 [lib/shared/widgets/unread_notifications_button.dart:38-41](lib/shared/widgets/unread_notifications_button.dart#L38)

```dart
@override
void initState() {
  super.initState();
  Future.microtask(NotificationInboxService.refreshUnreadCount);  // → load()
}
```

`NotificationInboxService.refreshUnreadCount()` llama `load()` que lee el archivo entero, hace `jsonDecode`, normaliza cada item, los ordena por fecha y los re-escribe si hay repair. **Todo solo para contar los no leídos.** Este componente está en el header de cada pantalla, así que se ejecuta múltiples veces.

**Recomendación**: separar `loadCountOnly()` que solo lea y cuente sin normalizar/reescribir:

```dart
static Future<int> loadCountOnly() async {
  final file = await _file();
  if (!await file.exists()) return 0;
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! List) return 0;
  return decoded.whereType<Map>().where((m) => m['read'] != true).length;
}
```

O mantener el count en SharedPreferences como cache, refrescando solo cuando llega un push o se abre la pantalla de notificaciones.

**Ganancia**: 30-150 ms cada vez que se abre una página con header.

---

### 3.3 [ALTO] `MainNavigationPage` usa `IndexedStack` con TODAS las páginas vivas

📄 [lib/shared/widgets/main_navigation_page.dart:181-187](lib/shared/widgets/main_navigation_page.dart#L181)

```dart
body: IndexedStack(
  index: _currentIndex,
  children: List<Widget>.generate(
    _pages.length,
    (index) => _pages[index] ?? const SizedBox.shrink(),
  ),
),
```

**Bien hecho**: hay lazy build (`_pages[index] ??= _buildPage(index)`). Cuando el usuario nunca visita una tab, esa tab nunca se construye. ✅

**Mal hecho**: una vez construida, **nunca se libera**. Si el usuario navegó por las 5 tabs, las 5 viven en RAM con sus controllers, scroll positions, listas en memoria. Eso es lo que se quiere para preservar estado, pero en gama baja puede causar OOM.

**Recomendación condicional**: solo si los reportes de Crashlytics muestran crashes OOM en gama baja, considerar un **soft dispose**: cuando una tab no es la activa por > 60s y no hay scroll position relevante, reconstruirla la próxima vez. Por ahora, monitorear.

---

### 3.4 [MEDIO] `context.watch` en lugar de `context.select` en hojas calientes

Verificado: solo **5 usos de `context.watch`** restantes:

| Archivo | Línea | Provider | Recomendación |
|---|---|---|---|
| `checkout_page.dart` | 1021 | `PointsProvider` | OK, este widget usa el summary completo |
| `product_detail_page.dart` | 482 | `ShopProvider().cartCount` | **Cambiar a `context.select`** — solo necesita `cartCount` |
| `bookings_page.dart` | 3273 | `ShopProvider` | Revisar — si solo lee `cartCount`, `select` |
| `bookings_page.dart` | 3274 | `AuthProvider` | OK si lee múltiples campos |
| `bookings_page.dart` | 3275 | `PointsProvider` | OK si lee múltiples campos |

**Acción concreta**: cambiar 2 (product_detail_page:482, bookings_page:3273 si aplica). Lo demás está bien.

**Ganancia**: rebuilds más selectivos → menos jank al editar el carrito o cambiar puntos.

---

### 3.5 [MEDIO] `home_page.dart` usa `ListView` no virtualizado con 5 secciones grandes

📄 [lib/features/home/presentation/pages/home_page.dart:73-164](lib/features/home/presentation/pages/home_page.dart#L73)

`ListView(children: [...])` construye **todos los hijos** de una vez (no es virtualizado). Para la home está OK porque son 5-6 secciones, pero algunas son pesadas:
- `_HeroSection` con gradient + shadow
- `GridView.count(shrinkWrap: true, physics: NeverScrollable)` — 5 cards
- `TeamHabitoHomeSection` — otro `ListView.builder` horizontal
- `_EditorialStrip` — `ListView.separated` horizontal
- `_ActivityCard` con `Consumer<AuthProvider>`

**No es crítico** porque el contenido cabe en ~1.5 viewports y se ve ágil. Pero en cold start cada uno de estos widgets se construye antes del primer frame.

**Recomendación condicional**: si después de aplicar las optimizaciones 2.1-2.4 sigue habiendo jank visible en home, migrar a `CustomScrollView` con `SliverList`/`SliverToBoxAdapter` y mover `_EditorialStrip` + `TeamHabitoHomeSection` debajo de la fold para que se construyan en `addPostFrameCallback`.

---

### 3.6 [MEDIO] No hay `RepaintBoundary` en list items con shadow + gradient

Verificado: **0 ocurrencias** de `RepaintBoundary` en `lib/`.

Flutter agrega boundaries automáticos en `ListView.builder`, pero no en `ListView(children: [...])`. La home, shop, bookings tienen tarjetas con `boxShadow`, `borderRadius`, gradients — cualquier rebuild de un parent fuerza repintar todo.

**Recomendación**: en componentes con sombras complejas (tarjetas de quick action, hero sections, editorial cards) envolver con `RepaintBoundary`. Esto cachea la capa visual y reduce el costo de rebuild.

**Ganancia**: menos jank durante interacciones (tap en bottom nav que cause un rebuild del root).

---

## 4. Hallazgos detallados — Tamaño descargable

### 4.1 [ALTO] AAB de 48 MB es alto para una app de barbería

**Composición típica**:
- Flutter engine: ~10 MB por ABI × 3 ABIs en AAB = pero Play split por ABI → ~10 MB descargable.
- `libapp.so` (código Dart): ~7.7 MB por ABI.
- Firebase Core + Messaging + Analytics + Crashlytics: ~3-4 MB.
- TikTok Business SDK: ~2-3 MB.
- Facebook App Events: ~1.5 MB.
- Recursos + assets: ~500 KB.

**Hipótesis**: TikTok Business SDK es candidato a salir si no aporta ROI medible. Facebook App Events también. Validar con producto.

**Recomendación**:
1. Confirmar con el equipo de marketing si TikTok Ads está activamente comprando y atribuyendo. Si no, **borrar** dependency + plugin + manifest. Ahorro: ~2-3 MB.
2. Idem Facebook App Events. Ahorro: ~1.5 MB.
3. Si ambos son necesarios pero no para todos los usuarios, considerar inicialización **lazy** después del primer login (no se necesitan en cold start).

---

### 4.2 [MEDIO] `compileSdk = flutter.compileSdkVersion` sin pin

Buena práctica de Flutter 3.x, pero significa que cualquier update del SDK puede mover el `compileSdk` y romper sin warning. Para una app en producción, pinear `compileSdk = 35` (o el target estable de la fecha) y revisar antes de cada upgrade.

---

### 4.3 [BAJO] APK universal (`app-release.apk` 58.96 MB) no se sube a Play

El AAB de Play es lo que importa (48.26 MB). Pero si alguna vez se distribuye el APK directo (por WhatsApp, por testers), 59 MB es un disuasor. Documentar que **siempre se usa AAB para Play Store** y considerar `flutter build apk --split-per-abi` cuando se necesita APK suelto.

---

## 5. Hallazgos detallados — Memoria y RAM

### 5.1 [REVISIÓN] `PushNotificationService._cachePushImage` descarga sin límite de tamaño

📄 [push_notification_service.dart:561-599](lib/core/services/push_notification_service.dart#L561)

Descarga la imagen del push completa y la guarda en disco. **No hay límite de tamaño**. Si alguien envía un push con una imagen de 10 MB, se descarga entera y se mantiene en memoria mientras se escribe. Y `getTemporaryDirectory()` no se purga.

**Recomendación**:
- `Content-Length` máximo: 2 MB.
- Periódicamente (al abrir app), limpiar `$tempDir/push_images` de archivos > 7 días.

---

### 5.2 [REVISIÓN] `flutter_secure_storage` se invoca múltiples veces por sesión

`getToken()`, `getUser()`, `isBiometricEnabled()` cada uno abre el keystore. En Android cada llamada cuesta 10-30 ms. Acumulado a lo largo de un cold start con biometric + auth refresh + push register, son ~100-200 ms gastados.

**Recomendación**: cachear en memoria los valores leídos. `AuthStorage` puede mantener `_cachedToken`, `_cachedUser`, `_cachedBiometric` y solo ir a disco la primera vez por sesión.

---

## 6. Hallazgos menores

| # | Observación | Acción |
|---|---|---|
| 6.1 | `MainNavigationPage._didScheduleAppUpdateCheck` corre `AppUpdateService.maybePromptForUpdate(context)` en cada `didChangeDependencies` la primera vez. OK. | — |
| 6.2 | `analyze.txt`, `analyze_round2.txt`, `analyze_after_auth.txt` son artefactos viejos en raíz. | Eliminar / mover a `_backups/`. |
| 6.3 | `_apk_inspect/` directorio sospechoso en `habito/`. | Verificar si está versionado y purgar. |
| 6.4 | `flutter_native_splash` ejecuta `image: assets/images/logo_habito.png` (21 KB). OK. | — |
| 6.5 | `setBiometricEnabled(true)` por default. Si el dispositivo no tiene huella registrada, `_AuthSplashScreen` no se ve nunca pero `BiometricService.isAvailable()` se llama igual (50 ms). | Ya está dentro de un `try` — bajo costo. |
| 6.6 | `add_2_calendar`, `share_plus`, `image_picker`, `local_auth`, `geolocator` son plugins pesados — usados solo en pantallas específicas. Idealmente lazy load. | Flutter no soporta lazy load real de plugins; mitigar con `--obfuscate` y R8 agresivo. |

---

## 7. Roadmap propuesto para esta release (Play Store)

### Fase A — Cold start (alta prioridad, 1 día de trabajo)

| Tarea | Archivo | Estimado |
|---|---|---|
| A.1 Diferir `AnalyticsService.initialize`, `PushNotificationService.initialize`, `ReferralLinkService.initialize` a post-`runApp` | `lib/main.dart` | 30 min |
| A.2 Limpiar fallback `?? Provider()..hydrate()` en `MultiProvider.update` | `lib/main.dart` | 10 min |
| A.3 Fusionar `hasSavedSession()` con `init()` y hacer post-auth tasks `unawaited` | `auth_gate_page.dart`, `auth_provider.dart` | 1 h |
| A.4 Defer `_loadBarbers()` en `team_habito_home_section` a `addPostFrameCallback` | `team_habito_home_section.dart` | 15 min |
| A.5 Cachear `File` en `_cacheFile()` y `NotificationInboxService._file()` | `habito_booking_api.dart`, `notification_inbox_service.dart` | 20 min |
| A.6 `loadCountOnly()` en `NotificationInboxService` para `UnreadNotificationsButton` | `notification_inbox_service.dart`, `unread_notifications_button.dart` | 30 min |
| A.7 Cachear lectura de secure storage en `AuthStorage` | `auth_storage.dart` | 20 min |

**Total A: ~3.5 horas. Ganancia estimada: -700 a -1500 ms cold start en gama media.**

### Fase B — Memoria (alta prioridad, medio día)

| Tarea | Archivo | Estimado |
|---|---|---|
| B.1 Agregar `targetWidth`/`targetHeight` a `HabitoCachedNetworkImage` que mapeen a `memCacheWidth/Height` con DPR | `habito_cached_network_image.dart` | 30 min |
| B.2 Pasar `targetWidth`/`targetHeight` en `team_habito_home_section`, `shop_page`, `products_archive_page`, `bookings_page` lists | varios | 1.5 h |
| B.3 Limitar tamaño de `_cachePushImage` y purgar carpeta vieja | `push_notification_service.dart` | 30 min |

**Total B: ~2.5 horas. Ganancia: -30 a -100 MB de pico de RAM en gama baja.**

### Fase C — Tamaño descargable (alta prioridad, medio día)

| Tarea | Estimado |
|---|---|
| C.1 Validar comercialmente si TikTok Business SDK y Facebook App Events están aportando — si no, removerlos | Coordinación: 1 día. Implementación: 30 min. |
| C.2 Migrar a Android 12+ Splash API (config en pubspec + remover `_AuthSplashScreen`) | 1 h |
| C.3 Documentar comando de build oficial `flutter build appbundle --release --tree-shake-icons --obfuscate --split-debug-info=symbols/X.Y.Z` en `README.md` | 15 min |
| C.4 Probar release con `-keep` reducido en ProGuard y validar Crashlytics + FCM + Meta + TikTok | 2 h |

**Total C: ~4 horas (sin contar decisión de TikTok/Meta). Ganancia: -3 a -6 MB AAB.**

### Fase D — Rebuilds y jank (opcional, medio día)

| Tarea | Estimado |
|---|---|
| D.1 `context.watch` → `context.select` en `product_detail_page:482`, `bookings_page:3273` si aplica | 20 min |
| D.2 `RepaintBoundary` en tarjetas con sombra (quick action cards, editorial strip, activity card) | 30 min |
| D.3 Limpieza de archivos `analyze*.txt` y `_apk_inspect/` | 10 min |

**Total D: ~1 hora. Ganancia: menos jank perceptible.**

---

## 8. Resumen para la próxima release

**Si solo hubiera tiempo para una cosa**: Fase A (cold start). Es el problema más visible para un usuario que abre la app después de actualizar.

**Si hay 1 día completo**: A + B. Cold start + memoria. La app va a sentirse notablemente más rápida y estable.

**Si hay 2 días**: A + B + C. Más rápida, más estable, más liviana de descargar. La descripción "mejora significativa" de Play Store estará respaldada.

**Métricas que recomiendo medir antes y después con Firebase Performance Monitoring**:
- `app_start` (Firebase trace automático).
- Custom trace: `home_first_paint` (desde `runApp` hasta primer scroll de home).
- Custom trace: `auth_gate_resolved` (desde `runApp` hasta que `_isBootstrapping=false`).
- `_image_decode_time` por imagen pesada.

Activar Performance Monitoring en `pubspec.yaml` con `firebase_performance: ^0.10.x` (no agrega peso significativo y da datos reales de producción).

---

## 9. Lo que NO recomiendo tocar en esta release

- **Migración a Riverpod / Bloc**: el código con Provider funciona, los providers son simples y los nuevos `context.select` ya cubren la mayoría de optimizaciones. Migrar es semanas de trabajo sin ganancia clara en rendimiento.
- **Reescribir `bookings_page` (4452 líneas)**: es grande pero está limpio. Tocar funcionalidad core 3 días antes de release es riesgoso.
- **Activar Impeller en Android**: estable en iOS pero en Android todavía hay quirks reportados con FCM, plugins de cámara y composición de gradients. Esperar a Flutter 3.30+ con Impeller default en Android.
- **Code splitting con `deferred as`**: Flutter Android no soporta dynamic code loading útil aún. Esfuerzo alto, ganancia nula.

---

## 10. Decisiones que requieren validación del producto

| Tema | Pregunta | Quien decide |
|---|---|---|
| TikTok Business SDK | ¿Está reportando conversiones / tiene ROI medible? Si no, quitarlo da -2 MB | Marketing |
| Facebook App Events | Idem | Marketing |
| `flutter_native_splash` legacy | Cambio cosmético del primer flash de pantalla | Producto + diseño |
| Performance Monitoring | Agregar `firebase_performance` para medir antes/después | Tech + Producto |
| Borrar archivos `.bak-*` y `analyze*.txt` | Limpieza de repo | Tech (autorizar) |

---

## Conclusión

El código está en muy buen estado tras las dos rondas de optimización previas. Las ganancias **más grandes** restantes están en el **cold start path** (main, auth_gate, primer paint de home) y en la **decodificación de imágenes**. Ambas se pueden cerrar en 1-2 días de trabajo con bajo riesgo de regresión.

Las mejoras de tamaño descargable son medianas pero acumulativas: tree-shake-icons + obfuscate + revisión de SDKs de marketing pueden reducir 3-6 MB sin tocar funcionalidad.

La auditoría sugiere **Fase A + Fase B como mínimo** para llamar a esta release "mejora significativa de rendimiento" con honestidad ante los usuarios de Play Store.
