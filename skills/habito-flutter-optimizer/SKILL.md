---
name: habito-flutter-optimizer
description: Aplica las optimizaciones auditadas de la app Flutter Hábito (barbería, WooCommerce + Amelia, Provider, Material 3) en rendimiento, consistencia visual y experiencia de usuario. Usa esta skill siempre que el usuario mencione la app Hábito, su carpeta D:\HABITO\APP\habito, los flujos de productos, carrito, checkout, órdenes, reservas, barberos, locaciones, horarios, puntos, notificaciones, o pida "optimizar", "mejorar rendimiento", "rediseño", "consistencia visual", "mejorar UX", "limpiar código", "implementar [hallazgo de auditoría]" o "ejecutar plan de optimización", incluso si no nombra explícitamente esta skill. La skill traduce los hallazgos de las auditorías AUDITORIA_*.md del repo en cambios concretos siguiendo el design system, los patrones de cache y los snippets que aquí se documentan.
---

# Optimizador de la app Hábito (Flutter)

Esta skill se carga cuando trabajas en `D:\HABITO\APP\habito\` (Flutter, Material 3, Provider, WooCommerce + Amelia, Firebase Messaging). Hay 6 documentos previos en el repo que documentan los hallazgos y un plan maestro:

- `AUDITORIA_HABITO.md` — rendimiento + visual + UX (general)
- `AUDITORIA_AMELIA.md` — barberos, locaciones, servicios, horarios, citas
- `AUDITORIA_CANCEL_REAGENDAR.md` — cancelar y reagendar
- `AUDITORIA_PRODUCTOS_CARRITO_PAGO.md` — productos, carrito, checkout, órdenes
- `AUDITORIA_PUNTOS.md` — programa de puntos myCRED
- `PLAN_OPTIMIZACION.md` — plan maestro con fases priorizadas

**Tu trabajo es:** ejecutar tareas de ese plan respetando los patrones de esta skill, sin volver a auditar (las auditorías ya se hicieron) y sin reinventar el design system (las decisiones ya están tomadas).

---

## Workflow estándar

Cuando recibes una tarea de optimización en este repo, sigue este orden:

1. **Identifica la fase del plan** (`PLAN_OPTIMIZACION.md`). Si la tarea no está, decide si es un quick-win independiente o si conviene agregarla al plan.
2. **Lee solo la referencia que aplica** (no leas las 4 a ciegas):
   - Cambios de cache, providers, network, imágenes, listas → `references/performance.md`
   - Colores, tipografía, espaciado, bordes, sombras, componentes visuales → `references/visual.md`
   - Loading/empty/error states, formularios, accesibilidad, deep links, mensajes → `references/ux.md`
   - Crear o extender el design system (`AppSpacing`, `AppShadows`, `AppTypography`, etc.) → `references/design_system.md`
3. **Lee el archivo afectado completo** (no parches a ciegas — el contexto importa).
4. **Aplica el patrón** que indica la referencia. Si el patrón no existe, escríbelo en la referencia correspondiente *antes* de aplicarlo, así queda para el futuro.
5. **Verifica con grep** que no rompiste otros call sites del mismo símbolo.
6. **Resume al usuario**: archivo + líneas tocadas + qué cambió + verificación. Sin posambles innecesarios.

## Reglas duras

Estas son decisiones ya tomadas. No las re-discutas:

- **Stack permitido**: solo paquetes ya en `pubspec.yaml`. No agregar dependencias sin pedir permiso explícito al usuario.
- **Material 3 + light theme only**. La app no soporta dark mode salvo `ProfilePage` (excepción documentada).
- **Provider** para state management. NO migrar a Bloc/Riverpod.
- **Persistencia sensible** → `flutter_secure_storage`. **Persistencia normal** (carrito, prefs UI) → `SharedPreferences` (agregar `shared_preferences` al pubspec si no está; pedir permiso primero). **Cache de catálogo** → `path_provider` + JSON en `Documents/`.
- **Nunca tocar `.bak-*` files** del repo. Son backups, ignorarlos en globs.
- **No introducir emojis** en código ni en strings de UI.
- **Tildes en español**: la app está en español de Ecuador. Cuando edites cualquier string de UI, corrige las tildes faltantes que veas (es un problema recurrente: "Aun" → "Aún", "modulo" → "módulo", "esta" → "está", "vencio" → "venció", "Si" → "Sí", "accion" → "acción").
- **No remover código sin verificar** que no sea referenciado (grep antes de borrar).
- **Cero retries en operaciones con dinero (`createBooking`, `createOrder`)** sin agregar `idempotency_key` primero. Las dos cosas van juntas o ninguna.

## Anti-patrones que ya identificamos en este repo

Cuando los veas, repáralos aunque no sean parte de la tarea actual:

1. `clearCache()` global en respuesta a un pull-to-refresh local → invalidar solo el recurso correspondiente.
2. `context.watch<ShopProvider>()` o `context.watch<PointsProvider>()` en niveles altos del árbol que disparan rebuild masivo → reemplazar por `Selector<P, T>` localizado.
3. `unawaited(forceRefresh: true)` después de `getCachedX()` cuando la caché está fresca → eliminar el doble fetch.
4. `extractServiceImageUrl(service)` o cualquier normalización pesada llamada por frame en `build()` → memoizar dentro del propio mapa (`service['_resolvedImage'] ??= ...`).
5. `Color(0xFF...)` hardcoded → usar `AppColors`. Si el color no existe en `AppColors`, agrégalo allí primero.
6. `fontSize: N` o `fontWeight: FontWeight.wN` sueltos → usar `Theme.of(context).textTheme.X` o `AppTypography.X` (cuando se cree).
7. `BorderRadius.circular(N)` con valor arbitrario → usar `AppRadius.sm/md/lg`.
8. `SizedBox(height/width: N)` con valor mágico → usar `AppSpacing.xs/sm/md/lg/xl/xxl`.
9. `BoxShadow(...)` ad-hoc → usar `AppShadows.light/medium/strong`.
10. `e.toString().replaceFirst('Exception: ', '')` mostrado al usuario → mapear a mensajes amables en un `_friendlyXxxError(e)`.
11. `redeem_points` enviado como número en un endpoint y como string en otro → estandarizar a número.
12. Operaciones críticas (cancel/reschedule/createOrder/createBooking) sin retry e `idempotency_key` → agregar ambos.

## Antes de modificar un archivo grande

Si el archivo supera ~1500 líneas (`bookings_page.dart` está en ~4400, `checkout_page.dart` ~1100, `habito_shop_api.dart` ~2000, `habito_booking_api.dart` ~1660), no leas el archivo completo de golpe — usa `Grep` con los símbolos relevantes y luego lee solo las secciones que vas a tocar.

## Después de cualquier cambio

1. Confirma compilación mental: ¿imports nuevos? ¿símbolos exportados que cambian firma?
2. Si tocaste un widget público de `lib/shared/widgets/`, busca todos sus call sites con `Grep` y verifica que las props no rompieron a nadie.
3. Si tocaste un servicio (`HabitoShopApi`, `HabitoBookingApi`, `PointsApi`, `AuthApi`), valida que sus consumidores siguen usando la misma firma o actualízalos en el mismo cambio.
4. **No corras `flutter test` ni `flutter analyze`** desde esta sesión a menos que el usuario lo pida — son lentos y pueden estar mal configurados localmente. Reporta el cambio y deja que el usuario lo verifique en su IDE.
5. Cierra con un resumen de 3 líneas máximo: qué cambió, por qué, qué falta verificar manualmente.

## Cuando agregas algo nuevo al design system

Cualquier constante nueva (color, spacing, shadow, typography, radius) **se documenta en `references/design_system.md`** *antes* de usarse en el código. Esto evita drift futuro. Si tienes que decidir un valor nuevo, revisa primero qué hay en el design system y reusa antes de inventar.

## Cuando un hallazgo de auditoría no aplica

Si llegas a una tarea del plan y descubres que el hallazgo ya está resuelto, márcalo en `PLAN_OPTIMIZACION.md` con fecha y agente, y sigue con la siguiente. No vuelvas a "verificar" cosas ya hechas.
