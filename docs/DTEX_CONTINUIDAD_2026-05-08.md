# DTEX - Continuidad 2026-05-08

## Cambio de plan - app Android custodio

La PWA/webapp queda como referencia secundaria. Para control policial confiable
se inicio app Android dedicada de custodio.

### Archivos nuevos

- `lib/main_custodio.dart`
- `lib/presentation/views/dtex_custodio_android_app.dart`
- `lib/core/services/dtex_android_tracking_service.dart`

### Comando de build

```bash
flutter build apk --debug -t lib/main_custodio.dart
```

APK generado:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### Flujo app Android

1. Custodio abre app DTEX.
2. Ingresa:
   - nombre,
   - codigo de seguridad de mision.
3. RPC `dtex_validar_acceso_custodio` valida mision activa.
4. App muestra:
   - custodio/grado,
   - interno asignado,
   - destino,
   - ETA,
   - mapa con ubicacion actual, destino, geocerca y traza directa,
   - radio operativa.
5. Custodio presiona `Empezar diligencia`.
6. App activa:
   - permisos ubicacion/notificacion,
   - foreground notification,
   - wake lock,
   - tracking GPS periodico,
   - bateria,
   - estado de red.
7. App reporta automaticamente:
   - llegada a destino por geocerca,
   - retorno/en ruta al detectar movimiento fuera del destino,
   - desvios.

### Validacion local

- `flutter analyze`: OK.
- `flutter test`: OK.
- `flutter build apk --debug -t lib/main_custodio.dart`: OK.

### Validacion en Android fisico

- Telefono detectado:
  - `Infinix X657B`
  - Android 10 API 29
  - ADB id: `0686837191104688`
- Comando ejecutado:

```bash
flutter run -d 0686837191104688 -t lib/main_custodio.dart
```

- Resultado:
  - APK compilo e instalo en el telefono.
  - App inicio en el telefono.
  - Supabase inicializo OK.
  - Pantalla de login DTEX Custodio visible.
- Bloqueo actual:
  - no hay misiones DTEX activas visibles para prueba.
  - consulta anon a `dtex_misiones` devolvio `[]`.
  - falta crear mision real o datos de prueba con `custodio_nombre` + `codigo_otp`.

### Pendientes para campo

1. Aplicar en Supabase:
   - `docs/supabase_dtex_schema_alignment.sql`
   - `docs/supabase_dtex_custodio_public_rpc.sql`
2. Para desbloquear prueba Android inmediata, ejecutar opcionalmente:
   - `docs/supabase_dtex_seed_mision_prueba_android.sql`
   - credenciales:
     - nombre: `CUSTODIO PRUEBA DTEX`
     - codigo: `123456`
   - verificacion:
     - `select public.dtex_validar_acceso_custodio('CUSTODIO PRUEBA DTEX', '123456');`
3. Crear mision DTEX activa de prueba desde supervisor:
   - custodio_nombre exacto,
   - custodio_grado,
   - custodio_codigo,
   - reo_nombre,
   - destino con latitud/longitud,
   - codigo_otp/codigo de seguridad.
4. Probar login real en Android por:
   - nombre del custodio,
   - codigo de seguridad.
5. En Android, otorgar:
   - ubicacion precisa,
   - permitir todo el tiempo si el sistema lo ofrece,
   - notificaciones,
   - excluir de optimizacion de bateria si se requiere.
6. Presionar `Empezar diligencia`.
7. Probar ruta real, tracking y geocerca.
8. Revisar en Supabase:
   - inserts en `dtex_tracking_gps`,
   - estados en `dtex_misiones`,
   - alertas en `dtex_alertas`.

### Ajuste aplicado al retomar

- Se agrego `docs/supabase_dtex_seed_mision_prueba_android.sql` para crear/reactivar una mision de prueba Android con custodio `CUSTODIO PRUEBA DTEX` y codigo `123456`.
- Se agrego enfriamiento de 5 minutos para alertas automaticas `DESVIO` en `DtexAndroidTrackingService`, evitando ruido por cada ciclo GPS mientras el desvio siga activo.
- Se endurecio el inicio de diligencia Android: primero valida permisos operativos, luego arranca el stream GPS y recien despues sincroniza estado `EN_RUTA` con DTEX. El boton queda bloqueado mientras inicia para evitar doble toque.
- Si Android muestra `PostgrestException: could not find the function dtex_validar_acceso_custodio`, ejecutar nuevamente `docs/supabase_dtex_custodio_public_rpc.sql` en el proyecto Supabase correcto y recargar cache con `notify pgrst, 'reload schema';`.
- Si Supabase SQL Editor muestra `cannot change name of input parameter`, el script RPC ya incluye `drop function if exists ...` por firma antes de recrear las funciones; volver a ejecutar el archivo completo actualizado.
- Si el seed falla por `dtex_misiones_tipo_diligencia_check`, usar `tipo_diligencia = 'JUDICIAL'`; el valor de prueba anterior `PRUEBA_ANDROID` no pertenece al CHECK real.
- Si el seed falla por `dtex_misiones_supervisor_email_fkey`, el script actualizado toma automaticamente un admin activo real desde `allowed_admins` con rol `SUDO`, `SUPERVISOR_DTEX`, `SUPERVISOR` o compatible.

---

## Prioridad vigente

- Primero dejar funcional la webapp publica/movil del custodio.
- Recien despues vincular la webapp monitor.
- SCCP operativo no debe retroceder.

## Avance aplicado

- Webapp custodio mantiene ruta:
  - `/dtex/custodio`
  - `/dtex/custodio?otp=123456`
- Acciones operativas visibles para custodio:
  - registro realizado,
  - en ruta,
  - en destino,
  - retorno,
  - emergencia,
  - mision terminada.
- Tracking GPS del custodio ahora llama RPC:
  - `dtex_reportar_tracking_gps`
- OTP puede devolver payload completo:
  - `mision`
  - `destino`
- Si RLS bloquea relectura directa de la mision desde la ruta publica, la UI actualiza el estado localmente para no romper el flujo del custodio.

## SQL nuevo

- Ejecutar en Supabase SQL editor, en este orden:
  1. `docs/supabase_dtex_schema_alignment.sql`
  2. `docs/supabase_dtex_custodio_public_rpc.sql`

## RPCs requeridos

- `dtex_validar_otp(text)`
- `dtex_cambiar_estado(uuid, text, double precision, double precision)`
- `dtex_reportar_tracking_gps(uuid, double precision, double precision, double precision, double precision, double precision, double precision, integer, boolean)`
- `dtex_insertar_alerta(uuid, text, text, text, double precision, double precision)`

## Validacion local

- `dart format`: OK.
- `flutter analyze`: OK.
- `flutter test`: OK.
- Servidor local:
  - `http://127.0.0.1:8080`
- Verificacion HTTP:
  - `GET /` -> `200 text/html`
  - `GET /dtex/custodio?otp=123456` -> `200 text/html`

## Proxima prueba real

1. Aplicar SQL en Supabase.
2. Entrar como supervisor DTEX.
3. Crear una mision con destino con coordenadas validas.
4. Copiar OTP o escanear QR.
5. Abrir en movil:
   - `http://IP-DEL-EQUIPO:8080/dtex/custodio?otp=XXXXXX` en LAN local, o
   - URL desplegada si ya esta en hosting.
6. Permitir ubicacion del navegador.
7. Probar secuencia:
   - registro realizado,
   - en ruta,
   - GPS enviado,
   - en destino,
   - retorno,
   - emergencia si corresponde,
   - mision terminada.
