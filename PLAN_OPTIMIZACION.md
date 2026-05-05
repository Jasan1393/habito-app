---
name: Plan de optimización Hábito
description: Roadmap ejecutable de mejoras en Rendimiento, Visual y UX, organizado en fases con dependencias claras
fecha_inicio: 2026-05-03
estado: pendiente de ejecución
skill_asociada: skills/habito-flutter-optimizer/SKILL.md
auditorias_base:
  - AUDITORIA_HABITO.md
  - AUDITORIA_AMELIA.md
  - AUDITORIA_CANCEL_REAGENDAR.md
  - AUDITORIA_PRODUCTOS_CARRITO_PAGO.md
  - AUDITORIA_PUNTOS.md
---

# Plan de optimización — App Hábito

Este plan toma todos los hallazgos de las 5 auditorías previas y los convierte en fases ejecutables. Cada tarea apunta al archivo afectado y al patrón de la skill que la guía.

## Cómo usar este plan

1. **Antes de empezar una sesión**, abre `skills/habito-flutter-optimizer/SKILL.md` y dile al modelo "ejecuta la fase X del plan de optimización" (o tareas específicas).
2. Las fases están ordenadas por **dependencia técnica** (no por urgencia de negocio): cada una desbloquea las siguientes. No saltar fases.
3. Dentro de una fase, las tareas se pueden ejecutar **en paralelo** salvo donde se indique dependencia.
4. **Marcar progreso aquí mismo** con `[x]` al terminar cada tarea, y agregar la fecha entre paréntesis.
5. Si una tarea revela trabajo extra no contemplado, agregarla a la fase correspondiente con la nota "(emergente, descubierta el YYYY-MM-DD)".

---

## Fase 0 — Quick wins (1 día, 0 dependencias)

Cosas que se pueden hacer hoy sin tocar arquitectura. Ganancia visible inmediata.

- [ ] **0.1** Comprimir `assets/images/services/Corte de Cabello.png` (1.9 MB → ~250 KB WebP). Hacerlo fuera de Flutter con un editor o herramienta CLI; reemplazar el archivo. Verificar que la pantalla `shop_page.dart` siga renderizando ok.
- [ ] **0.2** En `cart_page.dart:41-78`, eliminar el doble fetch de almacenes. Confirmar que la caché fresca evita el `forceRefresh`. Patrón: `references/performance.md` §3.
- [ ] **0.3** En `locations_page.dart:60-101`, eliminar el doble fetch idéntico.
- [ ] **0.4** En `home_page.dart:32` y `points_page.dart:38`, reemplazar `context.watch<ShopProvider>()` por `context.select<ShopProvider, int>((s) => s.cartCount)`. Patrón: `references/performance.md` §7.
- [ ] **0.5** En `shop_page.dart:53` y `services_archive_page.dart:34`, reemplazar `HabitoBookingApi.clearCache()` por `clearServicesCache()` (granular). Requiere agregar el método `clearServicesCache` (y `clearEmployeesCache`, `clearLocationsCache`) en `habito_booking_api.dart`. Patrón: `references/performance.md` §1.
- [ ] **0.6** Memoizar `extractServiceImageUrl` con `service['_resolvedImage'] ??= ...`. Patrón: `references/performance.md` §6.
- [ ] **0.7** Pasada de tildes en strings de UI más visibles: `appointment_detail_page.dart`, `points_page.dart`, `bookings_page.dart` (mensajes de aviso). Lista en `references/ux.md` §9.

**Salida esperada**: scroll y cold-start notablemente más rápidos en shop y carrito; ortografía corregida.

---

## Fase 1 — Design system base (3 días, depende de Fase 0)

Construir las constantes que toda la app va a consumir. Hacer esto antes de la migración visual evita drift.

- [ ] **1.1** Expandir `lib/core/theme/app_colors.dart` con las variantes de oro, superficies oscuras, y `dangerDeep` documentadas en `references/design_system.md`.
- [ ] **1.2** Expandir el `textTheme` de `app_theme.dart` con `headlineLarge`, `titleMedium`, `titleSmall`, `bodySmall`, `labelLarge/Medium/Small`.
- [ ] **1.3** Crear `lib/core/theme/app_spacing.dart`.
- [ ] **1.4** Crear `lib/core/theme/app_radius.dart`.
- [ ] **1.5** Crear `lib/core/theme/app_shadows.dart`.
- [ ] **1.6** Crear `lib/core/theme/app_icon_size.dart` (opcional pero recomendado).
- [ ] **1.7** Crear `lib/shared/widgets/habito_loading_shimmer.dart`.
- [ ] **1.8** Crear `lib/shared/widgets/habito_empty_state.dart`.
- [ ] **1.9** Crear `lib/shared/widgets/habito_error_state.dart`.

**Salida esperada**: `lib/core/theme/` con 5-6 archivos. `lib/shared/widgets/` con 3 widgets nuevos. Cero cambios visibles en la app aún (es solo infraestructura).

---

## Fase 2 — Migración visual (5 días, depende de Fase 1)

Migrar pantalla por pantalla a usar el design system. Una pantalla por commit, fácil de revisar.

Orden sugerido (de mayor impacto visible a menor):

- [ ] **2.1** `home_page.dart` (es la primera impresión).
- [ ] **2.2** `shop_page.dart` + `products_archive_page.dart` + `product_detail_page.dart`.
- [ ] **2.3** `cart_page.dart` + `checkout_page.dart`.
- [ ] **2.4** `bookings_page.dart` (es enorme; planificar 1 día solo para esta).
- [ ] **2.5** `my_appointments_page.dart` + `appointment_detail_page.dart`.
- [ ] **2.6** `orders_page.dart`.
- [ ] **2.7** `points_page.dart`.
- [ ] **2.8** `notifications_page.dart`.
- [ ] **2.9** `locations_page.dart`.
- [ ] **2.10** `team_habito_page.dart` + `team_habito_home_section.dart`.
- [ ] **2.11** `profile_page.dart` + `edit_profile_page.dart`.
- [ ] **2.12** `login_page.dart` + `register_page.dart` + `forgot_password_page.dart` + `delete_account_page.dart`.
- [ ] **2.13** `app_top_header.dart`, `habito_bottom_navigation_bar.dart`, `unread_notifications_button.dart`.

Para cada pantalla, seguir el patrón "Cómo migrar una pantalla al design system" en `references/visual.md`.

**Salida esperada**: cero `Color(0xFF...)`, `fontSize: N`, `BorderRadius.circular(N)` arbitrarios, `BoxShadow` ad-hoc o `SizedBox(width/height: N)` con valores mágicos en archivos de `lib/`. Verificar con `Grep` al final.

---

## Fase 3 — Estados de UI uniformes (2 días, depende de Fase 1)

Unificar loading / empty / error en todas las pantallas que cargan datos del backend.

- [ ] **3.1** `shop_page.dart` — reemplazar skeletons custom por `HabitoLoadingShimmer`.
- [ ] **3.2** `products_archive_page.dart` — empty + error con widgets nuevos.
- [ ] **3.3** `cart_page.dart` — `_EmptyCartView` → `HabitoEmptyState` con CTA "Ir a la tienda".
- [ ] **3.4** `my_appointments_page.dart` — empty por tab + error.
- [ ] **3.5** `orders_page.dart` — empty por filtro + error con retry.
- [ ] **3.6** `bookings_page.dart` — loading entre pasos del wizard + empty de slots.
- [ ] **3.7** `points_page.dart` — los 3 estados existentes a `HabitoEmptyState/HabitoErrorState`.
- [ ] **3.8** `notifications_page.dart` — empty + error.
- [ ] **3.9** `locations_page.dart` — empty + error.
- [ ] **3.10** Agregar `RefreshIndicator` donde falte (órdenes ya tiene; verificar todas).

---

## Fase 4 — Mensajes amables (1 día, depende de Fase 1)

Crear los mappers de errores y aplicarlos.

- [ ] **4.1** Crear `lib/core/errors/friendly_errors.dart` con un helper genérico y mappers por dominio.
- [ ] **4.2** `_friendlyCancelError` aplicado en `appointment_detail_page.dart:471`.
- [ ] **4.3** `_friendlyRescheduleError` aplicado en `bookings_page.dart:2159` (separar del `_friendlyBookingError`).
- [ ] **4.4** `_friendlyCheckoutError` aplicado en `checkout_page.dart` y `shop_provider.dart:639`.
- [ ] **4.5** `_friendlyPaymentProofError` aplicado en `orders_page.dart`.
- [ ] **4.6** `_friendlyPointsError` aplicado en `points_page.dart` (reemplazar el `error!` directo en hero card).
- [ ] **4.7** Sanear `_decodeResponse` en los 3 servicios para que **nunca** devuelva `response.body` raw al lanzar.

---

## Fase 5 — Persistencia del carrito (1 día, depende de Fase 0)

- [ ] **5.1** Pedir permiso al usuario para agregar `shared_preferences` al `pubspec.yaml`. Ejecutar `flutter pub get`.
- [ ] **5.2** Implementar `ShopProvider.hydrate()` y `_persist()` con debounce de 1s. Patrón: `references/ux.md` §6.
- [ ] **5.3** Llamar `shop.hydrate()` en `main.dart` después del `Firebase.initializeApp()`.
- [ ] **5.4** Persistir también `_fulfillmentMethod` y `_pickupLocation`.
- [ ] **5.5** Limpiar storage al hacer `clearCart()` y al logout.
- [ ] **5.6** Test manual: agregar items, cerrar la app, abrir, verificar que están.

---

## Fase 6 — Robustez de operaciones críticas (3 días, depende de Fase 0)

Agregar `idempotency_key` + retry exponencial a las operaciones que tocan dinero o citas.

- [ ] **6.1** Implementar el helper `_newIdempotencyKey()` en `lib/core/utils/uuid.dart` (sin agregar `uuid` package). Patrón: `references/performance.md` §8.
- [ ] **6.2** Implementar el helper `_retryingPost(...)` con backoff exponencial.
- [ ] **6.3** Aplicar a `HabitoBookingApi.createBooking` (header `Idempotency-Key`).
- [ ] **6.4** Aplicar a `HabitoBookingApi.cancelBooking`.
- [ ] **6.5** Aplicar a `HabitoBookingApi.rescheduleAppointment`.
- [ ] **6.6** Aplicar a `HabitoShopApi.createOrder`.
- [ ] **6.7** Aplicar a `HabitoShopApi.uploadPaymentProof` (si aplica retry).
- [ ] **6.8** Estandarizar el formato de `redeem_points` entre `createBooking` (número) y `createOrder` (string formateado) — usar número en ambos.
- [ ] **6.9** Coordinar con backend: el plugin debe deduplicar por `Idempotency-Key`. Sin esto, los retries pueden duplicar órdenes.
- [ ] **6.10** Aclarar el contrato de `redeemAmount` en `createBooking` (¿es total o discount?). Documentar en `references/performance.md` y en el plugin.

---

## Fase 7 — Reagendar visible para el usuario (0.5 días, depende de Fase 1)

El feature está construido al 95% pero sin botón de entrada. Ver `AUDITORIA_CANCEL_REAGENDAR.md` §2.

- [ ] **7.1** Agregar botón "Reagendar" en `appointment_detail_page.dart` junto a "Cancelar cita".
- [ ] **7.2** Visible solo si `canCancel == true` (mismas reglas que cancelar).
- [ ] **7.3** Al tap: `Navigator.push(BookingsPage(appointmentId: appointmentId.toString(), service: ..., selectedBarber: ..., initialBranch: ..., initialDate: bookingStart))`.
- [ ] **7.4** Después de reagendar (si éxito), volver al detail con `pop(true)` y refrescar.
- [ ] **7.5** En modo `_isEditing` deshabilitar selector de servicio y barbero (solo se permite cambiar fecha/hora).

---

## Fase 8 — Datos bancarios visibles tras orden (1 día, depende de Fase 1)

- [ ] **8.1** Crear `HabitoBankDataSheet` (`lib/shared/widgets/habito_bank_data_sheet.dart`). Ver shape en `references/design_system.md`.
- [ ] **8.2** Definir los datos bancarios. Idealmente vienen del backend (`/shop/payment-methods`). Mientras tanto, hardcodear en `AppConfig.bankDetails`.
- [ ] **8.3** Después de crear orden con `bacs`, mostrar el sheet con: número de cuenta, titular, banco, RUC, correo para comprobante.
- [ ] **8.4** Botón "Copiar número de cuenta" usando `Clipboard.setData`.
- [ ] **8.5** Botón "Abrir WhatsApp" con `url_launcher` y número de Hábito.
- [ ] **8.6** Botón "Subir comprobante" que navega a `OrdersPage(initialOrderId: ...)`.

---

## Fase 9 — Validación cédula/RUC ecuatoriana (0.5 días, depende de Fase 0)

- [ ] **9.1** Crear `lib/core/validators/ecuador_id_validator.dart` con módulo 11 para cédula y RUC. Patrón: `references/ux.md` §3.
- [ ] **9.2** Reemplazar la validación actual en `register_page.dart` (líneas 687-714) por el validador real.
- [ ] **9.3** Reemplazar la validación en `checkout_page.dart` (líneas 585-591, 1057-1058).
- [ ] **9.4** Reemplazar la validación en `bookings_page.dart` (cualquier `_isCustomerFiscalDataValid`).
- [ ] **9.5** Tests unitarios manuales con cédulas/RUC reales para verificar.

---

## Fase 10 — Forms a nivel pro (1 día, depende de Fase 0)

- [ ] **10.1** Crear `lib/core/validators/form_validators.dart` con `validateEmail`, `validatePhone`, `validateRequired`.
- [ ] **10.2** Recorrer todos los `TextFormField` de la app y agregar `keyboardType` + `textInputAction` + `autofillHints` faltantes. Mapeo en `references/ux.md` §3.
- [ ] **10.3** En `checkout_page.dart`, migrar de validación manual (`_missingCheckoutInfo`) a `Form.validate()` + validators por campo.
- [ ] **10.4** Agregar `maxLength` razonable a campos de texto libre (businessName, address, customerNote: 250 chars).

---

## Fase 11 — Caché de availability (0.5 días, depende de Fase 0)

- [ ] **11.1** En `HabitoBookingApi`, agregar caché en memoria por clave `(serviceId, employeeId, locationId, date)` con TTL de 30-60 s.
- [ ] **11.2** Quitar `Cache-Control: no-cache` y `Pragma: no-cache` de `getAvailability` (basta con el cache buster `_ts`, y mejor aún con la caché local).
- [ ] **11.3** En `bookings_page.dart`, mantener `_availabilityRequestId` (la guarda contra respuestas obsoletas sigue siendo útil).
- [ ] **11.4** Verificar que `extras` siga viajando bien — si genera URL muy larga con muchos extras, evaluar pasar `getAvailability` a `POST` (consultar con backend).

---

## Fase 12 — Puntos: anti doble-gasto + lógica compartida (2 días, depende de Fase 6)

- [ ] **12.1** Crear `lib/features/points/points_calculator.dart` con `resolveState`, `pointsToUse`, `pointsDiscount`, `helperMessage`. Mover la lógica duplicada de `bookings_page.dart` y `checkout_page.dart`.
- [ ] **12.2** Refactorizar `bookings_page.dart:820-914` para usar `PointsCalculator`.
- [ ] **12.3** Refactorizar `checkout_page.dart:416-477` para usar `PointsCalculator`.
- [ ] **12.4** Implementar decremento optimista en `PointsProvider`: al iniciar `createBooking`/`createOrder`, llamar `pointsProvider.reserve(amount)` que descuenta del `_summary.balance` localmente. Si falla, llamar `pointsProvider.releaseReservation(amount)`.
- [ ] **12.5** En `BookingsPage._submitBooking` y `CheckoutPage._submit`, deshabilitar el switch "Usar puntos" si `pointsProvider.hasReservation == true`.
- [ ] **12.6** Conectar `PointsApi.getHistory()` paginado a la `PointsPage` con infinite scroll o "Ver más" (depende de `historyTotal`).
- [ ] **12.7** Decidir destino de `bookingPointsEnabled` y `orderPointsEnabled` (campos huérfanos): usarlos para mostrar "Ganarás X puntos por esta operación", o eliminarlos del modelo.
- [ ] **12.8** Bajar el default de `redeemMaxPercent` de 100% a un valor conservador (30-50%).

---

## Fase 13 — Validación pre-checkout del carrito (1 día, depende de Fase 5)

- [ ] **13.1** Agregar endpoint backend `/shop/cart/validate` que reciba `[{product_id, quantity}]` y devuelva `{items: [{id, available, current_price, current_stock}]}`.
- [ ] **13.2** En `ShopProvider.checkout`, antes del `createOrder`, llamar `validateCart`.
- [ ] **13.3** Si hay diferencias (precio cambió, producto agotado, producto desactivado), mostrar dialog "Tu carrito necesita actualizarse" con detalle por item, y aplicar los cambios al carrito antes de continuar.
- [ ] **13.4** Si el usuario acepta, refrescar `_cartItems` y volver a la pantalla de checkout con los nuevos totales.

---

## Fase 14 — Validación de comprobante de pago (0.5 días, depende de Fase 0)

- [ ] **14.1** En `orders_page.dart:73-109` (`_selectAndUploadPaymentProof`), validar tipo de archivo (`jpg`, `jpeg`, `png`) y tamaño (<5 MB) antes de subir.
- [ ] **14.2** Si no cumple, mostrar SnackBar amable y abortar.
- [ ] **14.3** Mostrar preview del archivo seleccionado antes de confirmar el upload.

---

## Fase 15 — Limpieza de código muerto (0.5 días, depende de Fase 0)

Después de verificar con `Grep` que no se usan:

- [ ] **15.1** Eliminar `lib/features/bookings/data/booking_service.dart` (DEAD CODE — endpoints `/reservas/*` no se usan).
- [ ] **15.2** Eliminar `BookingModel`, `CreateBookingRequest`, `RescheduleBookingRequest`, `BookingException` del mismo archivo.
- [ ] **15.3** Verificar si `lib/features/bookings/data/appointment_data.dart` (`AppointmentData`) se usa. Si no, eliminar.
- [ ] **15.4** Eliminar todos los `.bak-*` del repo (si están en git, agregarlos a `.gitignore` primero).

---

## Fase 16 — Accesibilidad mínima (1 día, depende de Fase 1)

- [ ] **16.1** Steppers del carrito a 44×44 px (hoy 34×34).
- [ ] **16.2** `Semantics(label: ..., image: true)` en imágenes de productos y servicios.
- [ ] **16.3** `Tooltip` en botones de solo icono (search, cart, notifications, etc.).
- [ ] **16.4** Verificar contraste de `AppColors.textSecondary` sobre `AppColors.background` con un checker (4.5:1 mínimo).
- [ ] **16.5** Agregar `Dismissible` con `confirmDismiss` y SnackBar "Deshacer" al quitar productos del carrito.

---

## Fase 17 — Tracking y guías de envío (1 día, depende de coordinación con backend)

- [ ] **17.1** Agregar campos `tracking_number` y `tracking_url` al payload de orden (backend).
- [ ] **17.2** En `orders_page.dart` detail, mostrar la sección de tracking si la orden es delivery y tiene número de guía.
- [ ] **17.3** Botón "Ver estado" que abre `tracking_url` con `url_launcher`.

---

## Fase 18 — Migrar pantallas a `AppTopHeader` (0.5 días, depende de Fase 2)

- [ ] **18.1** `MyAppointmentsPage`.
- [ ] **18.2** `OrdersPage`.
- [ ] **18.3** `AppointmentDetailPage`.
- [ ] **18.4** Documentar excepción de `ProfilePage` (dark theme intencional).

---

## Fases descartadas o opcionales

Cosas que las auditorías mencionaron pero no priorizamos:

- **Soporte de variaciones de WooCommerce** (talla L/XL): solo si Hábito comienza a vender productos variables.
- **Integración con pasarela real** (Datafast / Place to Pay / Payphone): proyecto grande, fuera del scope de optimización; abrir como iniciativa separada.
- **Dark mode global**: la marca es predominantemente light; mantener.

---

## Resumen ejecutivo (para vista rápida)

| Fase | Días | Bloquea | Impacto |
|---|---|---|---|
| 0. Quick wins | 1 | — | Alto en performance perceptible |
| 1. Design system base | 3 | F2, F3, F4, F7, F8, F16, F18 | Foundational |
| 2. Migración visual | 5 | — | Consistencia visual |
| 3. Estados uniformes | 2 | — | UX percibida |
| 4. Mensajes amables | 1 | — | UX en errores |
| 5. Persistencia carrito | 1 | F13 | Reduce abandono |
| 6. Idempotency + retry | 3 | F12 | Cero órdenes duplicadas |
| 7. Reagendar visible | 0.5 | — | Feature crítico ausente hoy |
| 8. Datos bancarios | 1 | — | Conversión post-checkout |
| 9. Validación cédula/RUC | 0.5 | — | Cumplimiento fiscal |
| 10. Forms profesionales | 1 | — | UX en formularios |
| 11. Caché availability | 0.5 | — | -60% requests reservas |
| 12. Puntos refactor | 2 | — | Anti doble-gasto |
| 13. Validación carrito | 1 | — | Cero discrepancias |
| 14. Validar comprobante | 0.5 | — | Robustez upload |
| 15. Limpieza código muerto | 0.5 | — | Mantenibilidad |
| 16. Accesibilidad | 1 | — | Cumplimiento + UX |
| 17. Tracking envío | 1 | Backend | UX post-compra |
| 18. AppTopHeader unificado | 0.5 | — | Consistencia |

**Total**: ~25 días-persona si se hace serial. Con paralelización razonable: ~3 semanas.

---

## Cómo invocar al asistente para ejecutar

Ejemplos de prompts efectivos:

> "Ejecuta la Fase 0 completa del plan de optimización. Empieza por 0.2 (doble fetch en cart_page) y avísame cuando termines cada tarea."

> "Quiero hacer la Fase 1 (design system base). Crea los 6 archivos de tema y los 3 widgets compartidos siguiendo references/design_system.md."

> "Aplica la Fase 2.1 al home_page.dart. Migra todos los hardcoded a tokens del design system."

> "Resuelve la Fase 7 (botón reagendar) end-to-end."

El asistente debería invocar automáticamente la skill `habito-flutter-optimizer` por la mención del plan o de la app. Si no lo hace, escribe explícito: "usa la skill habito-flutter-optimizer".
