# Contrato backend: validar carrito antes del checkout

La app llama este endpoint antes de crear una orden:

```http
POST /shop/cart/validate
Authorization: Bearer {token}
Content-Type: application/json
Idempotency-Key: habito-cart-validate-...
```

## Payload enviado por la app

```json
{
  "line_items": [
    { "product_id": 123, "quantity": 2, "unit_price": 5.0 }
  ],
  "fulfillment_method": "delivery",
  "pickup_location_id": 0,
  "pickup_location_name": "",
  "pickup_warehouse_external_id": "",
  "app_totals": {
    "subtotal": "10.00",
    "tax_total": "0.00",
    "shipping_total": "3.50",
    "total": "13.50",
    "prices_include_tax": true
  }
}
```

## Respuesta esperada

```json
{
  "success": true,
  "data": {
    "can_checkout": true,
    "cart_changed": true,
    "message": "Actualizamos tu carrito con la disponibilidad actual.",
    "items": [
      {
        "product_id": 123,
        "name": "Shampoo",
        "requested_quantity": 2,
        "final_quantity": 1,
        "available_quantity": 1,
        "old_unit_price": 5.0,
        "new_unit_price": 5.5,
        "in_stock": true,
        "removed": false,
        "severity": "warning",
        "message": "Solo queda 1 unidad disponible."
      }
    ]
  }
}
```

Si el endpoint responde `404`, la app no bloquea el checkout para mantener compatibilidad con bridges antiguos. Cuando el bridge implemente esta ruta, la app aplicara automaticamente cantidades/precios actualizados antes de crear la orden.
