---
name: Auditoría Productos · Carrito · Checkout
description: Análisis end-to-end del flujo de e-commerce
fecha: 2026-05-03
---

# Auditoría — Productos, Carrito y Pago

## TL;DR

El catálogo de productos está bien estructurado (caché en disco con schema versioning, fallback al endpoint público de WooCommerce, búsqueda local con scoring) pero arrastra deuda en multi-warehouse, búsqueda variable y filtrado de visibilidad. **El carrito vive solo en RAM** (verificado: cero referencias a `SharedPreferences`/secure storage en `shop_provider.dart`). Cerrar el app pierde todo. El checkout funciona pero **sin pasarela de pago real** — solo transferencia bancaria manual con comprobante subido posteriormente desde la pantalla de órdenes. Sin `idempotency_key` en la creación de orden. Validaciones de cédula/RUC son débiles (solo longitud, no algoritmo de módulo 11).

---

## 1. PRODUCTOS

### Endpoints

| Recurso | Endpoint | Fallback público |
|---|---|---|
| Lista | `GET /shop/products` | `GET /wp-json/wc/store/v1/products` |
| Detalle | `GET /shop/products/{id}` | `GET /wp-json/wc/store/v1/products/{id}` |
| Categorías | `GET /shop/categories` | `GET /wp-json/wc/store/v1/products/categories` |
| Almacenes | `GET /shop/warehouses` | — |

Timeout 25 s. Fallback al endpoint público de WooCommerce si el custom falla — buena práctica de resiliencia.

### Caché

- `_productsTtl = 5 min` (lista fresh) · `_productTtl = 10 min` (producto fresh)
- `_staleListTtl = 3 días` · `_staleProductTtl = 7 días`
- Persistencia en `Documents/shop_cache/catalog.json`
- `_cacheSchemaVersion = 9` — cuando se incremente, la caché vieja se descarta automáticamente. Bien.
- `_searchIndex` con TTL de 10 min, `_searchIndexSeedLimit = 160`

### Hallazgos

**1.1 — Filtrado de servicios por slug es frágil.**
`_excludedStoreCategorySlugs = {'servicio', 'servicios', 'service', 'services', 'amelia-servicios', 'amelia-services', 'reservas', 'bookings'}` (línea 22-31). Si una categoría se llama distinto en WooCommerce, los servicios de Amelia se cuelan a la tienda como productos. Mejor usar un atributo dedicado (`is_service: true`) emitido por el plugin.

**1.2 — Índice de búsqueda limitado a 160 productos.**
`_searchIndexSeedLimit = 160` (línea 21). Si el catálogo crece por encima de eso, la búsqueda local nunca encuentra los nuevos hasta que expire la caché (10 min) y se reseed. Sugerencia: subir a 500+ o paginar el índice.

**1.3 — Sin soporte de variaciones de WooCommerce.**
La app reconoce `variation_id` en line items pero no expone un selector de variante en `product_detail_page.dart`. Productos variables (talla L/XL, etc.) se muestran como simples. Si en algún momento se incorporan, el carrito acepta `variation_id` solo si se pasa programáticamente.

**1.4 — `_isProductVisibleForSale` con lógica inconsistente.**
Líneas 1100-1101 tienen un branch que requiere `visibility == "search"` con search no vacío. Pero la mayoría de productos en Woo tienen `visibility == "visible"` por defecto, así que ese branch nunca se ejecuta. Revisar si hace algo útil o es código muerto.

**1.5 — `_normalizeWarehouseStockList` no normaliza `in_stock` a bool.**
`in_stock: _parseBool(...) ?? quantity > 0` (línea 1156). Si `quantity` viene como string "0.5" o como `null`, la inferencia falla. Almacenes con stock fraccionario o `null` se marcan como sin stock. Forzar `bool` en la normalización.

**1.6 — `extractServiceImageUrl` y normalizadores recorren ~30 candidatos por llamada sin memoización.**
Cada frame en una grilla de 12 productos invoca esto N veces. Memoizar el resultado dentro del propio mapa al normalizar (`product['_resolvedImage']`).

**1.7 — Race condition en background refresh.**
`_refreshingListKeys` evita duplicados pero si entra un `forceRefresh: true` mientras el background refresh está en curso, se hacen 2 requests para la misma key.

**1.8 — Animación staggered `_CatalogReveal` sin cleanup explícito.**
Si pull-to-refresh re-renderiza la lista N veces, se acumulan TweenAnimationBuilders sin disponerse. Bajo impacto pero crece con el uso prolongado.

**1.9 — Hero animations en detalle de producto.**
Verificar — si no están, conviene agregarlas para una transición más fluida desde la grilla al detalle.

### Lo que está bien

- Doble caché (lista + producto individual) con TTL fresh + stale.
- Schema versioning (`_cacheSchemaVersion`) que invalida automáticamente al cambiar el shape.
- Fallback al endpoint público de Woo.
- Búsqueda local con scoring rico (exact, prefix, contains, Levenshtein, tokens, categorías).
- Pre-carga de imagen en `_precacheMainImage`.
- Pull-to-refresh en home y archive.
- Filtrado de productos sin precio, sin stock o ocultos.

---

## 2. CARRITO

### Estructura del estado

- `ShopCartItem` inmutable con `copyWith`. Campos para impuesto IVA 15/0, `pricesIncludeTax`, `globalMaxQuantity`, `warehouseStock`, `maxQuantity`. Bien diseñado.
- `ShopProvider` mantiene `List<ShopCartItem> _cartItems`, `ShopFulfillmentMethod _fulfillmentMethod`, `Map<String, dynamic>? _pickupLocation`.

### Hallazgos

**2.1 — ⚠️ El carrito NO se persiste entre sesiones.** (CRÍTICO)
Verificado por grep: cero referencias a `SharedPreferences`, `secure_storage`, `_persistCart`, `_loadCart` en `shop_provider.dart`. El carrito vive solo en RAM. Si el usuario cierra la app, vuelve y abre el carrito, está vacío. Para una barbería con productos premium (donde el ticket promedio puede ser alto y la decisión no es impulso), perder el carrito es fricción mayor.
**Sugerencia:** persistir `_cartItems`, `_fulfillmentMethod` y `_pickupLocation` en `SharedPreferences` con throttle de 1s tras cada notifyListeners.

**2.2 — Sin sincronización con servidor antes del checkout.**
El carrito local tiene `subtotal`, `taxTotal`, `_pickupLocation`. Si un producto cambia de precio o se desactiva en WooCommerce mientras está en el carrito, no se entera hasta que `createOrder` falla. Sugerencia: endpoint `POST /shop/cart/validate` que devuelva el delta antes del checkout.

**2.3 — Envío hardcoded en $3.50.**
`fixedShippingTotal = 3.50` (línea 143). Si Hábito cambia los shipping zones de Woo, la app sigue cobrando 3.50 al usuario pero Woo puede recalcular distinto en server-side. Riesgo de discrepancia.

**2.4 — `requiresCartReset` en `ShopCartActionResult` no se consume en UI.**
Cuando el usuario quiere agregar un producto con un fulfillment incompatible con el carrito existente (ej: tenía pickup en Sucursal A y agrega producto disponible solo en Sucursal B), el provider devuelve `requiresCartReset: true`. La UI en `cart_page.dart:112-124` solo muestra el mensaje, no abre un dialog "¿Reemplazar carrito?". Hoy la lógica del provider lo hace silenciosamente al cambiar contexto.

**2.5 — Doble fetch de almacenes en CartPage.** (ya marcado en auditorías previas)
`cart_page.dart:41-78` carga caché y luego dispara `forceRefresh: true` con `unawaited`. 2 requests por apertura del carrito.

**2.6 — Sin loading state en el botón "Continuar al pago".**
El botón debería deshabilitarse y mostrar spinner mientras `shop.isCreatingOrder == true`.

**2.7 — Sin debounce en operaciones de stepper.**
Si el usuario presiona "+" rápido, cada tap dispara `incrementQuantity → notifyListeners`, causando rebuilds. Throttle de 200 ms ayuda.

**2.8 — `decrementQuantity` elimina el ítem cuando llega a 0 sin confirmación.**
Línea 450-451. El usuario puede borrar un producto sin querer. Mejor: deshabilitar "−" en cantidad 1 y exigir tap explícito en "Quitar".

**2.9 — "Quitar" en `cart_page.dart:593-596` sin confirmación ni undo.**
Tap accidental = pérdida del producto. Sugerencia: `Dismissible` con confirmación + SnackBar con "Deshacer" 3 segundos.

**2.10 — Stepper de 34×34 px.**
Justo bajo el mínimo de Material (48 dp) y debajo del HIG iOS (44 pt). Aumentar a 44×44 con padding visible 36×36.

**2.11 — Cálculo de `subtotal/taxTotal/cartCount` recalcula con `fold` en cada acceso.**
Para 5-10 ítems es invisible; si crece se nota. Memoizar con un `_cachedTotals` invalidado en cada mutación.

### Lo que está bien

- Modelo inmutable y `copyWith` limpio.
- Lógica de IVA distingue 15%, 0%, no taxable y `pricesIncludeTax`.
- `_resolveMaxQuantityForProduct` respeta el stock de la sucursal seleccionada en pickup.
- Reset de contexto al vaciar el carrito.
- Snackbars con mensajes contextuales tras ajustes automáticos.
- `ShopCartActionResult` separa "éxito" / "ajuste" / "rechazo".

---

## 3. CHECKOUT

### Flujo

Página única con scroll (`checkout_page.dart`), 3 secciones lógicas: Resumen → Entrega → Pago. Sin indicador de progreso (es OK porque es una sola pantalla, pero conviene títulos visuales para cada sección).

### Datos fiscales Ecuador

**3.1 — ⚠️ Validación de cédula y RUC SOLO por longitud.**
Cédula = 10 dígitos, RUC = 13 dígitos (verificado en `checkout_page.dart:585-591, 1057-1058`). **No implementa el algoritmo de módulo 11** que valida la cédula ecuatoriana. Pasan documentos falsos como "1234567890" o "1111111111111".
**Sugerencia:** implementar el validador (multiplicar dígitos por coeficientes 2,1,2,1,2,1,2,1,2 para cédula, sumar, módulo 10). Hábito está facturando con datos potencialmente inválidos hoy.

**3.2 — Provincia/cantón hardcoded en `_ecuadorLocations` (línea 19-289).**
24 provincias completas. Bien para autonomía offline pero si el SRI cambia algún cantón, la app queda desfasada. Aceptable si se mantiene el archivo.

**3.3 — "Razón Social" no es un campo dedicado en checkout.**
Se toma de `auth.user.businessName` si `contactType == 'business'` (línea 375-386). Si el usuario no tiene business name en su perfil, no hay forma de capturarlo en el checkout — bloqueo silencioso.

### Métodos de pago

**3.4 — ⚠️ Solo transferencia bancaria. Sin pasarela real.**
`ShopPaymentMethod.bankTransfer` hardcoded como único método (línea 22-32 de `shop_payment_method.dart`). El código detecta el id `payphone` (línea 49) pero solo devuelve "Próximamente". **Esto significa que el ecommerce no es transaccional online**: el cliente compra, recibe instrucciones de transferencia, transfiere desde su banco y luego sube el comprobante en la pantalla de órdenes.
Esto es legítimo para Ecuador (donde la transferencia bancaria interbancaria es muy usada) pero hay que dejarlo claro en la UI:
- Mostrar **datos de la cuenta destino en pantalla** después de crear la orden (RUC, número de cuenta, banco, titular).
- Botón "Copiar número de cuenta".
- Botón "Abrir WhatsApp" para soporte.

**3.5 — Datos de transferencia no se muestran en checkout ni post-checkout.**
Solo aparece "Transferencia o depósito bancario" como label. El usuario tiene que adivinar dónde están los datos. Verificar si vienen en el email post-orden — si sí, indicarlo en pantalla; si no, agregar una hoja con los datos.

### Crear orden

**3.6 — ⚠️ Sin `idempotency_key`.**
Doble tap en "Confirmar pedido" en una conexión lenta = 2 órdenes idénticas. Para una operación con dinero es crítico. Generar un UUID en cliente y enviarlo como header `Idempotency-Key`; el plugin debe deduplicar.

**3.7 — Sin retries.**
Si el POST tiene timeout pero el servidor sí lo procesó, el cliente lanza error y el usuario reintenta → orden duplicada. Combina con 3.6 para resolverlo seguro.

**3.8 — El carrito se limpia DESPUÉS del éxito, correctamente.**
Verificado en `shop_provider.dart:631-637`: `_cartItems.clear()` ocurre después de `await HabitoShopApi.createOrder(...)` y de añadir la orden a `_orders`. Si el create falla, el catch (línea 638-640) preserva el carrito. **Bien implementado.** (Un agente reportó esto como bug pero la verificación lo descarta.)

**3.9 — Mensaje de error del servidor se muestra al usuario casi crudo.**
`_checkoutError = e.toString().replaceFirst('Exception: ', '')` (línea 639). Si el plugin devuelve "SQLSTATE[..]" o errores técnicos, van a la UI. Mapear errores comunes a mensajes amigables.

**3.10 — Forms usan validación manual en vez de `Form.validate()`.**
GlobalKey existe (`_formKey` línea 306) pero la validación pasa por `_missingCheckoutInfo()`. Mejor usar `validator:` en cada `TextFormField` para consistencia.

**3.11 — Validador de email muy laxo.**
"Contiene `@` y `.`" acepta `a@b`. Usar regex más estricta o `EmailValidator.validate()`.

**3.12 — Faltan `textInputAction: TextInputAction.next` en varios campos.**
El usuario tiene que tocar manualmente cada campo en lugar de usar el teclado para navegar.

**3.13 — Sin `autofillHints`.**
Password manager y autofill de Android/iOS no rellenan email, teléfono ni dirección. UX más fricción de lo necesario.

### Edge cases

**3.14 — Logout durante checkout.**
Si el token expira mientras el usuario llena el form, el `createOrder` falla con "Token requerido" pero los datos del form se preservan (controllers). Bien. Pero idealmente: detectar logout y avisar antes de que llene todo.

**3.15 — Cambio de fulfillment con stock insuficiente.**
`updateCartContext` recalcula límites y ajusta cantidades. Bueno. Verificar que el SnackBar realmente comunique cuántos items se ajustaron.

---

## 4. ÓRDENES Y COMPROBANTE

### Listing

- Endpoint `GET /shop/orders?limit=20&page=N&status=...`. Paginación manual ("Cargar más"), no infinite scroll.
- 4 filtros: Todos / Activos / Completados / Cancelados+Reembolsados.
- Pull-to-refresh y deep link desde push (`initialOrderId`, `openFromPush`) con scroll automático y highlight 5 s. Buena UX.
- Estados normalizados a español ("pending → Pendiente", "on-hold → En espera", "processing → Procesando", "completed → Completada", etc.).

### Comprobante de pago

**4.1 — Subida desde la pantalla de órdenes (no desde checkout).**
Flujo: usuario crea la orden → recibe instrucciones de transferencia (¿por email?) → vuelve a la app → entra a la orden pendiente → "Subir comprobante" → ImagePicker abre galería → comprime a 1800px / quality 82 → POST multipart al backend.

**4.2 — ⚠️ Sin validación de tipo de archivo ni tamaño.**
`habito_shop_api.dart:752-771`: el endpoint acepta cualquier archivo del image picker. Si el usuario sube un PDF malformado o una imagen de 50 MB, el servidor lo recibe. Validar `[.jpg, .jpeg, .png]` y máx ~5 MB en cliente antes de subir.

**4.3 — Solo 1 comprobante por orden.**
Si Hábito rechaza el comprobante (ej: monto distinto), el cliente debe re-subir. No hay historial de comprobantes ni estado intermedio "rechazado, vuelve a subir". Considerar agregar un campo de estado del comprobante con motivo.

**4.4 — Sin tracking del envío.**
Para pedidos con `delivery`, no hay número de guía ni link a courier. La orden muestra estado "En espera" → "Procesando" → "Completada" sin más detalle. Si Hábito usa Servientrega/Tramaco, agregar `tracking_number` y `tracking_url` en el payload del backend.

### Detalle de orden

- Bien estructurado: número, fecha, items (3 visibles + "+N más"), totales con IVA desglosado, método de pago, estado del comprobante, sucursal asignada, despacho.
- Botón "Subir comprobante" condicional (solo si pending + bacs + sin comprobante).
- Highlight automático de la orden cuando se llega desde push.

---

## Top 12 acciones priorizadas

| # | Acción | Severidad |
|---|--------|-----------|
| 1 | Persistir el carrito (`_cartItems` + fulfillment + pickup) en `SharedPreferences` | **Crítico** |
| 2 | Implementar validación real de cédula (módulo 11) y RUC ecuatoriano | **Crítico** |
| 3 | Agregar `Idempotency-Key` + retry exponencial a `createOrder` | **Crítico** |
| 4 | Mostrar datos bancarios + botón "Copiar cuenta" + WhatsApp en sheet post-orden | **Crítico** |
| 5 | Validar tipo y tamaño del comprobante antes de subir | Alto |
| 6 | Endpoint de validación de carrito antes de checkout (precios, stock, productos activos) | Alto |
| 7 | Loading state en botón "Continuar al pago" del carrito | Alto |
| 8 | Email validator estricto + autofillHints + textInputAction en todos los campos | Alto |
| 9 | Mapear errores técnicos del backend a mensajes amigables (`_friendlyCheckoutError`) | Medio |
| 10 | Memoizar `extractServiceImageUrl` y precios en getters de `ShopCartItem` | Medio |
| 11 | Aumentar steppers a 44×44 px y agregar `Dismissible` con "Deshacer" en remove | Medio |
| 12 | Tracking number + link courier para órdenes con delivery | Medio |

---

## Diagrama del flujo

```
Productos
  ├── ShopPage (home, productos destacados)
  ├── ProductsArchivePage (grilla + búsqueda + filtros)
  └── ProductDetailPage (detalle + selector almacén + add to cart)
         │
         ▼
Carrito (ShopProvider, en RAM, NO persistido)
  ├── CartPage (items + fulfillment + sucursal pickup)
  └── CTA "Continuar al pago"
         │
         ▼
Checkout (CheckoutPage)
  ├── Resumen del pedido
  ├── Datos de entrega (provincia, cantón, dirección)
  ├── Datos fiscales (cédula/RUC)
  ├── Método de pago (SOLO transferencia bancaria hoy)
  └── Confirmar pedido → POST /shop/orders → limpia carrito
         │
         ▼
Órdenes (OrdersPage)
  ├── Listado con filtros y pull-to-refresh
  ├── Deep link desde push (highlight)
  └── Subir comprobante (si pending + bacs + sin comprobante)
```

## Lo que está bien (transversal)

- Arquitectura modular API → Provider → Page con responsabilidades claras.
- IVA desglosado correctamente con soporte para `pricesIncludeTax`.
- Caché en disco con schema versioning.
- Fallback al endpoint público de WooCommerce ante caída del custom.
- Pull-to-refresh consistente en shop, archive, orders.
- Highlight de orden recién creada al llegar desde push.
- Compresión de comprobante (1800px, quality 82) razonable.
- Manejo de logout durante operaciones críticas (sin crash).
- Localización completa al español.
- Reset correcto del contexto del carrito al vaciarse.
- ShopCartActionResult separa éxito/ajuste/rechazo de forma clara.
