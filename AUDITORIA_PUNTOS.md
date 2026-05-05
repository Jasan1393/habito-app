---
name: Auditoría módulo de Puntos
description: Análisis del programa de puntos (myCRED) y su integración con citas y órdenes
fecha: 2026-05-03
endpoints: GET /points/summary · GET /points/history
backend: WordPress + plugin Habito + myCRED
---

# Auditoría — Módulo de Puntos

El programa de puntos está implementado sobre **myCRED** (plugin WordPress) y expuesto al cliente a través de dos endpoints custom (`/points/summary` y `/points/history`). En la app vive en su propio feature (`lib/features/points/`) con `PointsApi`, `PointsProvider`, modelos `PointsSummary` y `PointsHistoryEntry`, y la pantalla `PointsPage`. Se integra con dos flujos de redención: **reservas** (`bookings_page.dart`) y **órdenes** (`checkout_page.dart`).

## TL;DR

- **Arquitectura limpia**: API + Provider + Models + Page bien separados, con cache de 5 min.
- **Doble fuente de verdad** dentro del mismo provider: `updateSession()` *sintetiza* un `PointsSummary` desde `AuthUser` cada vez que cambia la sesión, sobrescribiendo el que pudo venir del API. En la práctica funciona pero crea ventanas de inconsistencia.
- **Lógica de redención duplicada** en `bookings_page.dart` y `checkout_page.dart` — los dos archivos reimplementan `_resolvePointsState`, `_pointsToUse`, `_pointsDiscount`, `_bookingPointsHelperMessage` con código casi idéntico.
- **Dos campos del modelo nunca se usan** (`bookingPointsEnabled`, `orderPointsEnabled`). Se parsean del JSON pero ningún consumidor los lee.
- **Sin paginación de historial**: `PointsApi.getHistory()` está definido y soporta `page` + `limit`, pero nadie lo llama. El usuario solo ve los primeros 20 movimientos del summary.
- **Sin protección contra doble-gasto**: el saldo local no se decrementa optimísticamente al reservar/comprar. Si el usuario tiene 100 puntos y abre una reserva (50 puntos) y un checkout en otra pantalla, ambos pueden enviar 100.
- **Inconsistencia en el formato de `redeem_points`**: en `createBooking` va como número, en `createOrder` va como string formateado.

---

## 1. Arquitectura del módulo

```
┌──────────────────┐     ┌──────────────────┐
│   PointsApi      │────▶│ /points/summary  │
│ (HTTP + decode)  │────▶│ /points/history  │  (este NO se usa)
└────────┬─────────┘     └──────────────────┘
         │ resultado
         ▼
┌──────────────────────────────────────────┐
│         PointsProvider                   │
│  ┌────────────┐    ┌──────────────────┐ │
│  │  load()    │    │ updateSession()  │ │
│  │ desde API  │    │ síntesis desde   │ │
│  │            │    │   AuthUser       │ │
│  └─────┬──────┘    └──────┬───────────┘ │
│        └──── _summary ────┘             │
└──────────────────────────────────────────┘
         │
         ▼
┌──────────────────┬───────────────────┬───────────────────┐
│   PointsPage     │ BookingsPage      │  CheckoutPage     │
│  (visualización) │ _bookingPointsToUse│  _pointsToUse    │
│                  │ _bookingPointsDis  │  _pointsDiscount │
└──────────────────┴───────────────────┴───────────────────┘
                                │
                                ▼
                ┌─────────────────────────┐
                │ HabitoBookingApi        │
                │   .createBooking(...,   │
                │      redeemPoints,      │
                │      redeemAmount)      │
                └─────────────────────────┘
                ┌─────────────────────────┐
                │ HabitoShopApi           │
                │   .createOrder(...,     │
                │      redeemPoints)      │
                └─────────────────────────┘
```

---

## 2. PointsApi (`points_api.dart`)

**Endpoints**:
- `GET /points/summary?history_limit=20` → devuelve summary + primeros N items
- `GET /points/history?page=N&limit=20` → paginado (definido, no usado)

**Headers**: `Accept`, `Content-Type: application/json`, `Authorization: Bearer {token}`
**Timeout**: `AppConfig.authTimeout` (20 s)
**Retries**: 0

### Hallazgos

**2.1 — Cero retries en endpoints sensibles.**
Si el usuario tiene mala conexión, el saldo nunca se actualiza. Conviene un retry con backoff (1 + 2 s) ya que la operación es read-only e idempotente.

**2.2 — `getHistory()` definido pero nunca invocado.**
Verificado por grep: solo aparece en su propia definición. La paginación del historial está cableada pero muerta en UI.

**2.3 — `_unwrapSuccess` lanza Exception genérica.**
Línea 124-131: el mensaje viene del backend o se cae al fallback (`'No pudimos cargar tus puntos en este momento.'` o `'No pudimos consultar tu saldo de puntos.'`). El status code se pierde — la UI no puede distinguir 401 (sesión expirada, debería forzar logout) de 500 (error servidor).

**2.4 — Si `decoded` no es `Map<String, dynamic>` retorna `success: false` con `raw: response.body`.**
Si el endpoint devuelve HTML (caso típico cuando WordPress redirige a login), el body completo se incluye en el throw. Riesgo de exponer HTML técnico en SnackBars.

**2.5 — Usa el cliente HTTP por instancia, no estático.**
A diferencia de `HabitoShopApi` y `HabitoBookingApi` (que usan un client estático), `PointsApi` crea uno por instancia. Como `PointsProvider` se crea una sola vez en `main.dart`, esto es OK, pero rompe el patrón.

---

## 3. PointsSummary (modelo)

15 campos. Soporta tanto snake_case como camelCase del backend (defensivo, sugiere contrato inestable).

### Hallazgos

**3.1 — `bookingPointsEnabled` y `orderPointsEnabled` son campos huérfanos.**
Verificado: ningún archivo los consulta. Se parsean (líneas 86-94) y se exponen en la clase, pero ningún consumidor los lee. Se **podría** querer mostrar/ocultar la sección "ganarás X puntos por esta reserva" — esa funcionalidad no existe en UI hoy. Eliminar o usar.

**3.2 — `redeemPointsPerUsd` por defecto = 100.**
Si el backend no envía la tasa, asume 100 puntos = 1 USD. **Crítico**: si la configuración real del plugin es distinta (ej: 50 puntos = 1 USD), el descuento mostrado al usuario no coincide con el que aplicará el servidor. Convendría loguear una alerta o no permitir redención si el rate llega como 0/null.

**3.3 — `redeemMaxPercent` por defecto = 100.**
Permite que el usuario pague el 100% de la reserva con puntos. Si Hábito quiere limitar a 50% (típico en programas de fidelidad), el default es agresivo. Mejor: default conservador (ej. 30%) y solo subir si el plugin lo permite explícitamente.

**3.4 — `formatPoints()` formatea con regex.**
Línea 101-110: convierte 100.00 → "100", 100.50 → "100.5", 100.55 → "100.55". Funciona pero es frágil. `NumberFormat.decimalPattern('es_EC')` daría separadores de miles correctamente (no se usan hoy, pero si el saldo crece a 10,000 puntos se ve "10000" en lugar de "10.000").

---

## 4. PointsProvider

Cache en memoria con TTL de 5 minutos. Dos formas de poblar `_summary`: `updateSession()` (síntesis desde `AuthUser`) y `load()` (fetch al API).

### Hallazgos

**4.1 — ⚠️ Doble fuente de verdad sobre `_summary`.** (CRÍTICO)
El proxy provider en `main.dart:41-46` invoca `updateSession()` cada vez que el `AuthProvider` notifica un cambio. Esto sintetiza un `PointsSummary` desde `AuthUser` y lo guarda en `_summary`, **sobrescribiendo** lo que pudo venir del último `load()` desde el API.

Caso real: el usuario abre la app, `load()` trae summary fresco (ej: balance 87, mycredAvailable=true), `_lastLoadedAt = ahora`. El usuario actualiza su perfil → `auth.refreshProfile()` notifica → `updateSession()` recalcula `_summary` desde `AuthUser`. Si el `AuthUser` actualizado no incluye campos como `mycredAvailable` o `nextGoal`, esos quedan en valores por defecto. La UI muestra el "Saldo actual" del API parcialmente sobreescrito. `_lastLoadedAt` no se borra, así que el siguiente `load()` salta el fetch por TTL.

**Sugerencia:** preservar `_summary` si fue cargado desde API y solo *complementar* con datos de `AuthUser` (balance, label) sin recrear el objeto entero. O resetear `_lastLoadedAt` cuando `updateSession` sintetiza.

**4.2 — `load()` no cancela request en curso si la sesión termina mientras está en vuelo.**
Si el usuario hace logout justo después de pull-to-refresh, el response sigue llegando y actualiza `_summary` aunque ya no haya sesión. Después `updateSession(null, null)` lo limpia, pero hay un blink visible.

**Sugerencia:** check de `_token` después del await: `if (_token != token) return;`.

**4.3 — `load()` no protege contra invocaciones concurrentes.**
Si `points.refresh()` se llama dos veces rápido (pull-to-refresh + reset de pantalla), se hacen 2 fetches. Falta un `Completer` o un guard `if (_isLoading) return;`.

**4.4 — `load()` con `forceRefresh: false` no actualiza UI cuando la caché es válida.**
Línea 88-93: si la caché está fresca y se llama `load()` sin force, retorna sin notificar listeners. Si el provider había estado en estado de error, la pantalla no se actualiza. Mejor: limpiar `_error` antes del `return`.

**4.5 — `_isLoading = true` notifica listeners *antes* de fetch (línea 95-97).**
Esto es correcto pero genera 3 notifyListeners por load (start + finally) en operaciones cortas. Casi inevitable; nada que cambiar.

**4.6 — `updateSession` sin checks defensivos.**
Línea 51-55: cuando cambia `previousUserId != user.id`, limpia history pero deja el `_summary` calculado. Si nunca llega un `load()` después, el summary queda con datos del usuario nuevo pero history del viejo (de hecho lo limpia, ok), pero la lógica es laberíntica. Refactor a `_resetForUser()`.

**4.7 — Hardcoded `bookingPointsEnabled: user.pointsEnabled` y `orderPointsEnabled: user.pointsEnabled`.**
Líneas 76-77: la síntesis desde AuthUser asume que si los puntos están habilitados, también lo están las reglas de earn de bookings y orders. Esto contradice el modelo, donde son flags separadas. Si el plugin tiene `points_enabled = true` pero `booking_points_enabled = false`, la app va a creer que sí. Cuando llegue el load() real corrige.

---

## 5. PointsPage (`points_page.dart`)

Estructura visual:
1. Hero card negro con saldo grande (34 px) y mensaje contextual.
2. Card de métricas: "Total acumulado" + "Meta siguiente" / "Te faltan".
3. Sección "Historial" con cards de movimientos (gain vs loss).
4. Empty states bien definidos para 3 casos: módulo desactivado, error de carga, sin movimientos.

### Hallazgos

**5.1 — La hero card siempre muestra `$balanceText $label` (línea 116).**
Si `moduleEnabled == false`, igual muestra "0 Puntos" en font 34. Visualmente raro: el header dice "Programa de puntos" pero abajo se ve un saldo cero gigante. Mejor: ocultar el balance grande cuando el módulo no está activo y mostrar un CTA explicativo.

**5.2 — `points.error` se muestra verbatim en la hero card.**
Línea 237: `if ((error ?? '').isNotEmpty) return error!;`. Si el backend devuelve "myCred bridge unavailable: timeout connecting to mycred-1234" eso aparece centrado en la hero card en negro/blanco. Sanear.

**5.3 — Sin botón "Cómo gano puntos".**
La pantalla no explica las reglas (1 punto por dólar, bonus por reserva, etc.). El usuario ve el saldo pero no entiende cómo crece. Agregar una sección colapsable o un BottomSheet "¿Cómo funciona?".

**5.4 — Sin CTA "Reservar / Comprar para ganar".**
Después del historial vacío, podría haber dos botones que lleven a la sección de reservas y a productos. Hoy el usuario sale por el back.

**5.5 — Sin paginación visible para el historial.**
Solo se muestran los 20 items que vienen del summary. `historyTotal` se guarda en el provider (línea 28) pero no se usa en UI. Si `historyTotal > 20`, debería haber un botón "Ver más" o infinite scroll. Para esto está justamente `PointsApi.getHistory()` paginado, sin usar.

**5.6 — Filtro por tipo no existe.**
El historial mezcla "ganados", "redimidos" y "neutros". Un chip filter (Todos / Ganados / Redimidos) ayudaría.

**5.7 — Colores hardcoded en `_HistoryCard`.**
Línea 365: `Color(0xFF9C7732)` (gain) y `Color(0xFFA33A3A)` (loss). Deberían venir de `AppColors`.

**5.8 — Tildes faltantes en mensajes.**
- "Aun activamos tus puntos" → "Aún activamos"
- "modulo" → "módulo" (líneas 197, 234)
- "Aún no tienes" usa "Aun" en línea 195
- "Todavia" → "Todavía"
- "apareceran" → "aparecerán"
- "esta configurado" → "está configurado"

Mismo patrón que en `appointment_detail_page.dart`. Conviene una pasada de localización.

**5.9 — `didChangeDependencies` con flag `_didLoad`.**
Lleva el load al primer post-frame. Funciona, pero `initState` con `Future.microtask(...)` sería más estándar en Flutter. La implementación actual no rompe pero sí confunde.

**5.10 — `Consumer2<PointsProvider, AuthProvider>` cubre toda la lista.**
Cualquier cambio en cualquiera de los dos providers reconstruye la pantalla entera, incluido el ListView. Para un historial de 50+ items con `_HistoryCard` cada uno, puede notarse jank al hacer pull-to-refresh.

---

## 6. Integración con BOOKINGS

`bookings_page.dart` define internamente:
- `_resolvePointsState(auth, [pointsProvider])` — arma `_ResolvedPointsState`
- `_bookingPointsToUse(auth, total, [pp])` — calcula puntos a usar
- `_bookingPointsDiscount(auth, total, [pp])` — convierte a USD
- `_bookingPointsHelperMessage(state, total, points)` — mensajes UX
- `_BookingPointsTile` — UI con switch
- Branch en `_submitBooking`: si `_usePoints`, manda `redeemPoints` y `redeemAmount`

### Hallazgos

**6.1 — Lógica idéntica duplicada en `checkout_page.dart`.**
Mismas funciones, mismos cálculos, casi idéntico código. Mover a `PointsCalculator` (clase) o a métodos del propio `PointsProvider`.

**6.2 — `redeemPoints` y `redeemAmount` se mandan ambos al backend.**
`bookings_page.dart:2042-2043`:
```dart
redeemPoints: redeemPoints,    // ej: 50 puntos
redeemAmount: totalPrice,      // ej: $25 (TOTAL del servicio, no descuento)
```
**Ambiguo**: ¿qué hace el backend con `redeemAmount`? Si es "el monto total que se está pagando con puntos", debería ser `pointsDiscount` (lo equivalente en USD), no `totalPrice`. Si es "el monto total de la operación, para que el plugin valide el cap", el nombre `redeemAmount` confunde.

Sugerencia: clarificar en docs del plugin y, si es lo segundo, renombrar a `operationAmount`.

**6.3 — `pointsProvider.refresh()` después de reservar es `unawaited`.**
Línea 2067: `unawaited(authProvider.refreshProfile()); unawaited(pointsProvider.refresh());`. Si el usuario va a la pantalla de puntos inmediatamente, ve el saldo viejo durante el fetch. Mejor: await para garantizar consistencia, o ESperar un breve `await Future.delayed(500ms)` antes de mostrar el sheet de éxito.

**6.4 — `_bookingPointsToUse` no maneja el caso de `rate <= 0`.**
Línea 863: `final rate = pointsState.rate > 0 ? pointsState.rate : 100.0;`. Asume 100 si el rate viene en cero. Pero si el plugin envía `rate: 0` con `redeemEnabled: true` (configuración inválida), la app calcula descuentos con 100 — el servidor lo rechazará. Deshabilitar la opción si rate ≤ 0.

**6.5 — `pointsState.balance` se compara con `maxPointsByTotal` sin tolerancia.**
Línea 867: `pointsState.balance < maxPointsByTotal ? balance : maxPointsByTotal`. En punto flotante, balance = 50.0000001 vs maxPointsByTotal = 50.0 generaría artefactos. Aceptable porque luego se redondea a 2 decimales (línea 872), pero feo.

**6.6 — El switch de "Usar puntos" no se desactiva al fallar la transacción.**
Si la reserva falla por validación del backend (ej: puntos insuficientes en server-side por un cargo simultáneo), `_usePoints` permanece `true`. El usuario puede reintentar, fallará de nuevo. Mejor: detectar errores tipo "INSUFFICIENT_POINTS" y desactivar el switch + refrescar.

**6.7 — `_bookingPointsHelperMessage` solo cubre 3 ramas felices.**
Si hay error de carga del provider, la helper message muestra el caso "balance 0" o "minPoints no alcanzado", pero podría ser solo "no pudimos consultar tu saldo".

---

## 7. Integración con ÓRDENES (checkout)

`checkout_page.dart:416-477` reimplementa la misma lógica:
- `_resolvePointsState(auth, [pp])` — copia exacta
- `_pointsToUse(auth, total, [pp])` — cambia solo `redeemBookingsEnabled` por `redeemProductsEnabled`
- `_pointsDiscount(auth, total, [pp])` — copia exacta

`createOrder` recibe `redeemPoints` (no `redeemAmount` esta vez) y lo serializa como string formateado: `'redeem_points': _formatAmount(redeemPoints)` (`habito_shop_api.dart:647`).

### Hallazgos

**7.1 — ⚠️ Inconsistencia en formato del payload.**
`createBooking` envía `redeem_points` como número (ver `habito_booking_api.dart:442`).
`createOrder` envía `redeem_points` como string formateado (`habito_shop_api.dart:647`).
Si el plugin no es tolerante con tipos, uno de los dos rompe. Estandarizar.

**7.2 — `createOrder` no envía `redeemAmount`** — solo bookings sí.
¿Por qué? Si el plugin necesita el monto original para validar el cap, debería recibirlo en ambos. Si no lo necesita, ¿por qué bookings sí lo manda? Coherencia.

**7.3 — `_pointsToUse` para productos depende de `redeemProductsEnabled` (línea 451), correcto.**
Buena separación de feature flags entre bookings y orders.

**7.4 — Mismo problema 6.6 en checkout.**
El switch "Usar puntos" no se desactiva si el server rechaza por puntos insuficientes.

**7.5 — Refrescar puntos después de crear orden.**
Línea 836: `unawaited(pointsProvider.refresh());`. Mismo problema de race que en bookings.

---

## 8. Sin protección contra doble-gasto

**Escenario crítico**: el usuario tiene 100 puntos.
1. Abre BookingsPage, marca "usar puntos" → app calcula descuento de 50 puntos.
2. Sin confirmar, abre CartPage → CheckoutPage en otra navegación.
3. Marca "usar puntos" → app calcula descuento de 100 puntos (basado en el mismo balance local 100).
4. Confirma orden → server descuenta 100 puntos.
5. Vuelve a la reserva → confirma → server intenta descontar 50 puntos.
6. Server rechaza por saldo insuficiente. UI muestra error genérico "No se pudo crear la reserva".

Para evitarlo:
- Decremento optimista del saldo local al iniciar `_submitBooking` o `_submit`.
- Bloqueo del switch en otras pantallas mientras hay una operación en vuelo.
- Idealmente: lock server-side con idempotency key + confirmación final.

---

## 9. Mapping de flags

Sintetizando todas las flags relacionadas:

| Flag | Significado | Default si falta |
|---|---|---|
| `enabled` | Programa activo en general | `false` |
| `mycred_available` | Plugin myCRED accesible en server | `false` |
| `redeem_enabled` | Permitir redenciones (cualquier tipo) | `false` |
| `redeem_products_enabled` | Permitir redenciones en órdenes | `false` |
| `redeem_bookings_enabled` | Permitir redenciones en reservas | `false` |
| `redeem_points_per_usd` | Tasa de conversión | `100` |
| `redeem_min_points` | Mínimo redimible | `1` |
| `redeem_max_percent` | % máximo del total redimible | `100` |
| `booking_points_enabled` | Ganar puntos por reserva | `false` (NUNCA SE USA) |
| `order_points_enabled` | Ganar puntos por orden | `false` (NUNCA SE USA) |

---

## Top 10 acciones priorizadas

| # | Acción | Severidad |
|---|--------|-----------|
| 1 | Decremento optimista del saldo + bloqueo de "usar puntos" mientras hay operación en vuelo (anti doble-gasto) | **Crítico** |
| 2 | Estandarizar `redeem_points` (número vs string) entre `createBooking` y `createOrder` | **Crítico** |
| 3 | Clarificar el contrato de `redeemAmount` en bookings y eliminarlo o documentarlo en backend | Alto |
| 4 | Extraer la lógica duplicada (`_resolvePointsState`, `_pointsToUse`, `_pointsDiscount`) a `PointsCalculator` o a métodos del provider | Alto |
| 5 | `updateSession()` no debe sobrescribir un `_summary` cargado por API; complementar en lugar de reemplazar | Alto |
| 6 | Conectar `getHistory()` paginado a la `PointsPage` con infinite scroll o "Ver más" | Alto |
| 7 | Sanear `points.error` antes de pintarlo en la hero card (no exponer mensajes técnicos) | Medio |
| 8 | Cambiar `redeem_max_percent` default a un valor conservador (30-50%) en lugar de 100% | Medio |
| 9 | Eliminar (o usar) `bookingPointsEnabled` y `orderPointsEnabled` que están huérfanos | Medio |
| 10 | Sección "Cómo funciona" + CTA "Reservar para ganar puntos" en empty states de PointsPage | Medio |

---

## Lo que está bien

- Arquitectura limpia, separación API / Provider / Models / Page.
- Caché con TTL razonable (5 min) que evita llamadas excesivas.
- Empty states diferenciados (módulo deshabilitado / error / sin movimientos).
- Pull-to-refresh consistente.
- `formatPoints` redondea bien y oculta decimales triviales.
- Soporte de multi-key snake_case + camelCase del backend (defensivo).
- Síntesis de summary desde `AuthUser` permite mostrar saldo aún sin haber hecho fetch (tras login se ve inmediato).
- Helper messages contextuales en `_bookingPointsHelperMessage` (3 ramas distintas según balance, mínimo, total).
- Modelo `PointsHistoryEntry` sencillo y suficiente.
- `RefreshIndicator` con color de marca.
- Refresh de puntos después de cada operación de redención (aunque sea unawaited).
- Reset de history cuando cambia el `userId`.
- Distinción visual clara entre ganancia (icon stars + dorado) y consumo (icon sync + rojo) en el historial.
