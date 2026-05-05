---
name: Auditoría App Hábito
description: Evaluación de Rendimiento, Visual y Usabilidad — sin modificación de código
fecha: 2026-05-03
version_app: 2.7.0+17
---

# Auditoría App Hábito (Flutter)

**Stack revisado:** Flutter 3.3+, Material 3, Provider, WooCommerce + Amelia (Habito Booking API), Firebase Messaging, cached_network_image, flutter_secure_storage, local_auth, geolocator.

**Alcance:** ~60 archivos `.dart` en `lib/`. Sin modificaciones — solo lectura.

---

## 1. RENDIMIENTO

### Críticos

**1.1 Asset estático de 1.9 MB sin optimizar**
`assets/images/services/Corte de Cabello.png` se usa como placeholder en `shop_page.dart:131` (`_getServicePlaceholderImage()`). Decodificado en RAM puede ocupar 10–15 MB. Comprimir a WebP <300 KB o usar SVG.

**1.2 Doble fetch en `CartPage._loadPickupLocations()`**
`cart_page.dart:41-78` carga primero la caché y luego dispara un `forceRefresh: true` con `unawaited`. Cada apertura del carrito hace 2 requests al endpoint de almacenes aunque la caché esté fresca. Devolver temprano si caché < 5 min.

**1.3 `clearCache()` global en `ShopPage._loadHome()`**
`shop_page.dart:46-73` invalida toda la caché de Habito Booking (servicios + empleados + locaciones) y dispara 3 fetches paralelos en `initState` y en cada refresh. Conviene invalidación granular por recurso.

**1.4 Race condition en caché de productos**
`habito_shop_api.dart:50-118`: `_refreshListInBackground` no espera `_persistCache()`. Múltiples llamadas concurrentes pueden corromper la caché o devolver datos desactualizados. Usar el `_refreshingListKeys` Set para hacer el update atómico.

### Altos

**1.5 `context.watch<ShopProvider>()` en niveles altos**
`home_page.dart:32` y `points_page.dart:38` observan `cartCount`. Cualquier `notifyListeners()` del carrito provoca rebuild de toda la pantalla. Reemplazar por `Selector<ShopProvider, int>` localizado en el badge del header.

**1.6 Getters de precio sin memoización**
`ShopProvider.subtotal`, `taxTotal`, `cartTotal` recalculan con `fold()` cada acceso. `_formatPrice()` y `_productPrice()` se ejecutan por item por frame. En listas de 20+ productos se nota lag al hacer scroll.

**1.7 Retry sin exponential backoff**
`habito_booking_api.dart:88-127`: `_getDecodedWithRetry` usa delay fijo (450ms × 2). En conexión mala acumula latencia visible. Pasar a 450 → 900 → 1800 ms con timeout individual por intento.

### Medios

**1.8 `CachedNetworkImage` sin `memCacheWidth/Height`**
`habito_cached_network_image.dart:34-47`: imágenes de 3000×2000 se decodifican full size aunque se rendericen a 200×200. Definir `memCacheWidth` proporcional al tamaño visible (≈400 px).

**1.9 Búsqueda local O(N) sin índice**
`habito_shop_api.dart:390-420`: cada keystroke recorre todos los items. OK con 160, problemático si crece. Considerar trie o prefix index.

**1.10 `preloadSearchIndex()` en cada keystroke**
`products_archive_page.dart:174` lo invoca con `unawaited` dentro de `_handleSearchChanged`. Mover al `initState` de la página de búsqueda.

### Lo que está bien
Timeouts en HTTP, TTL + stale-while-revalidate en API, lazy init con `late`, providers bien separados por dominio, persistencia con `flutter_secure_storage`, push notifications inicializadas con manejo de errores en `main.dart`.

---

## 2. VISUAL

### Consistencia de tema

**2.1 Colores hardcodeados** — ~1.376 ocurrencias de `Color(0xFF…)` en el código, varias rompen la paleta:
- `app_top_header.dart:489`, `shop_page.dart:240` repiten `Color(0xFFD4AF37)` en lugar de `AppColors.secondary`.
- `shop_page.dart:403, 528, 750, 986` introducen variantes doradas (`0xFF8B6A28`, `0xFF9C7732`) no definidas.
- `home_page.dart:159-222` usa `0xFF0A0A0A`, `0xFF161616`, `0xFF201B14` para gradientes oscuros.
- `profile_page.dart:16-18` define constantes locales `gold`, `bg`, `card` propias.

**Sugerencia:** Ampliar `AppColors` con `goldDarker`, `goldDeep`, `darkGradientStart/End` y eliminar duplicados.

### Tipografía

**2.2 ~558 `fontSize:` hardcodeados** fuera del `TextTheme`. El theme solo define 4 estilos (headlineMedium 24, titleLarge 20, bodyLarge 16, bodyMedium 14). Faltan `bodySmall`, `labelSmall/Medium`, `titleSmall`. Ejemplos:
- `app_top_header.dart:307, 314` — labels con `fontSize: 14`.
- `home_page.dart:239, 352` — `fontSize: 20` y `22` sin entrar al tema.
- `habito_bottom_navigation_bar.dart:29` — `fontSize: 12` propio.

### Espaciado

**2.3 Sin escala de spacing.** Padding y `SizedBox` con valores 10, 12, 14, 16, 18, 20, 22 mezclados sin patrón. Crear `AppSpacing` (`xs=4, sm=8, md=12, lg=16, xl=20, xxl=24`).

### Bordes y radios

**2.4 ~708 `BorderRadius.circular()` con 10+ valores distintos** (12, 14, 16, 18, 20, 22, 26, 28, 30). El theme define 14 (inputs) y 18 (cards). Estandarizar a 3 valores: `sm=12, md=18, lg=28`.

### Estados (loading / empty / error)

**2.5 Cada pantalla resuelve los estados a su manera.**
- `ShopPage`: skeletons como contenedores blancos sin shimmer (`shop_page.dart:1009`).
- `_EmptyStrip` con icono dorado fuera de paleta (`shop_page.dart:937`).
- `_InfoCard` usa `TextButton` plano (no el botón del tema).
- Otras páginas (`MyAppointments`, `Orders`, `Cart`) probablemente con `CircularProgressIndicator` sin shimmer ni estilo.

**Sugerencia:** Crear `HabitoLoadingShimmer`, `HabitoEmptyState`, `HabitoErrorState` reutilizables.

### Headers / AppBar

**2.6 `ProfilePage` rompe el patrón** y usa `AppBar` nativo (`profile_page.dart:27-30`) sin notificaciones ni carrito, mientras el resto usa `AppTopHeader`. `MyAppointmentsPage` y `OrdersPage` tampoco lo usan.

### Bottom navigation

**2.7 `HabitoBottomNavigationBar:21`** define `indicatorColor: Color(0xFFE7D39A)` hardcodeado en lugar de `AppColors.goldSoft`.

### Sombras

**2.8 4+ variantes de `BoxShadow`** sin sistema:
- `home_page.dart:397-402` — alpha 0.04, blur 14.
- `shop_page.dart:815-820` — alpha 0.055, blur 18.
- `app_top_header.dart:458-463` — alpha 0.14.

Crear `AppShadows.light/medium/strong`.

### Imágenes y placeholders

**2.9 Fallback de imagen** en `shop_page.dart:459-480` usa gradiente oscuro ad-hoc (`0xFF2B2118 → 0xFF6E5031`). Centralizar en `HabitoCachedNetworkImage` con `AppColors.surfaceMuted` + ícono.

### Responsive

**2.10 Pocas pantallas tienen `LayoutBuilder` o breakpoints.**
- `home_page.dart:66-68` lo hace bien (`compact = maxWidth < 360`).
- `shop_page.dart:264` mantiene ancho fijo de 220 px para cards horizontales — riesgo de overflow en pantallas pequeñas.

### Splash & icono
Bien configurados en `pubspec.yaml:40-49` (negro `#111111`, logo de Hábito).

### Lo que está bien
Identidad visual fuerte (negro / dorado / crema), `AppTopHeader` reutilizable, iconografía solo Material (no mezcla), uso correcto de Material 3 con `ColorScheme.fromSeed`, tipografía base bien definida.

---

## 3. USABILIDAD

### Autenticación

Robusta en general. Login y registro:
- Validan antes del submit (`formKey.validate`).
- Mensajes específicos ("Correo inválido", "Mínimo 6 caracteres").
- Toggle ojo para mostrar contraseña (`login_page.dart:276-288`).
- Confirmación de password en registro (`register_page.dart:513`).
- `autofillHints` y `textInputAction` correctos.
- Spinner en botón durante submit.

**3.1 Inconsistencia de loading state** — `forgot_password_page.dart:16` usa flag local `_isSubmitting` mientras `delete_account_page.dart` usa `auth.isLoading` del provider. Unificar.

### Carrito y checkout

**3.2 Feedback silencioso al fallar update de cantidad.** `cart_page.dart:112-124` (`_showCartContextFeedback`) solo muestra mensaje si existe. Si la mutación falla por stock, el usuario no se entera. Mostrar siempre confirmación.

**3.3 Checkout sin indicador de progreso.** `checkout_page.dart` parece manejar varios pasos pero no se ve un stepper "1 de 3". Conviene un indicador visual + validación por paso + back claro.

**3.4 `_EmptyCartView()`** referenciado en `cart_page.dart:175` — verificar que tenga mensaje claro y CTA para volver al shop.

### Reservas (Amelia)

`bookings_page.dart` está bien estructurado:
- Flujo guiado: servicio → empleado → fecha → hora → confirmación.
- `_isLoading` y `_isLoadingAvailability` como flags separados.
- Prefill de datos del usuario logueado.
- `_isFormValid` valida todos los pasos.

**3.5 `_availabilityNoticeMessage`** declarado (línea 63) pero verificar dónde se renderiza. Si no se muestra, el usuario no recibe avisos como "no hay slots disponibles ese día".

**3.6 No hay loading visible entre pasos.** Cuando el usuario selecciona empleado y se piden los slots, debe haber feedback ("Cargando disponibilidad…").

### Mis citas

`my_appointments_page.dart` está sólido:
- 3 tabs (próximas / pasadas / historial).
- `_friendlyLoadError()` mapea timeouts y errores de conexión a mensajes amables (línea 124-143).
- Pull-to-refresh.
- Deep link desde push notification.

**3.7 Cancelación de cita** — existe `_isCancelling` (línea 23) pero verificar que el botón sea visible y con confirmación previa.

### Notificaciones

`notifications_page.dart` y `unread_notifications_button.dart` están bien:
- Badge con "9+" cuando hay muchas (línea 70-94).
- `markAllRead()` disponible.
- Delete con "Deshacer" en SnackBar.
- Pull-to-refresh.
- Filtro por tipo.

`push_notification_service.dart:115-127` navega tras 800 ms para evitar race conditions con cold start.

### Navegación

**3.8 `PushAppointmentLoaderPage`** hace `pushReplacement`. El back button puede no llevar a un destino lógico si la sesión no se restauró. Definir explícitamente el comportamiento.

`AppRoutes._parseInt/_parseBool` (líneas 65-78) protegen bien contra argumentos malformados desde push notifications.

### Forms

`register_page.dart` es ejemplar:
- `autofillHints` correctos en cada campo (givenName, familyName, email, telephoneNumber, newPassword).
- `keyboardType` específicos.
- Validadores de negocio: RUC 13 dígitos, cédula 10, teléfono 8+, password 8+.
- Campos condicionales: si selecciona "negocio", pide razón social.

**3.9 Sin `maxLength`** en `businessName`, `address`, etc. El usuario puede pegar 500+ caracteres sin feedback. Agregar contador o límite duro.

### Accesibilidad

- Tooltips en botones de notificación (`unread_notifications_button.dart:49-50`).
- Bottom nav con labels (≥48 dp).
- Buen contraste (negro/blanco/dorado).

**3.10 DatePicker en `EditProfilePage`** sin label visible — solo hint. Agregar `Semantics` o label explícito.

### Manejo offline

**3.11 Solo `MyAppointments` distingue tipos de error de red.** Cart, Checkout, Shop fallan silenciosamente o con SnackBar genérico. Agregar botón "Reintentar" en estados de error.

### Lo que está bien
Validación robusta, deep linking sólido, badges claros, mensajes de error amigables en citas, SnackBars con "Deshacer", picker de imagen con permisos manejados, biometría opcional.

---

## Top 10 acciones priorizadas

| # | Acción | Impacto | Esfuerzo |
|---|--------|---------|----------|
| 1 | Comprimir `Corte de Cabello.png` (1.9 MB → ~200 KB) | Alto | Bajo |
| 2 | Quitar doble fetch en CartPage y reemplazar `clearCache()` global por invalidación granular | Alto | Medio |
| 3 | Sustituir `context.watch` por `Selector` en HomePage / PointsPage | Alto | Bajo |
| 4 | Añadir `memCacheWidth/Height` a `HabitoCachedNetworkImage` | Medio | Bajo |
| 5 | Crear `AppSpacing`, `AppShadows`, ampliar `TextTheme` y `AppColors` (variantes oro) | Alto (mantenibilidad) | Medio |
| 6 | Crear widgets `HabitoLoadingShimmer`, `HabitoEmptyState`, `HabitoErrorState` | Alto | Medio |
| 7 | Migrar `ProfilePage`, `MyAppointments`, `Orders` a `AppTopHeader` | Medio | Medio |
| 8 | Indicador de pasos en checkout + validación por paso + botón "Reintentar" en fallos de red | Alto | Medio |
| 9 | Mostrar siempre feedback al actualizar cantidad en carrito | Medio | Bajo |
| 10 | Agregar exponential backoff y timeouts individuales en `habito_booking_api.dart` | Medio | Bajo |
