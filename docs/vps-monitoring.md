# Monitoreo VPS Habito

Objetivo: detectar por que se congela al mismo tiempo la web, UltimatePOS y la app. Esta guia no cambia el flujo de citas ni modifica Amelia; solo registra datos para diagnosticar.

## 1. Monitor del VPS

Copiar al VPS:

```bash
sudo mkdir -p /opt/habito-monitor
sudo cp tools/vps-snapshot-monitor.sh /opt/habito-monitor/vps-snapshot-monitor.sh
sudo chmod +x /opt/habito-monitor/vps-snapshot-monitor.sh
```

Ejecutar manualmente durante horas de uso:

```bash
sudo HABITO_MONITOR_LOG_DIR=/var/log/habito-vps-monitor \
  WP_PATH=/var/www/habitobarberia.com \
  /opt/habito-monitor/vps-snapshot-monitor.sh 5
```

Si no conoces el `WP_PATH`, omite esa variable. El script seguira registrando CPU, RAM, disco, procesos, MySQL y logs recientes.

Logs generados:

```bash
sudo ls -lh /var/log/habito-vps-monitor/
sudo tail -n 250 /var/log/habito-vps-monitor/vps-monitor-$(date +%F).log
```

Cuando ocurra el congelamiento, anotar la hora exacta y revisar 1-2 minutos antes y despues.

## 2. Monitor de WordPress para peticiones lentas

Copiar como must-use plugin:

```bash
sudo mkdir -p /var/www/habitobarberia.com/wp-content/mu-plugins
sudo cp tools/wp-habito-request-monitor.php \
  /var/www/habitobarberia.com/wp-content/mu-plugins/wp-habito-request-monitor.php
```

Opcional en `wp-config.php`:

```php
define( 'HABITO_MONITOR_ENABLED', true );
define( 'HABITO_MONITOR_SLOW_SECONDS', 3.0 );
define( 'HABITO_MONITOR_CRON_SECONDS', 1.0 );
```

Registra solo:

- Peticiones WordPress que duran 3 segundos o mas.
- WP-Cron que dura 1 segundo o mas.

No registra datos sensibles de querystring; solo guarda las claves de parametros.

Logs generados:

```bash
sudo ls -lh /var/www/habitobarberia.com/wp-content/uploads/habito-monitor/
sudo tail -n 100 /var/www/habitobarberia.com/wp-content/uploads/habito-monitor/slow-requests-$(date -u +%F).log
```

## 3. WP-Cron recomendado

Si se confirma que el congelamiento coincide con cron, mover WP-Cron fuera de las visitas normales.

En `wp-config.php`:

```php
define( 'DISABLE_WP_CRON', true );
```

Cron real del sistema:

```bash
sudo crontab -e
```

Agregar:

```cron
*/5 * * * * curl -fsS --max-time 60 https://habitobarberia.com/wp-cron.php?doing_wp_cron >/dev/null 2>&1
```

Esto evita que una visita de cliente ejecute trabajos pesados de WordPress.

## 4. Que buscar cuando vuelva a pasar

En el log del VPS:

- `loadavg` mayor que los cores del servidor.
- `mysqld` o `mariadbd` arriba en CPU.
- `php-fpm`, `apache2` o `nginx` consumiendo CPU.
- `wa` alto en `vmstat` o `iostat`, indica disco lento.
- Mensajes `OOM`, `killed`, `timeout`, `slow`.

En el log de WordPress:

- `is_cron: true` cerca de la hora del congelamiento.
- Rutas lentas como `/wp-json/habito/v1/availability`, `/wp-json/habito/v1/my-bookings`, `admin-ajax.php`, WooCommerce o Amelia.
- `db_queries` muy alto.
- `memory_peak_mb` muy alto.

## 5. Sospechosos actuales por codigo

- Recordatorios push cada 5 minutos en el plugin: `Habito_FCM::process_appointment_reminders`.
- Automatizaciones push horarias: `Habito_Push_Automations::run_now`.
- Consultas paginadas a Amelia para appointments.
- Consultas WooCommerce con `wc_get_orders`.
- `WP_DEBUG_LOG` activo en produccion, si esta escribiendo demasiadas lineas.

Con los logs podremos decidir si conviene bajar frecuencia de crons, agregar indices SQL, limitar paginas consultadas o mover trabajos a cron real.
