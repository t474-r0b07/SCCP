# DTEX - Continuidad 2026-05-07

## Regla vigente

- SCCP funcional no debe retroceder.
- Cambios de hoy quedaron aislados a DTEX.
- No se tocaron radio, partes sorpresa, analitica comandante ni telemetria SCCP.

## Avance aplicado

- Ruta publica PWA temporal:
  - `/dtex/custodio`
  - `/dtex/custodio?otp=123456`
- Vista custodio:
  - valida OTP con `dtex_validar_otp`,
  - muestra mision asignada,
  - permite marcar `REGISTRO_REALIZADO`, `EN_RUTA`, `EN_DESTINO`, `RETORNANDO` y `EMERGENCIA`,
  - lee ubicacion del navegador,
  - envia GPS periodico a `dtex_tracking_gps` cada 20 segundos si la mision esta activa.
- Panel supervisor DTEX:
  - muestra QR y enlace temporal del custodio,
  - permite copiar enlace,
  - selecciona automaticamente la mision recien creada.

## Validacion local

- `flutter analyze`: OK.
- `flutter test`: OK.
- Servidor local:
  - `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`
  - URL local: `http://127.0.0.1:8080`
- Verificacion HTTP:
  - `GET http://127.0.0.1:8080` -> `200 text/html`
  - `GET http://127.0.0.1:8080/dtex/custodio?otp=123456` -> `200 text/html`

## Pendientes inmediatos

1. Aplicar/verificar `docs/supabase_dtex_schema_alignment.sql`.
2. Confirmar contrato del RPC `dtex_validar_otp`:
   - debe retornar `id_mision`, o
   - un objeto `mision`/`data` con `id_mision`.
3. Confirmar RPC `dtex_cambiar_estado` para acceso temporal.
4. Confirmar RLS/permisos para insert en `dtex_tracking_gps`.
5. Probar con una mision DTEX real y OTP generado desde supervisor.

