# Politica de headers de la app

## AppTopHeader unificado

Las pantallas operativas principales deben usar `AppTopHeader` para mantener una experiencia consistente de busqueda, notificaciones y carrito.

Pantallas migradas:

- `MyAppointmentsPage`
- `OrdersPage`
- `AppointmentDetailPage`

## Excepcion intencional: ProfilePage

`ProfilePage` conserva su cabecera oscura personalizada porque funciona como pantalla de identidad/cuenta y usa un tratamiento visual distinto al flujo comercial. No debe migrarse a `AppTopHeader` mientras mantenga ese rol de perfil principal.
