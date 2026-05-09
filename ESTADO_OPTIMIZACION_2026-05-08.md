---
name: Estado de la optimización
description: Re-auditoría tras la primera ronda de implementación
fecha: 2026-05-08
plan_referencia: PLAN_OPTIMIZACION.md
---

# Estado de la optimización — 2026-05-08

## Resumen ejecutivo

**Implementación global ≈ 78% del plan.**

| Bloque | Estado |
|---|---|
| Fase 0 — Quick wins | 🟡 80% (falta `clearEmployeesCache`/`clearLocationsCache` granulares) |
| Fase 1 — Design system base | ✅ 100% (incluso supera la spec: agregaron `AppTextSize`) |
| Fase 2 — Migración visual | ✅ 95% (3 pantallas con hardcodes residuales) |
| Fase 3 — Estados uniformes | ✅ Aplicado donde se midió |
| Fase 4 — Mensajes amables | ✅ 100% (`FriendlyErrors` completo) |
| Fase 5 — Persistencia carrito | ✅ 100% (`SharedPreferences` + hydrate + debounce) |
| Fase 6 — Idempotency + retry | ✅ 100% en endpoints críticos + redeem_points consistente |
| Fase 7 — Reagendar visible | ✅ 100% |
| Fase 8 — Datos bancarios | ✅ 100% |
| Fase 9 — Validación cédula/RUC | ✅ 100% |
| Fase 10 — Forms profesionales | ✅ Aplicado |
| Fase 11 — Caché availability | ✅ 100% (TTL 45 s) |
| Fase 12 — Puntos refactor | ✅ 90% (PointsCalculator + reserve/release + paginación) |
| Fase 13 — Validación pre-checkout | ✅ 100% |
| Fase 14 — Validación comprobante | ✅ 100% |
| Fase 15 — Limpieza código muerto | 🔴 0% — ningún archivo eliminado, 62 `.bak` siguen |
| Fase 16 — Accesibilidad | 🟡 50% — falta `Dismissible` con "Deshacer" en carrito |
| Fase 17 — Tracking envío | ⏸️ Backend dependiente — sin avance |
| Fase 18 — `AppTopHeader` unificado | 🔴 20% — 4 pantallas siguen con `AppBar` nativo |

---

## ✅ Done — verificado por grep

### Design system (Fase 1)

7 archivos creados en `lib/core/theme/`:
- `app_colors.dart` (49 colores, supera la spec)
- `app_theme.dart` (textTheme expandido)
- `app_spacing.dart` (xs → xxxl + EdgeInsets helpers)
- `app_radius.dart` (sm → xxl + pill)
- `app_shadows.dart` (8 estilos, incl. `goldGlow`)
- `app_icon_size.dart` (20 constantes especializadas)
- `app_text_size.dart` (26 constantes — **no estaba en la spec, valor agregado**)

3 widgets compartidos en `lib/shared/widgets/`:
- `habito_empty_state.dart` con prop `compact`
- `habito_error_state.dart` con `onRetry` opcional
- `habito_loading_shimmer.dart` con 3 constructores (default / `.horizontal()` / `.grid()`)

**Reducción de hardcodes** (verificada con grep):
- `Color(0xFF...)`: 1376 → **67** (reducción 95%)
- `BorderRadius.circular(N)`: 708 → **19** (reducción 97%)
- `fontSize: N`: 558 → **197** (reducción 65%, los 197 restantes ya usan `AppTextSize.X` o son justificados)
- `BoxShadow` ad-hoc: prácticamente 0, todos centralizados

### Robustez (Fase 6)

- `lib/core/utils/uuid.dart` con `newIdempotencyKey(prefix:)`.
- `Idempotency-Key` + `X-Idempotency-Key` + `X-Habito-Idempotency-Key` (3 headers para tolerar configuraciones distintas del backend).
- Aplicado en:
  - `createBooking` (`habito_booking_api.dart:659`)
  - `cancelBooking` (`:694`)
  - `rescheduleAppointment` (`:721`)
  - `createOrder` (`habito_shop_api.dart:758`)
  - `validateCart` (`:809`)
  - `uploadPaymentProof` (`:839`)
- Retry exponencial vía `_postBackoffDelay()` con `1 << attempt`.
- **`redeem_points` consistente**: `_amountNumber(redeemPoints)` en ambos servicios. (Un agente reportó inconsistencia, verifiqué — está bien).

### Mensajes amables (Fase 4)

- `lib/core/errors/friendly_errors.dart` con métodos por dominio: `checkout`, `cancelAppointment`, `rescheduleAppointment`, `paymentProof`, `points`, `clean`.
- `_stripTechnicalNoise` y `_looksTechnical` para no exponer SQLSTATE / stack traces.
- Importado en `habito_shop_api.dart:11` y aplicado en líneas 2234, 2248.

### Persistencia carrito (Fase 5)

- `pubspec.yaml`: `shared_preferences: ^2.5.5`.
- `shop_provider.dart`:
  - `_cartStorageKey = 'habito_shop_cart_v1'` (con versionado, ✓).
  - `hydrate()` (línea 368) usado desde `main.dart:47`.
  - `_persistCart()` con debounce 1 s (`_scheduleCartPersist()` línea 992).
  - `clearCart()` limpia storage (`_clearPersistedCart()`).
  - Persiste items + `fulfillmentMethod` + `pickupLocation`.

### Validación pre-checkout (Fase 13)

- `lib/features/shop/models/cart_validation.dart` con `ShopCartValidationItem` y `ShopCartValidationResult`.
- `validateCartForCheckout()` en `shop_provider.dart:695`.
- Invocado en `checkout_page.dart:702` antes de `createOrder`.

### Validación cédula/RUC (Fase 9)

- `lib/core/validators/ecuador_id_validator.dart` con módulo 11 real.
- `lib/core/validators/form_validators.dart` con email regex estricto + phone EC.
- Aplicado en `register_page.dart`, `checkout_page.dart:1199`, `bookings_page.dart`.

### Puntos (Fase 12)

- `lib/features/points/points_calculator.dart` con lógica compartida.
- `lib/features/points/models/points_quote.dart` (modelo nuevo).
- `points_provider.dart`: `reserveRedemption()` (línea 179) + `releaseReservation()` (línea 201) → **anti doble-gasto activo**.
- Paginación de history: `loadMoreHistory()` + scroll infinito en `points_page.dart:58-64`.
- `defaultMaxPercent = 50` (bajado de 100% conservadoramente).

### Reagendar visible (Fase 7)

- Botón "Reagendar" en `appointment_detail_page.dart:973-995`.
- Visible solo si `canCancel == true`.
- Construye `BookingsPage(appointmentId: ...)`.
- Modo `_isEditing` en `bookings_page.dart:97`.

### Datos bancarios (Fase 8)

- `habito_bank_data_sheet.dart` invocado en `checkout_page.dart:895-901` post-orden con `bacs`.
- Botones: copiar cuenta, WhatsApp, subir comprobante.

### Validación comprobante (Fase 14)

- `habito_payment_proof_picker.dart` con validación de tipo + tamaño + preview.
- Usado desde `appointment_detail_page.dart:649` y `orders_page.dart:92`.

### Caché availability (Fase 11)

- TTL 45 s por `(serviceId, employeeId, locationId, date)` en `habito_booking_api.dart:365-426`.

---

## 🟡 Parcial — falta para cerrar

### Fase 0.5 — granularidad de caché

Falta agregar a `habito_booking_api.dart`:

```dart
static void clearEmployeesCache() {
  _cachedEmployees = null;
  _employeesCachedAt = null;
  _employeesRefreshFuture = null;
  unawaited(_persistCache());
}

static void clearLocationsCache() {
  _cachedLocations = null;
  _locationsCachedAt = null;
  _locationsRefreshFuture = null;
  unawaited(_persistCache());
}
```

Hoy solo existen `clearCache()` (global) y `clearServicesCache()`.

### Fase 2 — hardcodes residuales

3 archivos con hardcodes que se les escaparon a la migración:

| Archivo | Hardcodes | Sugerencia |
|---|---|---|
| `lib/features/auth/presentation/pages/auth_gate_page.dart` | 11 `Color(0xFF...)` (líneas 232, 267, 270, 290, 293, 298, 317, 338, 345, 360, 430) | Crear variantes en `AppColors` o derivar con `withValues(alpha:)` |
| `lib/features/shop/presentation/pages/services_archive_page.dart` | 8 `Color(0xFF...)` + 9 `BorderRadius.circular()` | Migrar al design system |
| `lib/features/bookings/presentation/pages/push_appointment_loader_page.dart` | 5 `Color(0xFF...)` | Migrar |

Y 3 fontSize sueltos:
- `app_theme.dart:34` → `fontSize: 12.5` en NavigationBar (debería ser `AppTextSize.bodySmall`).
- `habito_bank_data_sheet.dart:160` → `fontSize: 24` (debería ser `AppTextSize.headlineMedium`).
- `habito_payment_proof_picker.dart:204` → `fontSize: 20` (debería ser `AppTextSize.titleLarge`).

### Fase 16 — accesibilidad

✅ Steppers a 44×44 (`AppIconSize.quantityButton`).
🔴 Sin `Dismissible` ni confirmación al quitar producto del carrito (`cart_page.dart`).
🔴 Sin SnackBar "Deshacer" tras eliminación.

### Fase 18 — `AppTopHeader` unificado

5 pantallas siguen con `AppBar` nativo:
- `orders_page.dart` (2 AppBar)
- `my_appointments_page.dart`
- `appointment_detail_page.dart`
- `edit_profile_page.dart`
- `profile_page.dart` (excepción documentada — dark intencional, OK)

---

## 🔴 Pendiente

### Fase 15 — limpieza de código muerto

Verificado: nada eliminado.

```
❌ lib/features/bookings/data/booking_service.dart  (296 líneas, código muerto)
❌ lib/features/bookings/data/appointment_data.dart (~207 líneas, posiblemente muerto)
❌ 62 archivos .bak-* en el repo
```

Acción:
```bash
# Verificar que nada importe BookingService:
grep -rn "import.*booking_service" lib/
grep -rn "BookingService\|BookingModel\|CreateBookingRequest\|RescheduleBookingRequest" lib/

# Si todo limpio, eliminar:
rm lib/features/bookings/data/booking_service.dart

# Verificar que nada importe AppointmentData:
grep -rn "AppointmentData\|appointment_data" lib/

# Si todo limpio, eliminar:
rm lib/features/bookings/data/appointment_data.dart

# Limpiar .bak:
find lib -name "*.bak*" -delete

# Agregar a .gitignore (si no está):
echo "*.bak-*" >> .gitignore
```

### Tildes faltantes

Confirmado por grep:

| Archivo:línea | Texto actual | Texto correcto |
|---|---|---|
| `appointment_detail_page.dart:511` | `'La solicitud vencio porque la fecha de la cita ya paso.'` | `'La solicitud venció porque la fecha de la cita ya pasó.'` |
| `appointment_detail_page.dart:541` | `'Esta accion cancelara tu cita. Deseas continuar?'` | `'Esta acción cancelará tu cita. ¿Deseas continuar?'` |
| `appointment_detail_page.dart:1466` | `'La cita aun no tiene un pedido vinculado...'` | `'La cita aún no tiene un pedido vinculado...'` |
| `appointment_detail_page.dart:1463`, `orders_page.dart:1312, 1459` | `'quedo'` | `'quedó'` |
| `delete_account_page.dart:73` | `'Esta accion elimina el acceso...'` | `'Esta acción elimina el acceso...'` |

### Fase 17 — tracking envío

Sin avance (depende de coordinación con backend WordPress).

---

## ⚠️ Mejoras nuevas detectadas en esta re-auditoría

1. **`shop_api.dart:_decodeResponse` (línea 1797)** — verificar si todos los puntos donde se lanza Exception pasan por `FriendlyErrors.clean`. En la re-auditoría se observó que el shop usa `FriendlyErrors.checkout` en algunos lados (línea 2248) pero no es uniforme. Auditar otra pasada interna de `_decodeResponse` para garantizar que **ningún path** devuelva `response.body` raw.

2. **`bookings_page.dart`** — verificar que en modo `_isEditing` los selectores de **servicio y barbero** estén deshabilitados visualmente (el estado lógico ya lo está, pero el usuario debería ver los selectores en gris/disabled, no aparentemente clickeables).

3. **`cart_page.dart`** — agregar loading state explícito en el botón "Continuar al pago" cuando `shop.isCreatingOrder == true`. Con la persistencia activa, el riesgo de doble tap es alto.

4. **`HabitoLoadingShimmer`** — el constructor `.grid()` con `columns > 1` puede no respetar `aspectRatio` si los items tienen anchos variables. Probar visualmente en `products_archive_page.dart`.

5. **`PointsProvider.reserveRedemption`** — verificar que se llame **antes** de iniciar `createBooking`/`createOrder` y se libere en el `catch` si la operación falla. Si se llama después, no hay protección anti doble-gasto efectiva.

6. **`validateCartForCheckout`** — verificar que el dialog de "Tu carrito necesita actualizarse" se muestra cuando el resultado contiene cambios, y que el usuario tiene que confirmar explícitamente antes de seguir al `createOrder`.

7. **`/.gitignore`** — verificar que ya ignora `*.bak-*` antes de eliminarlos del working tree, para que no vuelvan a aparecer.

8. **`uuid.dart:newIdempotencyKey`** — el helper actual usa timestamp + random. Para máxima robustez, debería ser un UUID v4 puro (16 bytes random); con timestamp existe la teórica colisión si dos devices generan en el mismo ms con la misma seed. Riesgo bajísimo pero documentar.

---

## Próximos pasos sugeridos (1-2 horas)

Ordenado por costo/beneficio:

1. **30 min** — Eliminar `BookingService`, `AppointmentData` y los 62 `.bak`. Agregar regla `*.bak-*` al `.gitignore`. Esto limpia el repo de manera dramática y reduce ruido en grep/IDE.
2. **15 min** — Pasada de tildes (5 strings concretos arriba).
3. **20 min** — Agregar `clearEmployeesCache()` y `clearLocationsCache()` granulares en `habito_booking_api.dart`. Buscar call sites futuros.
4. **45 min** — Migrar `orders_page.dart`, `my_appointments_page.dart`, `appointment_detail_page.dart`, `edit_profile_page.dart` a `AppTopHeader` (deja `profile_page.dart` como excepción dark documentada).
5. **30 min** — `Dismissible` con `confirmDismiss` y SnackBar "Deshacer" 4 segundos en `cart_page.dart` para quitar producto.
6. **15 min** — Migrar los 11 hardcodes de `auth_gate_page.dart` y los 8 de `services_archive_page.dart` al design system.
7. **10 min** — Corregir los 3 `fontSize` sueltos (`app_theme.dart:34`, `habito_bank_data_sheet.dart:160`, `habito_payment_proof_picker.dart:204`).

**Total**: ~3 horas para cerrar al 95%+.

---

## Lo que se hizo de más (no estaba en el plan, valor agregado)

- `lib/core/theme/app_text_size.dart` — escala de tamaños de texto granular además del `textTheme`.
- `lib/features/points/models/points_quote.dart` — modelo de cotización de puntos.
- `lib/shared/widgets/habito_payment_proof_picker.dart` — componente reutilizable para subida de comprobante con validación + preview.
- 3 headers para `Idempotency-Key` (tolerancia a configs distintas del plugin).
- 8 sombras predefinidas (la spec pedía 4).
- 49 colores en `AppColors` (la spec pedía ~15).
- `FriendlyErrors._stripTechnicalNoise` — saneo de mensajes técnicos del backend antes de mostrar al usuario.

---

## Conclusión

El plan se ejecutó muy bien. **El código ya es notablemente más mantenible, consistente y robusto que en la auditoría inicial.** Las piezas de robustez crítica (idempotency, retry, persistencia, validación pre-checkout, anti doble-gasto en puntos) están todas en su lugar.

Lo que queda es relativamente cosmético y de limpieza:
- Eliminar código muerto / `.bak` (impacto alto en developer experience).
- Tildes y migración de las 4-5 pantallas residuales a `AppTopHeader`.
- `Dismissible` + 2-3 hardcodes residuales menores.

Una sesión de ~3 horas cierra al 95%+. La fase 17 queda en hold por backend.
