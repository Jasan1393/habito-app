---
name: Auditoría flujos Cancelar y Reagendar
description: Análisis end-to-end de cancelación y reagendamiento de citas
fecha: 2026-05-03
endpoints: POST /bookings/{id}/cancel · POST /appointments/{id}/reschedule
---

# Auditoría — Flujos Cancelar y Reagendar

## TL;DR

- **Cancelar funciona** end-to-end pero tiene varios huecos: sin retries, mensaje técnico al usuario en errores, no se invalida la lista local de citas tras cancelar (depende de un argumento de ruta), confirma con un dialog sin tilde y la lógica de elegibilidad acepta hasta 9 keys distintas para "se puede cancelar".
- **Reagendar es código muerto en la UI.** Toda la infraestructura existe (endpoint, método, página con título "Reagendar cita", `_isEditing`, `_rescheduleBooking()`) pero **ninguna pantalla construye `BookingsPage(appointmentId: …)`**. El botón "Agendar nuevamente" del detalle abre una reserva nueva, no un reagendamiento. El usuario final no puede reagendar desde la app.

---

## 1. Cancelar cita

### Endpoint y service
**Archivo:** `habito_booking_api.dart:567-583`
```dart
POST /bookings/{bookingId}/cancel
Headers: Authorization: Bearer {token}, Content-Type: application/json, Accept
Timeout: 20s · Retries: 0
```
- Cuerpo vacío. Solo el ID en la URL.
- No envía motivo de cancelación.
- No incluye `idempotency_key`.
- Usa `_decodeResponse` para 401/403/500 y luego valida `data['success'] == true`.

### Entry point en UI
**Archivo:** `appointment_detail_page.dart`

| Componente | Líneas | Observación |
|---|---|---|
| Botón "Cancelar cita" | 740-771 | `ElevatedButton` con `_isCancelling` toggle al spinner. Bien. |
| `_canCancelAppointment()` | 328-395 | Determina si el botón está habilitado. Ver hallazgos abajo. |
| `_cancelUnavailableReason()` | 397-413 | Mensaje de por qué no se puede cancelar. |
| `_cancelAppointment()` | 415-480 | Diálogo de confirmación + llamada al API. |
| Dialog de confirmación | 432-450 | "Cancelar cita" / "Esta accion cancelara tu cita..." |

### Flujo paso a paso
1. La pantalla calcula `canCancel` en cada `build()` llamando a `_canCancelAppointment()`.
2. Si `canCancel == true`, el botón "Cancelar cita" queda habilitado.
3. Tap → `showDialog` con confirmación "No / Si, cancelar".
4. Si confirma → `setState({_isCancelling = true})` → `await HabitoBookingApi.cancelBooking(bookingId, authToken)`.
5. Éxito → SnackBar "Cita cancelada correctamente." → `Navigator.pop(context, true)` (devuelve `true` al caller).
6. Error → SnackBar con `e.toString().replaceFirst('Exception: ', '')`.

### Hallazgos

**1.1 — `_canCancelAppointment()` acepta 9 nombres distintos para "se puede cancelar".**
Líneas 342-352: itera sobre `can_cancel`, `canCancel`, `cancelable`, `is_cancelable`, `isCancelable`, `cancellation_available`, `cancellationAvailable`, `within_cancellation_window`, `withinCancellationWindow`. Esto sugiere que el backend no normaliza el contrato. La app está cargando con la deuda técnica del plugin. **Sugerencia:** consolidar a un único campo (`can_cancel`) en el plugin y eliminar los 8 fallback en cliente.

**1.2 — Lógica de "fuera de ventana" basada en regex de texto en español/inglés.**
Líneas 365-372: `cancelWindowText.contains('fuera') || .contains('outside') || .contains('expired')`. Si el plugin cambia el texto a "vencida" o "no permitida", la lógica de `canCancel` queda inconsistente con el backend. Mejor usar una bandera booleana o un código.

**1.3 — `_cancelAppointment()` requiere `bookingId` (no `appointmentId`).**
Línea 459: `cancelBooking(bookingId: bookingId, ...)`. El usuario podría tener un `appointmentId` válido sin `bookingId` (por ejemplo en respuestas parciales). El método del API recibe `bookingId` pero el endpoint REST se llama `/bookings/{id}/cancel` — verificar que el ID que se envía sea efectivamente el de la *reserva* y no el del *appointment* (Amelia distingue ambos: una appointment puede tener varios bookings).

**1.4 — Cero retries en `cancelBooking`.**
Si la red falla en este momento, el usuario ve "No se pudo cancelar la cita: ..." y la cita sigue activa. En la cancelación, un retry idempotente con backoff sería seguro (la operación es idempotente: cancelar dos veces lo mismo no causa daño si el plugin maneja bien los duplicados).

**1.5 — El diálogo de confirmación tiene errores de tildes.**
- "Esta accion cancelara tu cita. Deseas continuar?" → "Esta acción cancelará tu cita. ¿Deseas continuar?"
- "Si, cancelar" → "Sí, cancelar"
- "La cita ya esta cancelada." → "La cita ya está cancelada."
- "La solicitud vencio porque la fecha de la cita ya paso." → "La solicitud venció porque la fecha de la cita ya pasó."

Aparece varias veces (líneas 401, 405, 407, 437, 446). Estilísticamente la app tiene tildes en otros lados, esto se ve descuidado.

**1.6 — Sin motivo de cancelación.**
La operación no permite enviar un `reason`. Para gestión interna del barbershop, conocer por qué cancela el cliente es valioso (cambio de planes, encontró otra disponibilidad, problema con barbero, etc.). Agregar un selector opcional en el diálogo con razones predefinidas + campo libre.

**1.7 — Estado local no se actualiza tras cancelar.**
Línea 466: `Navigator.pop(context, true)` devuelve `true` al caller. El caller (`my_appointments_page.dart`) debería detectar este `true` y refrescar la lista, pero hay que verificar si lo hace. Si solo se actualiza al hacer pull-to-refresh, el usuario ve la cita aún "Confirmada" hasta refrescar. **Revisa:** `Navigator.push(...).then((value) { if (value == true) _loadAppointments(); });` en my_appointments.

**1.8 — Mensaje de error técnico al usuario.**
Línea 471: `'No se pudo cancelar la cita: ${e.toString().replaceFirst('Exception: ', '')}'`. Si el backend devuelve "Exception: SQLSTATE[...]" o "Internal Server Error", eso va directo al usuario. Falta un `_friendlyCancelError()` análogo al `_friendlyBookingError()` que ya existe en `bookings_page.dart`.

**1.9 — Caché local no se invalida tras cancelar.**
`HabitoBookingApi.clearMyBookingsCache()` está vacío (línea 59-62: "La versión actual no mantiene una caché separada de mis reservas."). Si más adelante se agrega caché de mis citas, hay que invalidarla aquí.

**1.10 — Race condition: el botón es `disabled` pero el dialog ya está abierto.**
Si el estado `_isCancelling` se vuelve true, el botón queda deshabilitado. Pero si la cita se canceló desde otro device durante el dialog, no se detecta. Edge case poco probable.

**1.11 — `auth.isLoggedIn || token == null` — fallo silencioso.**
Línea 428-430: si no hay sesión, hace `return` sin mensaje. El usuario hace tap, ve un dialog, confirma, y no pasa nada visible. Mostrar "Inicia sesión para cancelar".

**1.12 — Estilo del botón rompe el sistema visual.**
Líneas 747-756: usa `Color(0xFFD4AF37)` y `Color(0xFFE7DFD4)` hardcoded en lugar de `AppColors.secondary`/`AppColors.border`. Igual `OutlinedButton` arriba (líneas 723-730) con `Color(0xFF9C7732)`.

**1.13 — La acción de "cancelar cita" usa el mismo color dorado que la acción primaria (Reservar / Confirmar).**
Patrón de UX confuso: la acción destructiva debería usar `AppColors.danger` o ser un botón secundario (texto rojo/outlined). Actualmente "Cancelar cita" se ve como un CTA atractivo en lugar de una acción seria.

---

## 2. Reagendar cita

### Endpoint y service
**Archivo:** `habito_booking_api.dart:585-609`
```dart
POST /appointments/{appointmentId}/reschedule
Headers: Authorization: Bearer {token}, Content-Type: application/json, Accept
Body: {"booking_start": "YYYY-MM-DD HH:mm:ss"}
Timeout: 20s · Retries: 0
```
- Solo permite cambiar la fecha y hora.
- **No permite cambiar** servicio, barbero ni sucursal.
- Sin `idempotency_key`.

### Implementación en BookingsPage
**Archivo:** `bookings_page.dart`

| Componente | Líneas | Observación |
|---|---|---|
| Constructor con `appointmentId` | 30, 40 | Se acepta como parámetro opcional. |
| `_isEditing` | 86 | `true` cuando `appointmentId != null`. |
| `_isNewBookingFlow` | 88-96 | `true` cuando *todo* es null. |
| Branch en `_submitBooking` | 1935-1938 | `if (_isEditing) await _rescheduleBooking(...)`. |
| `_rescheduleBooking()` | 2111-2167 | Llama a `rescheduleAppointment` y navega a /main con tab citas. |
| Título "Reagendar cita" | 3028 | AppBar adapta el texto. |
| Botón "Guardar cambios" | 3512 | El CTA cambia su label en modo edición. |

### Entry point en UI
**No existe.**

Auditoría exhaustiva con grep:

```
BookingsPage(appointmentId: …)  →  0 ocurrencias en código activo
```

Las construcciones encontradas son:

| Archivo | Línea | Argumentos |
|---|---|---|
| `team_habito_home_section.dart` | 525 | `selectedBarber: barber` |
| `team_habito_page.dart` | 241, 704 | `selectedBarber: barber` |
| `appointment_detail_page.dart` | 702 | `service`, `selectedBarber`, `initialBranch`, `initialBarber` (botón "Agendar nuevamente" — **es un rebook, no reagendar**) |
| `my_appointments_page.dart` | 1102 | `service`, `selectedBarber`, `initialBranch`, `initialBarber` (botón "Reservar de nuevo" — **rebook**) |
| `my_appointments_page.dart` | 1488 | `BookingsPage()` vacío (botón "Reservar cita" del empty state) |
| `app_routes.dart` | 32 | `BookingsPage()` vacío (ruta `/bookings`) |

**Conclusión:** todo el flujo de reagendar (página, branch en `_submitBooking`, método `_rescheduleBooking`, llamada al API, manejo de errores, navegación post-éxito) existe pero está completamente huérfano. Un usuario nunca puede llegar a la pantalla en modo `_isEditing == true`.

### Hallazgos

**2.1 — Feature dead-coded en UI.** ⚠️ CRÍTICO
La barbería tiene un endpoint funcional, una pantalla preparada y lógica completa, pero el botón nunca se construyó. Esto se traduce en:
- Los clientes que quieren reagendar tienen que cancelar + reservar de nuevo.
- Cancelar + reservar de nuevo puede liberar el slot a otro cliente (race condition al cancelar).
- Si la cancelación tiene política de "no se puede cancelar dentro de X horas", el usuario queda atrapado.

**Sugerencia:** agregar botón "Reagendar" en `appointment_detail_page.dart` junto a "Cancelar cita", visible solo si la cita es futura y `canCancel` es true (porque las políticas suelen ser similares). Construir `BookingsPage(appointmentId: '...', service: {...}, selectedBarber: {...}, initialDate: ..., initialBranch: ...)`.

**2.2 — `_rescheduleBooking` recibe `selectedTime` pero no respeta el servicio/barbero originales.**
La lógica actual permitiría cambiar barbero/servicio en pantalla y aún así llamar a `rescheduleAppointment`, que solo manda `booking_start`. Si el usuario cambia el barbero en la UI, su selección se pierde silenciosamente al guardar. **Sugerencia:** en modo `_isEditing`, deshabilitar/ocultar los selectores de servicio y barbero (o solo permitir cambiar barbero si el endpoint lo soporta).

**2.3 — Cero retries en `rescheduleAppointment`.**
Mismo problema que cancel y create. Es la única operación que toca dinero indirectamente (puntos ya redimidos en la reserva original).

**2.4 — El método del API solo envía `booking_start`. ¿Qué pasa con extras, persons, payment?**
La firma de `rescheduleAppointment` (línea 585-609) acepta SOLO `appointmentId`, `newBookingStart`, `authToken`. Si la cita original tenía extras o un payment_method asociado, esto no se reenvía. Asumiendo que el plugin lo conserva en el side servidor, ok — pero la app queda dependiendo de un comportamiento implícito.

**2.5 — Navegación post-reschedule destruye toda la pila.**
Líneas 2147-2156: `pushAndRemoveUntil(...(route) => false)` reemplaza toda la stack con `MainNavigationPage(initialIndex: 2)`. El usuario pierde el contexto previo y vuelve al home de "Mis citas". Para una operación rápida, sería mejor `pop(true)` y dejar que MyAppointments refresque.

**2.6 — `_friendlyBookingError(e)` se usa para reagendar, pero el método mapea errores de "create booking".**
Línea 2159. Si Amelia devuelve "SLOT_NOT_AVAILABLE" o "RESCHEDULE_LIMIT_REACHED" o "OUTSIDE_RESCHEDULE_WINDOW", la traducción puede no contemplarlos. Crear `_friendlyRescheduleError()`.

**2.7 — `int.tryParse(widget.appointmentId ?? '')` (línea 2112).**
El widget recibe `String?` pero el endpoint exige `int`. Si en algún momento un caller pasa un ID alfanumérico, falla silenciosamente con "No pudimos identificar la cita...". Mejor: cambiar el tipo del parámetro a `int?` directamente.

**2.8 — Backend devuelve `Map<String, dynamic>` pero el código no lo usa.**
Línea 605-608: el método retorna el `data` de la respuesta, pero `_rescheduleBooking` lo descarta (`await ... ;`). Si el backend devuelve el nuevo `booking_start` confirmado o el nuevo `status`, se pierde. La app asume que la respuesta refleja exactamente lo que se mandó.

**2.9 — No se actualiza la caché de `getMyBookings` tras reagendar.**
Como `clearMyBookingsCache()` está vacío, esto es no-op hoy. Pero si más adelante se agrega caché, esto va a romper.

---

## Comparativa con `createBooking`

| Aspecto | createBooking | cancelBooking | rescheduleAppointment |
|---|---|---|---|
| Retries | 0 | 0 | 0 |
| Idempotency key | ❌ | ❌ | ❌ |
| Body completo | Sí (extras, payment, points) | Vacío | Solo `booking_start` |
| Token requerido | Opcional (guest) | Sí | Sí |
| Manejador de error friendly | Sí (`_friendlyBookingError`) | No (raw e.toString) | Reusa el de booking |
| Entry point en UI | Sí (BookingsPage) | Sí (AppointmentDetail) | **No** |
| Caché invalidada al éxito | Sí (puntos, perfil) | No (no aplica hoy) | No |

---

## Top 7 acciones priorizadas

| # | Acción | Severidad |
|---|--------|-----------|
| 1 | Conectar el botón "Reagendar" en `appointment_detail_page.dart` para activar el flujo huérfano | **Crítico — feature ausente para usuarios** |
| 2 | Agregar retries idempotentes a `cancelBooking` y `rescheduleAppointment` | Alto |
| 3 | Crear `_friendlyCancelError()` y `_friendlyRescheduleError()` que mapeen errores comunes | Alto |
| 4 | Refrescar la lista de citas en `my_appointments_page` cuando el detalle devuelva `true` (verificar que ya esté hecho) | Alto |
| 5 | Diferenciar visualmente "Cancelar cita" del CTA dorado primario (usar `AppColors.danger` o outlined) | Medio |
| 6 | Corregir tildes en `appointment_detail_page.dart`: "acción", "cancelará", "Sí", "está", "venció", "pasó" | Medio |
| 7 | Consolidar el contrato del backend a un único campo `can_cancel` y eliminar los 9 fallback en cliente | Medio |

---

## Notas adicionales

**Política de cancelación.** El backend expone múltiples campos (`cancel_until`, `cancel_before`, `cancellation_deadline`, `cancel_window`, `can_cancel`, etc.). Esto sugiere que la lógica de "cuándo se puede cancelar" está dispersa en el plugin. Conviene documentar la política en el README del plugin y enviar un único campo derivado al cliente.

**Reagendar como cancelar+crear.** Algunos sistemas implementan reagendar internamente como cancel+create. Si el plugin de Hábito hace eso, se pierde el ID original. Si lo hace como UPDATE de la appointment de Amelia, conserva el ID (bueno para tracking). Verificar cuál es el comportamiento real consultando con el desarrollador del plugin o haciendo dos requests de prueba y comparando los IDs antes/después.

**Recordatorios push.** Si el cliente reagenda, los recordatorios push programados (24h antes, 1h antes) deberían recalcularse. Verificar que el plugin los reprograma.
