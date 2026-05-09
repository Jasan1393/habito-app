# Contrato de operaciones criticas Habito

## Idempotencia

La app debe enviar la misma llave en todos los reintentos de una misma operacion critica:

- `Idempotency-Key`
- `X-Idempotency-Key`
- `X-Habito-Idempotency-Key`

El backend debe guardar una respuesta por llave, usuario y endpoint durante una ventana razonable, por ejemplo 24 horas. Si llega la misma llave otra vez, debe devolver la respuesta original sin crear una segunda reserva, pedido, cancelacion, reagendamiento o comprobante.

Operaciones protegidas desde la app:

- Crear reserva: `POST /bookings`
- Cancelar reserva: `POST /bookings/{booking_id}/cancel`
- Reagendar cita: `POST /appointments/{appointment_id}/reschedule`
- Crear pedido: `POST /shop/orders`
- Subir comprobante: `POST /shop/orders/{order_id}/payment-proof`

## Reintentos

La app reintenta con backoff exponencial ante errores transitorios:

- Timeout o fallo de conexion.
- HTTP `408`, `425`, `429`, `500`, `502`, `503`, `504`.

No debe reintentar errores funcionales como validacion, permisos, saldo insuficiente o datos faltantes.

## Canje de puntos

El flujo correcto siempre empieza consultando `/points/quote`.

La app envia:

- `redeem_points`: numero de puntos a consumir.
- `redeem_amount`: valor monetario del descuento aprobado por el quote.

`redeem_amount` no es el total de la factura. Es unicamente el monto cubierto por puntos en USD. El backend/myCRED conserva la verdad del saldo y debe validar de nuevo antes de descontar.

Ejemplo:

```json
{
  "redeem_points": 600,
  "redeem_amount": 6.00
}
```
