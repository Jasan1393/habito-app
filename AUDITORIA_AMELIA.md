---
name: Auditoría integración con Amelia
description: Análisis de las 5 integraciones (barberos, locaciones, servicios, horarios, citas) entre la app Hábito y la API custom Habito ↔ Amelia
fecha: 2026-05-03
endpoints: habitobarberia.com/wp-json/habito/v1/*
---

# Auditoría — Integración con Amelia

La app no habla directamente con la API REST de Amelia. Conversa con un *plugin custom de WordPress* expuesto en el namespace `habito/v1`, que actúa como wrapper sobre Amelia + lógica de negocio (puntos, métodos de pago, etc.). Toda la integración pasa por una sola clase: `HabitoBookingApi` (`lib/features/shop/data/services/habito_booking_api.dart`).

**Base URL** (configurable vía `--dart-define`):
`https://habitobarberia.com/wp-json/habito/v1`

**Hallazgo transversal: código muerto.**
Existen dos arquitecturas paralelas para reservas:
1. `HabitoBookingApi` — la que efectivamente se usa.
2. `BookingService` + `BookingModel` + `CreateBookingRequest` + `RescheduleBookingRequest` (`lib/features/bookings/data/booking_service.dart`) — apunta a endpoints `/reservas/crear`, `/reservas/cancelar`, `/reservas/reagendar`, `/reservas/mis-citas`. **No se invoca desde ninguna parte de la app.** Es el residuo de un diseño anterior.
Además `AppointmentData` (`lib/features/bookings/data/appointment_data.dart`) mantiene una lista en memoria con CRUD local, pero el flujo real lee siempre de `getMyBookings()`. Verificar si todavía se referencia o también es residuo.
**Sugerencia:** eliminar los 3 archivos para evitar confusión y reducir superficie de mantenimiento.

---

## 1. Recuperar Barberos — `getEmployees()`

**Endpoint:** `GET /employees-enriched`
**Headers:** `Accept: application/json`
**Timeout:** 20 s · **Retries:** 3 · **Delay:** 450 ms lineal
**Caché:** memoria + disco (`booking_cache/catalog.json`), TTL fresh 10 min, TTL stale 7 días.

### Flujo
1. `_ensureLoaded()` carga la caché de disco si existe.
2. Si `forceRefresh=false` y la caché es fresca → devuelve memoria directamente.
3. Si la caché está expirada pero usable (<7 días) → devuelve memoria y lanza `_refreshEmployeesInBackground()` con guarda contra requests duplicados.
4. Si no hay caché → fetch + persistencia en disco.

### Consumido en
- `bookings_page.dart:265, 341` — flujo de reserva.
- `team_habito_page.dart:118, 128` — pantalla "Team Hábito".
- `team_habito_home_section.dart:85, 95` — sección del Home.

### Hallazgos

**A. Inconsistencia de retries entre endpoints del mismo catálogo.**
Servicios y locaciones usan `attempts: 2`; barberos usa `attempts: 3`. No hay justificación visible en código. Estandarizar a 2 ó 3.

**B. `forceRefresh: cachedEmployees.isNotEmpty`** en `team_habito_page.dart:128-129` y `team_habito_home_section.dart:95`. Esto invierte la lógica intuitiva: si HAY caché, fuerza refresh; si no, espera el fetch normal. Funciona en la práctica pero es contraintuitivo y triplica fetches en pantallas con caché caliente.

**C. Sin reintento si el background refresh falla.**
`_refreshEmployeesInBackground()` traga el error con `.catchError((_) {})` (línea 1379-1387). El usuario sigue viendo datos potencialmente obsoletos sin saberlo.

**D. Mapeo defensivo redundante.**
`team_habito_page.dart:177-178` lee `firstName ?? first_name`. El backend siempre responde una de las dos formas — verificar y eliminar el fallback.

---

## 2. Recuperar Locaciones — `getLocations()`

**Endpoint:** `GET /locations`
**Headers:** `Accept: application/json`
**Timeout:** 20 s · **Retries:** 2 · **Delay:** 450 ms lineal
**Caché:** misma estructura compartida (`catalog.json`).

### Consumido en
- `bookings_page.dart:266, 351` — selector de sucursal.
- `locations_page.dart:73, 84` — pantalla "Locaciones".
- `cart_page.dart:_loadPickupLocations()` — almacenes para retiro (auditoría previa marcó el doble fetch).

### Hallazgos

**E. Doble fetch garantizado en `LocationsPage._loadLocations()` (línea 60-101).**
Si no es `forceRefresh`, primero pide `getCachedLocations()`, lo aplica, y dispara *inmediatamente* `_loadLocations(forceRefresh: true)` con `unawaited`. Cada apertura de la pantalla = 2 requests, aún con caché fresca.

**F. Coordenadas mezcladas con descripción.**
`locations_page.dart:121-131`: las coordenadas pueden venir en `latitude/longitude` (Amelia) o extraerse del campo `description` mediante regex. Esta lógica indica que el plugin no está normalizando bien lo que entrega Amelia. **Sugerencia:** mover la extracción de coordenadas al backend y eliminar `LocationLauncherService.extractCoordinatesFromText()` del cliente.

**G. `_cacheKnownCoordinates()` y `_resolveCoordinatesFromMapLinks()`** (líneas 115-116) son `unawaited` y persisten en otra caché (`location_coordinate_cache_service.dart`). Tres fuentes de coordenadas por sucursal genera complejidad innecesaria.

---

## 3. Recuperar Servicios — `getServices()`

**Endpoint:** `GET /services-lite`
**Headers:** `Accept: application/json`
**Timeout:** 20 s · **Retries:** 2 · **Delay:** 450 ms lineal
**Caché:** compartida (`catalog.json`).

### Particularidad
`getServices()` valida adicionalmente con `_servicesHaveImages()` que la caché no esté "vacía de imágenes". Si las imágenes faltan considera la caché incompleta y refetchea.

### Consumido en
- `bookings_page.dart:264, 331` — selector de servicio.
- `shop_page.dart:55` — sección "Servicios" del Home del shop.
- `services_archive_page.dart:37` — listado completo.

### Hallazgos

**H. `extractServiceImageUrl()` recorre ~32 candidatos por llamada** (líneas 129-183). Se invoca *por cada servicio en cada frame* en `shop_page.dart:118` y `services_archive_page.dart:64`. Sin memoización. Para una lista de 12 servicios esto multiplica miles de comparaciones por scroll. Memoizar el resultado dentro del propio mapa del servicio (`service['_resolvedImage']`).

**I. `clearCache()` global desde el shop.**
`shop_page.dart:53` y `services_archive_page.dart:34` invocan `HabitoBookingApi.clearCache()` en pull-to-refresh. Esto invalida también la caché de barberos y sucursales que usa el flujo de reservas. Reemplazar por una invalidación granular: `clearServicesCache()` solamente.

**J. `_servicesHaveImages` es un fail-safe contra una respuesta empobrecida del backend.**
Indica que el endpoint a veces devuelve servicios sin imágenes (¿caché del plugin?). Si el problema es del plugin, conviene resolverlo allá; si no, documentar por qué este chequeo existe.

**K. Persistencia en disco está bien diseñada** pero `_persistCache()` se ejecuta *después* del `await` del setter de memoria. Si dos llamadas concurrentes llegan al `await _persistCache()` casi simultáneamente, la última gana. Para los 3 catálogos esto es de bajo impacto pero introducen race conditions silenciosas.

---

## 4. Recuperar Horarios — `getAvailability()`

**Endpoint:** `GET /availability?service_id=…&employee_id=…&location_id=…&persons=…&start_datetime=…&end_datetime=…&extras=…&_ts=…`
**Headers:** `Accept`, `Cache-Control: no-cache`, `Pragma: no-cache`
**Timeout:** 20 s · **Retries:** 3 · **Delay:** 650 ms lineal
**Caché:** **ninguna**. Cada cambio de fecha/empleado/servicio dispara un request fresco.

### Flujo
`bookings_page.dart:_loadAvailabilityIfPossible()` (línea 1158-1293):
1. Valida que haya servicio + empleado + sucursal + fecha.
2. Calcula `slotStepMinutes` según duración del servicio (mínimo 5).
3. Genera `startDateTime`/`endDateTime` para el día completo.
4. Llama a `getAvailability` con extras.
5. Aplica filtros: `_extractMinimumBookingCutoff`, `_filterSlotsByMinimumNotice`, `_filterSlotsForDisplay`.
6. Usa `_availabilityRequestId` (contador monótono) para descartar respuestas obsoletas si el usuario cambió de selección.

### Hallazgos

**L. Doble protección contra caché HTTP innecesaria.**
Se envían `Cache-Control: no-cache` + `Pragma: no-cache` *y* el query param `_ts=DateTime.now().millisecondsSinceEpoch`. El cache buster ya garantiza unicidad de URL — los headers son redundantes y rompen cualquier CDN intermedio.

**M. Sin caché del lado del cliente.**
Los slots de disponibilidad cambian con frecuencia, pero cuando el usuario navega Día N → Día N+1 → Día N, la app vuelve a pedir Día N. Caché en memoria por (service, employee, location, date) con TTL de 30-60 s reduciría 60-80% de los requests del flujo de reserva.

**N. `extras` se envía como JSON-string dentro del query param.**
Línea 343-359: `queryParameters['extras'] = jsonEncode(...)`. Funciona pero (1) puede romper límites de URL en algunos servers, (2) los logs del servidor van a guardar la URL con todo el payload visible, (3) algunos proxies normalizan querystrings y rompen el JSON. Para query con extras debería ser `POST /availability` o cada extra como params repetidos.

**O. Excelente protección contra respuestas obsoletas.**
`_availabilityRequestId` (línea 1175, 1192, 1204, 1239, 1270, 1278) es la solución correcta y está bien implementada. Mantener.

**P. Mensaje de aviso poco claro.**
Línea 1261: `'Para este servicio, los horarios deben reservarse con al menos ${noticeLabel ?? 'tiempo de anticipacion'}.'` — typo en "anticipacion" (sin tilde) y el fallback es vago. Falta tilde también en otros mensajes (`'Si, cancelar'` en `appointment_detail_page.dart:446`).

**Q. Slot step heurístico hardcoded.**
`_preferredSlotStepMinutes(requestedDurationSeconds) ?? 5` — la cadencia mínima de 5 minutos puede no coincidir con el `Time slot length` configurado en Amelia. Si Amelia está en 15 min y la app pide 5, vamos a generar slots inválidos que se intentarán reservar y fallarán.

**R. `slotStepMinutes` no se envía al backend.**
El backend probablemente respeta su propia configuración de Amelia, pero el cliente está usando un valor distinto para *renderizar*. Inconsistencia silenciosa.

---

## 5. Generar Citas — `createBooking()`

**Endpoint:** `POST /bookings`
**Headers:** `Content-Type: application/json`, `Accept`, `Authorization: Bearer {token}` (opcional para invitados)
**Timeout:** 20 s · **Retries:** **0**
**Body:** ver líneas 431-456 — incluye `service_id`, `provider_id`, `location_id`, `booking_start`, `persons`, `duration`, `country_phone_iso`, `locale`, `notify_participants`, `extras`, `redeem_points`, `redeem_amount`, bloque `payment_method`, `customer_id`, `amelia_customer_id`, `custom_fields`.

### Flujo
`bookings_page.dart:_submitBooking()` (línea 1950-2109):
1. Valida método de pago habilitado y que soporte "manual order".
2. Si `_usePoints`, refresca puntos primero.
3. Compone el `customer` payload con datos fiscales (cédula/RUC, ciudad, dirección, etc.).
4. Llama a `createBooking()`.
5. Extrae `appointment_id` o `bookingId` para mostrar el sheet de éxito.
6. Si redimió puntos, refresca perfil y saldo.

### Hallazgos

**S. CERO retries en `createBooking`.**
Es la única operación crítica de toda la integración con Amelia y es la que **menos** tolera fallos. `http.post(...).timeout(_timeout)` (línea 542-548). Una intermitencia de red descarta toda la reserva. Implementar retry idempotente con detección de duplicados (basada en un `idempotency_key` enviado al backend, idealmente generado en cliente para no crear citas duplicadas si el primer POST sí llegó pero el ACK se perdió).

**T. Sin `idempotency_key`.**
Si el cliente no recibe respuesta y reintenta manualmente, puede generar dos citas. Crítico para una operación con dinero (puntos redimidos, intent de pago).

**U. `notify_participants: 1` hardcoded** (línea 440). Amelia siempre va a mandar email + SMS. Si en algún momento se quiere ofrecer "no avisar a mi correo aún" no hay control desde el cliente.

**V. `country_phone_iso: 'ec'` y `locale: 'es_EC'` hardcoded.**
Bien para Ecuador, pero no extensible. Mover a `AppConfig`.

**W. `duration: totalDuration > 0 ? totalDuration : 3600` con fallback de 1 hora** (línea 2038). Si el servicio no devolvió duración, asumimos 60 min — peligroso para servicios de 30 min (bloqueamos slot de más) o 90 min (sub-reserva). Mejor: rechazar y mostrar "no pudimos determinar la duración del servicio" antes de enviar.

**X. Errores genéricos.**
Si `data['success'] != true`, se lanza `Exception(_extractErrorMessage(data))`. Si falla por stock/horario tomado, el usuario ve el mensaje técnico del backend. `_friendlyBookingError(e)` (línea 2101) ayuda, pero no he visto su implementación — verificar que mapee los errores comunes ("BOOKING_SLOT_TAKEN", "CUSTOMER_LIMIT", etc.) a mensajes amables.

**Y. `_decodeResponse` filtra el body en errores 500** (línea 1543): `'Error 500 del servidor. Respuesta: ${response.body}'`. Esto va a la UI. Puede exponer trazas internas del plugin / WordPress al usuario.

**Z. Persons fijo en 1.**
La UI no expone selección de número de personas (`persons: 1` en línea 401). Si la barbería en algún momento ofrece "viene con un acompañante", no hay flujo.

**AA. `cancelBooking` y `rescheduleAppointment` también sin retries.**
Mismas operaciones críticas, mismo problema.

**BB. `_findFirstMapByKeys` para extraer datos de la respuesta** (línea 1094-1121) es robusto frente a múltiples shapes (`appointment` directo o anidado en `data.appointment`). Sugiere que el plugin no es 100% consistente respondiendo. Consolidar el contrato del backend evitaría toda esta lógica defensiva.

---

## Top 10 acciones priorizadas

| # | Acción | Impacto |
|---|--------|---------|
| 1 | Agregar `idempotency_key` + retry exponential a `createBooking` (1 → 3 intentos con detección de duplicado backend) | **Crítico** — evita pérdida de citas y duplicados |
| 2 | Caché por (service, employee, location, date) en `getAvailability` con TTL 30 s | Alto — reduce 60-80% de requests del flujo |
| 3 | Eliminar `BookingService`, `BookingModel`, `CreateBookingRequest`, `RescheduleBookingRequest` (código muerto) | Alto — claridad |
| 4 | Reemplazar `clearCache()` global por `clearServicesCache()` granular | Alto — evita que el shop invalide la caché de bookings |
| 5 | Memoizar `extractServiceImageUrl` (almacenar resultado en `service['_resolvedImage']`) | Medio — perf en shop |
| 6 | Quitar el doble fetch de `LocationsPage._loadLocations` y `CartPage._loadPickupLocations` | Medio — ancho de banda |
| 7 | Mover `extras` de `getAvailability` de querystring a body (POST) | Medio — robustez |
| 8 | Sanear `_decodeResponse`: nunca devolver `response.body` raw al usuario | Medio — seguridad |
| 9 | Estandarizar `attempts` y delays entre catálogos (services/employees/locations) | Bajo — consistencia |
| 10 | Mover `country_phone_iso`, `locale`, `notify_participants` a `AppConfig` | Bajo — i18n futura |

---

## Diagrama de dependencias

```
UI (BookingsPage / TeamPage / LocationsPage / ShopPage)
  │
  ├── HabitoBookingApi (única clase activa)
  │     ├── /services-lite        ← getServices()
  │     ├── /employees-enriched   ← getEmployees()
  │     ├── /locations            ← getLocations()
  │     ├── /availability         ← getAvailability()
  │     ├── /bookings             ← createBooking()
  │     ├── /bookings/:id/cancel  ← cancelBooking()
  │     ├── /appointments/:id/reschedule ← rescheduleAppointment()
  │     ├── /my-bookings          ← getMyBookings()
  │     ├── /my-booking           ← getMyBooking()
  │     └── /fcm-token            ← saveFcmToken()
  │
  ├── BookingService (DEAD CODE)
  │     ├── /reservas/mis-citas
  │     ├── /reservas/crear
  │     ├── /reservas/cancelar
  │     └── /reservas/reagendar
  │
  └── AppointmentData (in-memory, ¿usado?)
```

## Lo que está bien

- Caché en disco persistente del catálogo con TTL fresco + stale.
- `_availabilityRequestId` para descartar respuestas obsoletas.
- Background refresh con guard Future evita requests duplicados.
- `_extractErrorMessage` humaniza campos faltantes en español ("servicio", "barbero", "sucursal").
- Manejo de 401/403/500 centralizado en `_decodeResponse`.
- Normalización de status (approved/pending/canceled/completed/rejected) tolerante a español/inglés.
- Detección de "expired pending" (cita vencida sin confirmar).
- Soporte de extras de servicio bien implementado en availability + booking.
- Token Bearer opcional — permite reservas como invitado.
- Endpoint con timeout en TODAS las llamadas.
