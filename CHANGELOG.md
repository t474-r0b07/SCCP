# Changelog

## 2026-05-09

### DTEX - Rutas, destinos Tarija y prueba Android
- Se agrego seed idempotente de destinos operativos de Tarija:
  - `docs/supabase_dtex_seed_destinos_tarija.sql`
- Se corrigio la mision de prueba Android para evitar coordenadas legacy de La Paz:
  - el destino fallback `DESTINO PRUEBA DTEX ANDROID` ahora apunta a Palacio de Justicia, Tarija,
  - la mision de prueba prioriza `Palacio de Justicia` si existe en `dtex_destinos`.
- Se mejoro la app Android custodio:
  - mapa con rotacion bloqueada,
  - ruta por calles via OSRM cuando hay red,
  - distancia y ETA basadas en ruta por calles,
  - linea recta solo como respaldo visual si no hay ruta.
- Validacion en movil:
  - APK generado con `flutter build apk --debug -t lib/main_custodio.dart`,
  - APK instalado y abierto en Infinix X657B por ADB.

### DTEX - Seguridad, alertas e inconsistencias
- Se agregaron alertas automaticas durante mision activa en Android:
  - `DESVIO_RUTA`,
  - `GPS_PRECISION_BAJA`,
  - `UBICACION_APAGADA`,
  - `BATERIA_CRITICA`,
  - `SIN_CONEXION`,
  - `PARADA_NO_AUTORIZADA`,
  - `APP_SUSPENDIDA`.
- Se agrego enfriamiento por tipo de alerta para evitar inundar Supabase con eventos repetidos.
- Se agregan notificaciones locales al custodio cuando se registra una alerta operativa.
- Se agregaron labels legibles para nuevos tipos de alerta DTEX en `DtexAlerta`.
- Se agrego escalamiento SQL de alertas a inconsistencias administrativas:
  - `docs/supabase_dtex_alertas_inconsistencias.sql`
  - vista `public.v_dtex_alertas_inconsistencia_candidatas`,
  - funcion `public.fn_dtex_alertas_registrar_inconsistencias(p_ref, p_min_age_minutes)`.
- La funcion crea inconsistencias con `id_reporte = DTEX_ALERT_<id_alerta>` para evitar duplicados.
- Validacion:
  - `flutter analyze` OK en archivos modificados,
  - APK debug generado,
  - APK instalado y abierto en Infinix X657B.

### DTEX - Radio operativa Android custodio
- Se reemplazo la tarjeta inline de radio por acceso a pantalla dedicada.
- La pantalla nueva incluye:
  - pestaña de mensajes con historial por custodio,
  - envio de mensajes al supervisor por `radio_mensajes`,
  - marcado automatico como `LEIDO` para mensajes entrantes vistos por el custodio,
  - pestaña de reporte de situacion,
  - captura de foto con camara,
  - subida de evidencia a Supabase Storage,
  - envio de reporte `PARTE_NOVEDAD` con descripcion, ubicacion y enlace de foto.
- Se agrego dependencia:
  - `image_picker`
- Se agrego permiso Android:
  - `android.permission.CAMERA`
- Se agrego SQL de soporte para bucket de evidencias:
  - `docs/supabase_dtex_reportes_storage.sql`
  - bucket `dtex-reportes`
- Validacion:
  - `flutter pub get` OK,
  - `dart format` OK,
  - `flutter analyze` OK en archivos modificados.

### DTEX - App Android supervisor MVP
- Se agrego entrypoint Android dedicado para supervisor DTEX:
  - `lib/main_dtex_supervisor.dart`
  - `lib/presentation/views/dtex_supervisor_android_app.dart`
- Funcionalidad MVP:
  - login real con Supabase/AuthController,
  - validacion de acceso DTEX por `allowed_admins`,
  - dashboard con misiones activas, alertas, destinos y extensiones,
  - pestaña para asignar diligencias y generar OTP,
  - mapa de monitoreo con tracking de mision seleccionada,
  - panel de alertas con resolucion,
  - radio operativa supervisor-custodio.
- Validacion:
  - `dart format` OK,
  - `flutter analyze lib/main_dtex_supervisor.dart lib/presentation/views/dtex_supervisor_android_app.dart` OK,
  - `flutter build apk --debug -t lib/main_dtex_supervisor.dart` OK,
  - APK instalado y abierto en Infinix X657B.
- Nota tecnica:
  - MVP usa el mismo `applicationId` que la app custodio; para instalarlas juntas se requiere separar flavors/package ids (`custodio` y `supervisor`).

## 2026-05-08

### DTEX - Semilla de prueba Android custodio
- Se agrego script SQL idempotente para desbloquear la prueba real de login en Android:
  - `docs/supabase_dtex_seed_mision_prueba_android.sql`
- El script crea o reactiva:
  - destino `DESTINO PRUEBA DTEX ANDROID`,
  - mision activa `PENDIENTE`,
  - custodio `CUSTODIO PRUEBA DTEX`,
  - codigo de seguridad `123456`.
- Orden sugerido de ejecucion en Supabase:
  1. `docs/supabase_dtex_schema_alignment.sql`
  2. `docs/supabase_dtex_custodio_public_rpc.sql`
  3. `docs/supabase_dtex_seed_mision_prueba_android.sql`
- Verificacion SQL incluida:
  - `select public.dtex_validar_acceso_custodio('CUSTODIO PRUEBA DTEX', '123456');`
- Validacion local:
  - `flutter analyze` OK.

### DTEX - Tracking Android anti-ruido
- Se agrego ventana de enfriamiento de 5 minutos para alertas automaticas `DESVIO` en `DtexAndroidTrackingService`.
- Objetivo: evitar multiples inserts de alerta por cada ciclo GPS mientras el custodio permanece fuera del trayecto esperado.
- Validacion:
  - `dart format lib/core/services/dtex_android_tracking_service.dart` OK.
  - `flutter analyze` OK.
  - `flutter test` OK.
  - `flutter build apk --debug -t lib/main_custodio.dart` OK.

### DTEX - Cambio de plan: app Android custodio
- Se descarto PWA como solucion final para custodio por limitaciones de tracking confiable en segundo plano.
- Se inicio app Android dedicada para custodio dentro del mismo proyecto Flutter:
  - entrada nueva `lib/main_custodio.dart`,
  - app movil vertical `lib/presentation/views/dtex_custodio_android_app.dart`,
  - servicio nativo de tracking `lib/core/services/dtex_android_tracking_service.dart`.
- Funcionalidad inicial:
  - login custodio con nombre + codigo de seguridad,
  - dashboard movil con custodio/grado/interno,
  - tarjeta destino con ETA,
  - mapa con ubicacion actual, destino, geocerca y traza directa,
  - boton `Empezar diligencia`,
  - tracking con foreground notification,
  - reporte GPS periodico con bateria y estado de red,
  - llegada automatica a destino por geocerca,
  - deteccion de movimiento de salida/retorno,
  - alerta automatica por desvio,
  - emergencia manual,
  - cierre/desconexion,
  - tarjeta inicial de radio operativa SCCP para enviar mensaje al supervisor.
- Dependencias Android agregadas:
  - `geolocator`,
  - `permission_handler`,
  - `battery_plus`,
  - `connectivity_plus`,
  - `wakelock_plus`,
  - `flutter_local_notifications`.
- Android:
  - permisos de ubicacion, background location, foreground service, notificaciones, red y wake lock en `AndroidManifest.xml`,
  - habilitado core library desugaring para notificaciones.
- Supabase:
  - agregado RPC `dtex_validar_acceso_custodio(p_nombre, p_codigo)` en `docs/supabase_dtex_custodio_public_rpc.sql`.
- Validacion:
  - `flutter analyze` OK.
  - `flutter test` OK.
  - `flutter build apk --debug -t lib/main_custodio.dart` OK.
  - APK generado: `build/app/outputs/flutter-apk/app-debug.apk`.
  - Prueba en telefono fisico OK hasta login:
    - dispositivo: `Infinix X657B`,
    - Android 10 API 29,
    - device id ADB: `0686837191104688`,
    - comando: `flutter run -d 0686837191104688 -t lib/main_custodio.dart`,
    - Supabase inicializo OK en el dispositivo,
    - app abre login DTEX Custodio.
  - Consulta anon a misiones activas devolvio `[]`; no hay datos de prueba para login real.
- Pendiente backend/campo:
  - crear/aplicar datos reales de prueba DTEX,
  - crear una mision activa con `custodio_nombre` y `codigo_otp`,
  - aplicar SQL `docs/supabase_dtex_custodio_public_rpc.sql`,
  - probar login real por nombre + codigo en Android,
  - probar ubicacion real y permisos en campo,
  - endurecer watchdog backend para silencio/desconexion manual/datos apagados/mock location.

### DTEX - Webapp custodio prioridad funcional
- Se confirmo continuidad operativa: primero cerrar webapp movil/publica del custodio, luego vincular webapp monitor.
- Se intento introspeccion completa de Supabase con anon key:
  - metadata REST requiere `service_role`,
  - consulta a `dtex_misiones` responde, pero no expone estructura completa desde esta app.
- Se agrego SQL backend para custodio publico:
  - `docs/supabase_dtex_custodio_public_rpc.sql`
  - RPC `dtex_validar_otp`,
  - RPC `dtex_cambiar_estado`,
  - RPC `dtex_reportar_tracking_gps`,
  - RPC `dtex_insertar_alerta`,
  - grants `anon/authenticated` para ejecutar RPCs sin abrir inserts directos desde la webapp.
- Se ajusto la webapp custodio:
  - acciones visibles: registro realizado, en ruta, en destino, retorno, emergencia y mision terminada,
  - el tracking GPS ahora usa RPC `dtex_reportar_tracking_gps`,
  - la respuesta OTP puede traer `destino` junto con `mision`,
  - fallback local de estado si RLS bloquea relectura directa de `dtex_misiones`.
- Archivos clave:
  - `lib/presentation/views/dtex_custodio_view.dart`
  - `lib/data/repositories/dtex_repository.dart`
  - `lib/data/models/dtex_mision_model.dart`
  - `docs/supabase_dtex_custodio_public_rpc.sql`
- Validacion:
  - `dart format` OK.
  - `flutter analyze` OK.
  - `flutter test` OK.
  - servidor local levantado en `http://127.0.0.1:8080`.
  - `GET /` y `GET /dtex/custodio?otp=123456` devuelven `200 text/html`.
- Pendiente inmediato para prueba real:
  - ejecutar primero `docs/supabase_dtex_schema_alignment.sql`,
  - ejecutar despues `docs/supabase_dtex_custodio_public_rpc.sql`,
  - crear mision DTEX desde supervisor,
  - abrir `/dtex/custodio?otp=XXXXXX` en movil y permitir ubicacion.

## 2026-05-07

### DTEX - Ruta custodio temporal QR/OTP
- Se agrego ruta publica aislada:
  - `/dtex/custodio`
  - acepta OTP por query string: `/dtex/custodio?otp=123456`
- Se agrego vista PWA liviana para custodio:
  - validacion OTP via RPC `dtex_validar_otp`,
  - carga de mision asignada,
  - acciones: registro realizado, en ruta, en destino, retorno y emergencia,
  - lectura de ubicacion web con permiso del navegador,
  - envio periodico de GPS a `dtex_tracking_gps` durante mision activa.
- Se agrego QR/link en panel DTEX supervisor:
  - muestra QR para el enlace temporal del custodio,
  - permite copiar el enlace,
  - al crear mision se selecciona automaticamente la nueva mision para ver OTP/QR.
- Se agrego dependencia:
  - `qr_flutter`
- Archivos clave:
  - `lib/presentation/views/dtex_custodio_view.dart`
  - `lib/core/services/dtex_geo_location*.dart`
  - `lib/data/repositories/dtex_repository.dart`
  - `lib/presentation/views/dtex_view.dart`
  - `lib/main.dart`
- Validacion:
  - `flutter analyze` OK.
  - `flutter test` OK.
  - servidor local levantado en `http://127.0.0.1:8080`.
  - `GET /` y `GET /dtex/custodio?otp=123456` devuelven `200 text/html`.
- Pendiente Supabase:
  - confirmar/aplicar `docs/supabase_dtex_schema_alignment.sql`,
  - confirmar que `dtex_validar_otp` retorne `id_mision` o payload de mision,
  - confirmar permisos/RLS para `dtex_cambiar_estado` y `dtex_tracking_gps` desde acceso temporal.

## 2026-05-06

### Cierre de jornada DTEX - continuidad
- Se dejo continuidad formal en:
  - `docs/DTEX_CONTINUIDAD_2026-05-06.md`
- Servidor local detenido al cierre.
- Punto pendiente detectado durante prueba:
  - el usuario anterior no funciono para login.
  - manana revisar Supabase `auth.users` + `allowed_admins`, `activo=true` y `nivel_acceso` (`SUDO`, `SUPERVISOR`, `SUPERVISOR_DTEX`).
- Proximo bloque:
  - validar/aplicar `docs/supabase_dtex_schema_alignment.sql`,
  - probar login DTEX,
  - probar creacion de mision,
  - iniciar ruta aislada `/dtex/custodio` con OTP/QR/PWA temporal.

### DTEX - Alineacion roles, estados y cierre seguro
- Regla operativa aplicada: SCCP se mantiene estable; cambios enfocados en DTEX y entradas controladas.
- Roles admin:
  - `AllowedAdmin` ahora reconoce roles reales `SUDO`, `SUPERVISOR`, `SUPERVISOR_DTEX`.
  - Se conserva compatibilidad con roles existentes `DIRECTOR`, `ADMIN`, `ADMINISTRADOR`, `COMANDANTE`.
  - `SUPERVISOR_DTEX` obtiene acceso DTEX sin recibir acciones SCCP completas.
  - Comandante/SUDO tiene entrada DTEX desde header comandante.
- DTEX estados:
  - Agregadas constantes en `DtexMision` para flujo operativo:
    `PENDIENTE`, `REGISTRO_REALIZADO`, `EN_RUTA`, `EN_DESTINO`, `RETORNANDO`, `CERRADA`, `EMERGENCIA`, `CANCELADA`.
  - Labels UI alineados al lenguaje deseado:
    mision abierta, registro realizado, en ruta, en destino, retorno, completada.
  - Filtros DTEX ahora usan lista centralizada de estados.
- Cierre de mision:
  - `conducta_final` cambio de texto libre a selector compatible con CHECK Supabase:
    `SIN_INCIDENCIAS`, `CON_OBSERVACIONES`, `CON_INCIDENCIAS_GRAVES`.
  - Repositorio valida conducta antes de enviar update.
- Alertas DTEX:
  - Labels agregados para `DESVIO`, `DETENIDO`, `UBICACION_APAGADA`, `INCONSISTENCIA`.
- Documentacion/scripts:
  - `docs/supabase_dtex_schema_alignment.sql` para alinear OTP, conducta y estados en Supabase.
  - `docs/dtex_qr_pwa_strategy.md` con estrategia QR/PWA temporal para custodios eventuales.
- Validacion:
  - `dart format` OK.
  - `flutter analyze` sobre archivos tocados OK.
  - `flutter analyze` completo OK.
  - `flutter test` completo OK.
  - `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` levanto correctamente.
  - `curl http://127.0.0.1:8080` devuelve HTML.

### Comandante - Mapa historico agrupado
- Se ejecuto el bloque pendiente de continuidad para el mapa historico del comandante.
- `lib/presentation/controllers/commander_controller.dart`:
  - Agregado `HistoricalRouteCluster`.
  - Agregado helper `compactHistoricalRoute()` para agrupar puntos consecutivos mientras el desplazamiento sea `<= 50 m`.
  - La agrupacion filtra reportes sin GPS, ordena por hora y abre un nuevo tramo cuando supera el umbral.
- `lib/presentation/views/commander_dashboard_view.dart`:
  - El mapa historico consume la compactacion desde el controlador.
  - Tooltips por punto muestran `HORA` o `RANGO` y cantidad de reportes agrupados.
  - Los puntos agrupados muestran badge visible con el conteo.
  - Se mantiene drag/zoom y ajuste de camara sobre los puntos compactados.
- Validacion:
  - `dart format` OK.
  - `flutter analyze lib/presentation/widgets/alertas_card.dart` OK.
  - `flutter analyze lib/presentation/widgets/estado_operativo_card.dart` OK.
  - `flutter analyze lib/presentation/controllers/commander_controller.dart lib/presentation/views/commander_dashboard_view.dart` OK.
- Build no ejecutado, siguiendo la guia de continuidad.

### DTEX - Integracion inicial en WebApp SCCP
- Se hizo revision completa de estructura, README y CHANGELOG antes de tocar codigo.
- Diagnostico inicial:
  - `README.md` esta desactualizado frente al estado real del sistema.
  - La WebApp SCCP base ya tiene supervisor/comandante, radio operativa, partes sorpresa, analitica, telemetria, seguridad admin y PWA.
  - DTEX existia como capa parcial: modelos, repositorio y controlador, pero sin entrada visible/ruta/vista operativa.
- Archivos DTEX existentes revisados:
  - `lib/data/models/dtex_mision_model.dart`
  - `lib/data/models/dtex_destino_model.dart`
  - `lib/data/models/dtex_alerta_model.dart`
  - `lib/data/models/dtex_tracking_extension_model.dart`
  - `lib/data/repositories/dtex_repository.dart`
  - `lib/presentation/controllers/dtex_controller.dart`

### DTEX - Cambios aplicados
- Nuevo panel operativo:
  - `lib/presentation/views/dtex_view.dart`
  - Abre como dialog/panel desde WebApp.
  - Incluye lista/filtros de misiones, creacion de mision, generacion OTP, detalle, tracking basico por ultima posicion, alertas pendientes, extensiones pendientes y cierre manual.
- Integracion con dashboard supervisor:
  - `lib/presentation/views/dashboard_view.dart`
  - Se agrego boton `Diligencias DTEX` en acciones superiores del supervisor.
- Correcciones base:
  - `DtexMision.estaActiva` ahora incluye `EMERGENCIA` para mantener tracking realtime.
  - `cerrarMisionConConducta` ahora marca `estado = CERRADA` y setea `ts_cierre`.
  - OTP cambiado de generacion basada en reloj a `Random.secure()`.
  - `getMisiones()` corregido para aplicar filtros Supabase antes de `order/limit`.

### Validacion tecnica
- `dart format` OK en archivos tocados.
- `flutter analyze` OK, sin issues.
- `flutter test` OK.
- Al probar servidor web aparecio pantalla roja:
  - `Library not defined: package:sccp_command_center/core/theme/app-theme.dart`
  - Causa probable: artefactos/cache heredados de Windows dentro de `.dart_tool` / `build`, no import real en `lib/`.
  - Se confirmo que el codigo fuente importa `app_theme.dart` correctamente.
  - Se ejecuto limpieza de migracion Windows -> Linux:
    - `flutter clean`
    - `flutter pub get`
  - Esto borro artefactos generados y regenero dependencias en Linux Mint.

### Contexto DTEX confirmado por usuario
- Schema Supabase real fue compartido en conversacion.
- Tablas DTEX existentes en schema:
  - `dtex_misiones`
  - `dtex_destinos`
  - `dtex_tracking_gps`
  - `dtex_alertas`
  - `dtex_extensiones`
- Roles reales en `allowed_admins.nivel_acceso`:
  - `SUDO`
  - `SUPERVISOR`
  - `SUPERVISOR_DTEX`
- Diferencia operativa:
  - SCCP actual supervisa control externo.
  - DTEX sera supervisado por jefe de seguridad interno.
  - Superusuario/director/administrador debe tener acceso superior.
- Estados deseados por usuario para DTEX:
  - primero estado de mision aceptada/abierta,
  - luego registro realizado,
  - en ruta,
  - en destino,
  - retorno,
  - completada.
- Alertas deseadas:
  - desvio,
  - detenido,
  - ubicacion apagada,
  - cualquier inconsistencia operativa.
- Datos de internos/policias:
  - mantener DTEX separado de `reos` y `oficiales` fijos,
  - porque custodios e internos para diligencias externas son eventuales/rotativos.
- App movil/custodio:
  - usuario duda entre app Android tradicional y flujo temporal.
  - Idea preferida a explorar: acceso temporal por QR para mision, sin obligar a todos los custodios rotativos a instalar una app permanente.

### Pendientes inmediatos para siguiente sesion
- Adaptar codigo DTEX al schema real:
  - `codigo_otp` en schema aparece como `character NOT NULL`; para OTP de 6 digitos deberia cambiarse a `text` o `varchar(6)` en Supabase, o el codigo debera ajustarse si no se cambia DB.
  - `conducta_final` tiene CHECK: `SIN_INCIDENCIAS`, `CON_OBSERVACIONES`, `CON_INCIDENCIAS_GRAVES`; la UI actual permite texto libre y debe cambiar a selector.
  - Estados actuales del codigo usan `PENDIENTE`, `EN_RUTA`, `EN_DESTINO`, `RETORNANDO`, `CERRADA`, `EMERGENCIA`, `CANCELADA`; deben alinearse con los estados deseados o mapearse con etiquetas operativas.
  - `AllowedAdmin` todavia entiende `DIRECTOR`; debe alinearse con `SUDO`, `SUPERVISOR`, `SUPERVISOR_DTEX` sin romper acceso actual.
- Volver a levantar servidor luego de `flutter clean && flutter pub get` y verificar que desaparezca pantalla roja.
- Mantener DTEX aislado para no romper SCCP funcional:
  - no tocar radio,
  - no tocar partes sorpresa,
  - no tocar analitica comandante,
  - no tocar dashboard central salvo entrada controlada DTEX.

### Prompt de continuidad para proxima sesion
```text
Estamos en /home/kad-pmb/Documentos/sccp_command_center, Flutter WebApp SCCP en Linux Mint. El proyecto venia de Windows y ya se ejecuto `flutter clean && flutter pub get` para limpiar artefactos Windows. No hay .git en esta carpeta, asi que antes de cambios grandes conviene hacer backup o inicializar git.

Contexto: SCCP actual funciona y NO se debe romper. Tiene supervisor/comandante, radio operativa, partes sorpresa, analitica, telemetria y seguridad admin. DTEX es modulo nuevo para diligencias externas, separado del SCCP externo. El jefe de seguridad interno supervisa DTEX; superusuario/director/administrador tiene acceso superior. Roles reales en allowed_admins.nivel_acceso: SUDO, SUPERVISOR, SUPERVISOR_DTEX.

Ya se agrego una primera integracion DTEX:
- lib/presentation/views/dtex_view.dart
- boton "Diligencias DTEX" en lib/presentation/views/dashboard_view.dart
- ajustes en lib/data/repositories/dtex_repository.dart
- ajustes en lib/data/models/dtex_mision_model.dart
Validacion previa: flutter analyze OK y flutter test OK antes del flutter clean.

Schema DTEX real existe en Supabase: dtex_misiones, dtex_destinos, dtex_tracking_gps, dtex_alertas, dtex_extensiones. Ojo: dtex_misiones.codigo_otp aparece como `character NOT NULL`, pero el codigo genera OTP de 6 digitos; recomendar cambiar DB a text/varchar(6) o ajustar codigo. conducta_final tiene CHECK: SIN_INCIDENCIAS, CON_OBSERVACIONES, CON_INCIDENCIAS_GRAVES; UI actual debe pasar de texto libre a selector.

Estados deseados por usuario para DTEX: mision aceptada/abierta -> registro realizado -> en ruta -> en destino -> retorno -> completada. Alertas deseadas: desvio, detenido, ubicacion apagada y cualquier inconsistencia. Datos de interno/custodio deben manejarse aparte, sin depender de tablas reos/oficiales fijas, porque son eventuales.

Hubo pantalla roja al abrir server: "Library not defined: package:sccp_command_center/core/theme/app-theme.dart". El codigo fuente importa app_theme.dart correctamente; causa probable eran artefactos Windows en .dart_tool/build. Ya se limpio con flutter clean/pub get. Primer paso de la nueva sesion: correr `flutter analyze`, `flutter test`, levantar `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` y verificar si la pantalla roja desaparecio.

Objetivo siguiente: avanzar con cambios conservadores, aislados a DTEX, sin tocar SCCP funcional. Primero alinear AllowedAdmin/Auth con SUDO/SUPERVISOR/SUPERVISOR_DTEX sin romper acceso existente; luego adaptar estados/labels DTEX y conducta_final; luego definir estrategia QR/PWA temporal para custodio en vez de app Android obligatoria permanente.
```

## 2026-02-28

### Corrección crítica de acceso por grupo (ALFA/BRAVO)
- `lib/presentation/controllers/dashboard_controller.dart`:
  - cálculo de grupo diario ajustado al día operativo `08:00 -> 07:59`.
  - ciclo de 14 días anclado en `2026-02-28` (día 1).
  - distribución final de ciclo:
    - `ALFA`: `{1, 4, 6, 9, 10, 12, 14}`
    - `BRAVO`: `{2, 3, 5, 7, 8, 11, 13}`
- `lib/presentation/controllers/commander_controller.dart`:
  - ancla diaria de analítica operativa alineada a `08:00`.
- `lib/presentation/views/dashboard_view.dart`:
  - etiqueta de periodo corregida a `08:00 a 08:00`.
- `docs/monitoring_analytics_logic.md`:
  - documentación actualizada al nuevo corte operativo `08:00-08:00`.

### Limpieza técnica de integridad (sin retrocesos)
- Rutas de assets corregidas para evitar íconos/imágenes invisibles:
  - `web/index.html`: `assets/assets/images/...` -> `assets/images/...`.
  - `lib/core/services/browser_notification_web.dart`: ícono de notificación apuntando a `assets/images/logo.png`.
  - `lib/presentation/controllers/dashboard_controller.dart`: fallbacks web de logos corregidos a `/assets/images/...`.
- `lib/presentation/views/dashboard_view.dart`:
  - logo de grupo reforzado con mapeo explícito `ALFA/BRAVO` y fallback seguro `logo-sccp.png` para evitar rutas inválidas.
- Verificación de integridad:
  - barrida de referencias `assets/*` en código: `MISSING_COUNT=0`.
  - `flutter analyze` OK.
  - `flutter test` OK.
  - `flutter build web --release` OK.

### Notificaciones web: no repetir histórico al reingresar
- `lib/presentation/controllers/dashboard_controller.dart`:
  - corrección de secuencia de bootstrap de notificaciones para evitar disparo masivo al iniciar.
  - removido efecto colateral en inbox de radio que marcaba bootstrap prematuro.
  - filtro de recencia agregado:
    - alertas/inconsistencias: solo recientes (ventana operativa corta),
    - radio: solo mensajes recientes.
- `lib/core/services/browser_notification_web.dart`:
  - deduplicación persistente en `localStorage` con TTL y limpieza automática.
  - evita re-notificar los mismos eventos al cerrar/abrir sesión web.
- `lib/core/services/browser_notification_stub.dart`:
  - API de dedupe alineada para plataformas no web.

### Informe impreso: radio en lenguaje operativo (sin payload técnico RTC)
- `lib/presentation/controllers/dashboard_controller.dart`:
  - bitácora del informe individual ahora traduce eventos RTC a estados comprensibles:
    - `INTENTO`, `RESPONDIDO`, `NO RESPONDIDO`, `FINALIZADO`.
  - filtrado de ruido técnico `ICE` (`__RTC__`) para no contaminar la lectura ejecutiva.
  - resumen de radio recalculado por contacto real:
    - intentos,
    - respuestas,
    - fallos por no respuesta.
  - detalle de mensajes normalizado y truncado para lectura rápida.

### Perfil oficial webapp - jurisdicción visible
- `lib/data/models/oficial_model.dart`:
  - agregado campo `jurisdiccion` con mapeo JSON (`jurisdiccion` / `Jurisdiccion`).
- `lib/presentation/widgets/detallado_perfil_oficial_dialog.dart`:
  - perfil detallado ahora muestra chip `JUR` junto a datos operativos del oficial.

## 2026-02-27

### Alineación cadena 09:00 (webapp/analítica)
- `dashboard_controller.dart`:
  - ventana operativa diaria ajustada de `08:00-08:00` a `09:00-09:00`.
- `commander_controller.dart`:
  - `effectiveShiftDate` diario y `_periodRange(AnalyticsPeriod.daily)` alineados a umbral 09:00.
- `dashboard_view.dart`:
  - texto de periodo en impresión supervisor actualizado a `09:00 a 09:00`.

### Documentación SQL/analítica
- `docs/monitoring_analytics_schema.sql`:
  - ventana `DIA` ajustada a `09:00 -> +24h`.
- `docs/monitoring_analytics_logic.md`:
  - referencia operativa diaria actualizada a `09:00-09:00`.

### Validación
- `flutter analyze` OK
- `flutter test` OK

### Webapp - Responsive (móvil) y tamaño de diálogos
- `lib/presentation/widgets/supervisor_quick_actions.dart`:
  - `Partes Sorpresa` y `Radio Operativa` ahora usan tamaño responsivo por viewport.
  - en móvil, controles superiores e input de radio pasan a layout vertical para evitar desorden/superposición.
  - burbujas de mensajes de radio ajustan ancho máximo dinámicamente en móvil.
- `lib/presentation/widgets/gestion_oficiales_dialog.dart`:
  - diálogo migrado a tamaño responsivo.
  - en móvil, distribución por pestañas (`OFICIALES / FORMULARIO / MASIVO`) para evitar colisiones de columnas.
  - cabecera y formularios compactados para pantallas estrechas.
- `lib/presentation/widgets/jarvis_initialization_overlay.dart`:
  - overlay JARVIS adaptado a móvil (reactor, panel de texto, partículas y offsets dinámicos).
- `lib/presentation/views/index_view.dart`:
  - splash/index con ancho/alto de HUD calculados por viewport para evitar panel gigante/descentrado.
- `lib/presentation/views/dashboard_view.dart`:
  - diálogo `Inconsistencias` reestructurado para responsive (métricas en `Wrap` + contenido embebido sin superposición).
- `lib/presentation/widgets/estado_operativo_card.dart`:
  - ajuste de `insetPadding` desktop para que el tamaño percibido del `onClick` de Estado Operativo quede alineado con el de `Alertas`.

### Validación adicional
- `flutter analyze` OK

### Ajuste tamaño popup Estado Operativo (desktop web)
- `lib/presentation/widgets/estado_operativo_card.dart`:
  - corrección del detector `mobileDialog` para web (`kIsWeb`) usando criterio por ancho.
  - evita que el popup de `Estado Operativo` entre en modo móvil por altura de ventana en PC.
  - resultado: tamaño desktop consistente con popup de `Alertas` (ancho 550).

### Webapp - Correcciones responsive críticas (móvil) + mapa
- `lib/presentation/widgets/supervisor_quick_actions.dart`:
  - `Partes Sorpresa` y `Radio Operativa` pasan a layout full-viewport en móvil (sin compresión por inset/padding).
  - contenedores móviles usan borde/radio adaptado para presentación tipo pantalla completa.
- `lib/presentation/views/partes_view.dart`:
  - mejora de legibilidad en móvil: títulos con `ellipsis`, chips en `Wrap`, y filas de detalle sin quiebre vertical de texto.
- `lib/presentation/widgets/telemetria_card.dart`:
  - corrección de altura de diálogo en móvil (antes quedaba fijo en ~500).
  - ajuste de espaciado/tamaños en panel de batería para evitar superposición de estado vs. gráfica de tendencia.
  - padding del diálogo adaptado para pantallas compactas.
- `lib/presentation/views/index_view.dart`:
  - re-balance de tamaño del panel inicial para móvil y centrado estable con `SafeArea`.
- `lib/presentation/widgets/tactical_map.dart`:
  - paneles informativos del mapa visibles por defecto.
  - se mantiene deshabilitado panel de alertas por requerimiento operativo.
  - reactivado panel de jurisdicción y etiquetas de bases también en vista móvil.

### Verificación
- `flutter analyze` OK
- `flutter test` OK

### Webapp - Consistencia de tamaño entre ventanas flotantes (perfil oficial)
- `lib/presentation/widgets/detallado_perfil_oficial_dialog.dart`:
  - corrección del detector `mobileDialog` para web con criterio por ancho (`kIsWeb`), igual que en `Estado Operativo`.
  - evita que la tarjeta/perfil de oficial se expanda a tamaño móvil en escritorio por altura de ventana.
  - resultado: proporción visual alineada con popup de `Estado Operativo`.

## 2026-02-26

### Webapp - Control de Acceso (3 autorizados) + Hardening Netlify
- `web/_headers` agregado con seguridad HTTP:
  - `X-Frame-Options: DENY`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy`
  - `Permissions-Policy`
  - `COOP/CORP`
  - `Strict-Transport-Security`
  - política de caché (`index/service-worker` sin cache, assets inmutables)
- Script nuevo para bloqueo de acceso web a solo 3 cuentas:
  - `docs/supabase_lock_access_3_admins.sql`
  - desactiva otros en `allowed_admins` y bloquea no autorizados en `auth.users`.
- Guía operativa Netlify (admin único + 2FA + deploy hooks):
  - `docs/netlify_security_lockdown_v1_1_3.md`

### Webapp - Informe Impreso (Semántica de Cierre de Alertas/Incidencias)
- Se corrige lenguaje ambiguo en reportes imprimibles para evitar confusión entre:
  - `reportes automáticos`,
  - `incidencias/inconsistencias abiertas`.
- `dashboard_controller.dart` (informe individual supervisor):
  - agrega `tasa de cierre` de incidencias (`cerradas / total`),
  - cambia redacción a `incidencias abiertas sin cierre`,
  - agrega nota explícita: una incidencia abierta **no** significa reporte no enviado.
- `commander_dashboard_view.dart` (informe comandante):
  - agrega `tasa de cierre incidencias`,
  - nota aclaratoria sobre diferencia entre incidencia abierta y reporte automático.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Pendientes Críticos para Mañana (Prueba de Campo)
- App móvil:
  - mejorar gráficos de `Estadísticas` por una visualización más clara y directa para lectura en campo.
- Webapp:
  - cuando un `parte sorpresa` sea solicitado y registrado con éxito, actualizar estado visible en tarjeta (de `parte solicitado` a `parte registrado con éxito` o equivalente claro).
- App móvil:
  - al iniciar y conceder permisos, la app se cierra; al reabrir inicia normal. Revisar y corregir este cierre en primer arranque.

## 2026-02-25

### Webapp - Ajuste Fullscreen Publicado (Desktop Web)
- `dashboard_view.dart`:
  - se corrige activación prematura del modo mobile en web publicada.
  - nuevo criterio: en web solo apila layout si ancho real `< 980`.
  - se agrega ancho mínimo operativo desktop (`1360`) con scroll horizontal en ventanas angostas para evitar compresión visual.
  - re-balance de flex en columnas (`izquierda/centro/derecha`) según ancho para proteger tarjeta de `ESTADÍSTICAS`.
- `stats_widget.dart`:
  - se corrige umbral de micrográficos: ya no pasa a vertical tan pronto.
  - nuevo modo compacto solo en anchos extremadamente bajos (`< 220`), manteniendo distribución horizontal en desktop web publicada.

### Webapp - Seguridad Admin (Contraseña + PIN)
- Nuevo diálogo de seguridad:
  - `lib/presentation/widgets/admin_security_dialog.dart`
  - permite:
    - cambiar contraseña de cuenta admin,
    - cambiar PIN de seguridad con validación de PIN actual.
- Integración en UI:
  - botón `Seguridad de Cuenta` en header supervisor (`dashboard_view.dart`).
  - botón `SEGURIDAD` en header comandante (`commander_dashboard_view.dart`).
  - acción `VALIDAR NOTIFICACIONES WEB` en panel de seguridad (re-solicita permiso y prueba notificación local del navegador).
- `auth_controller.dart`:
  - nuevo flujo `cambiarContrasena(passwordActual, nuevaContrasena)` con verificación de credencial actual.
  - nuevo flujo `cambiarPinAdmin(pinActual, nuevoPin)` con validación previa.
- `supabase_repository.dart`:
  - nuevo método `actualizarPinAdmin(adminId, nuevoPin)`.
- Nota técnica:
  - el envío de notificaciones con web cerrada (Web Push VAPID) sigue pendiente como fase separada.

### Verificación
- `flutter analyze` OK (archivos modificados)
- `flutter test` OK

## 2026-02-24

### Cierre Operativo de Jornada (Pre-Campo)
- Supabase listo para prueba real de campo con flujo estable y sin ambigüedad:
  - `docs/supabase_reset_field_test_2days.sql` simplificado a bloque limpio de reset transaccional.
  - eliminado riesgo de error por texto suelto en SQL pegado (caso `syntax error near "n SLA..."`).
  - `docs/supabase_scope_field_test_oficiales.sql` validado en ejecución: activación controlada de oficiales de prueba.
- Validación de alcance aplicada:
  - confirmados solo `2` oficiales activos cuando se ejecuta el scope inicial (`5538491`, `5538492`).
  - criterio operativo confirmado para mañana: `1 dispositivo = 1 id_oficial` (por unicidad de sesión).
- Orden operativo cerrado para salida a campo:
  1. `supabase_reset_field_test_2days.sql`
  2. `supabase_scope_field_test_oficiales.sql` (ajustando a los 5 oficiales reales del turno)
  3. `supabase_field_test_smoke_2days.sql`
- Webapp publicada para prueba externa:
  - despliegue en Netlify manteniendo sitio único (sin crear drops nuevos por cada release).
  - instalación tipo app web (PWA) habilitada desde navegador móvil.
- Pendiente confirmado para próxima versión:
  - implementar Web Push real para PWA (VAPID + suscripción + `push` en service worker)
    para recibir notificaciones aun con la web cerrada.
  - corregir distribución/layout de micrográficos en tarjeta `Estadísticas`
    para mantener la composición horizontal definida.
  - habilitar gestión de credenciales de admin:
    - cambio de contraseña desde panel seguro (Supabase Auth),
    - cambio de PIN con validación de PIN actual + guardado seguro.

### Webapp - Preparacion de Campo v1.1.3
- Version visible de cargador web:
  - `web/index.html` ahora muestra `WEBAPP v1.1.3` en pantalla de carga.
- Version de aplicacion alineada:
  - `lib/core/constants/app_constants.dart` actualizado a `appVersion = 1.1.3`.
- Limpieza de workspace y residuos:
  - nuevo script `tools/cleanup_project_v113.ps1` para borrar carpetas temporales y archivos basura conocidos.
  - limpieza ejecutada en entorno local (incluye `android/.gradle`).
- Operacion test server:
  - nueva guia `docs/deploy_webapp_test_server_v1_1_3.md`.
  - nueva guia express `docs/deploy_express_mobile_test_v1_1_3.md` para publicar hoy en internet (Netlify/Vercel).
  - soporte SPA agregado para hosting rapido:
    - `web/_redirects` (Netlify)
    - `vercel.json` (rewrite a `index.html`)
- Checklist operativo:
  - `docs/checklist_pre_campo_manana_v1_1_3.md` con secuencia noche/mañana para salida a campo.
- Operacion base de datos (Supabase):
  - nuevo reset controlado `docs/supabase_reset_field_test_2days.sql`.
  - nuevo smoke test operativo `docs/supabase_field_test_smoke_2days.sql`.

### Webapp - Corrección de Overflow (Commander/Stats/Telemetría)
- `commander_dashboard_view.dart`:
  - header del comandante ahora responsivo (sin desborde en anchos reducidos).
  - diálogo de impresión adaptativo para pantallas estrechas (layout vertical automático).
  - `MAPA HIST` se apila en modo compacto para evitar overflow horizontal.
  - panel de estadísticas comandante usa scroll horizontal controlado en filas KPI/gráficas.
  - textos de métricas/KPI con `ellipsis` para evitar desbordes.
- `dashboard_view.dart`:
  - diálogo on-click de `ESTADÍSTICAS` ahora calcula ancho/alto en función de pantalla.
  - filas de métricas, carriles y gráficas cambian a `Wrap/Column` en modo compacto.
  - header del diálogo y chips de periodo sin desborde.
- `stats_widget.dart`:
  - tarjeta mini de estadísticas con layout adaptable:
    - cambia de `Row` a `Column` en anchos pequeños.
    - gauges con tamaño dinámico para evitar overflow.
- `telemetria_card.dart`:
  - diálogo de telemetría responsivo (ancho/alto dinámico).
  - panel de resumen reestructurado para móvil/narrow viewport.
  - corrección de overflow en líneas de estado (`label/value`).
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Lectura Inmediata (Alertas/Inconsistencias/KPI Operativo)
- Orden directa priorizada en esta entrega:
  - la seguridad biométrica y la automatización en primer/segundo plano
    siguen siendo prioridad inquebrantable del proyecto.
- `dashboard_view.dart`:
  - eliminado código placeholder que anulaba gráficos tácticos.
  - import de widgets reales de `tactical_charts.dart`.
  - diálogo de inconsistencias ahora usa datos reales (sin mocks):
    - espectro por tipo normalizado,
    - evolución temporal por hora,
    - listados ordenados por impacto (tipo/oficial/prioridad).
- `dashboard_controller.dart` (`buildRealtimeAnalytics`):
  - KPI explícito y auditable:
    - `reportes_esperados` (según ventana operativa transcurrida y 1 reporte/6 min),
    - `reportes_total`,
    - `cumplimiento_reportes_pct` y nivel (`ALTO/MEDIO/BAJO`),
    - `reportes_esperados_jornada` (proyección jornada completa).
  - separación de carriles para evitar sobrerreacción visual:
    - `alertas`,
    - `inconsistencias`,
    - `telemetria`.
  - nuevos buckets/severidad por carril + nivel consolidado.
  - índice de riesgo recalibrado con ponderación de severidad y cumplimiento.
- `estado_operativo_card.dart`:
  - selector de alertas reorganizado por prioridad operativa:
    - infractores primero,
    - motivo de alerta/acción visible antes del detalle de perfil,
    - estado diferenciado entre alerta activa, inconsistencia abierta y estado normal.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Umbrales Visibles y Semáforo de Carriles
- `StatsWidget` optimizado para lectura ejecutiva:
  - KPI principal de cumplimiento de reportes (`recibidos/esperados`) con
    nivel visible (`ALTO/MEDIO/BAJO`).
  - fórmula operativa expuesta en UI:
    - 1 reporte cada 6 minutos por oficial.
  - semáforo por carriles:
    - `Alertas`,
    - `Inconsistencias`,
    - `Telemetría`,
    con conteo `Alta/Media/Baja` y nivel consolidado por carril.
  - etiquetas de gráficos más claras:
    - `ALERTAS POR TIPO` (`ABANDONO`, `OTRAS`, `FALTA RPT`),
    - panel adicional `TELEMETRÍA (OBSERVACIONES)`.
- Diálogo on-click de estadísticas (`dashboard_view.dart`):
  - agrega bloque de “Lectura inmediata” con:
    - cumplimiento de reportes,
    - nivel actual,
    - referencia geográfica (`GEO<=50m`),
    - y los 3 carriles en formato semáforo.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Alertas Card (Control Crítico por Cobertura)
- Se corrige inconsistencia crítica en tarjeta `Alertas`:
  - si la cobertura operativa cae (ej. `0/20`), se inyecta alerta de sistema
    `SIN_COBERTURA` y el riesgo sube a crítico automáticamente.
- Se elimina tendencia falsa en micrográfico de problemas:
  - deja de usar datos mock y ahora usa buckets reales de últimas 5 horas.
- Se redefine lectura de micrográficos en tarjeta `Alertas`:
  - `Riesgo`: índice analítico con sobre-escalado por cobertura crítica.
  - `Problemas` (donut): `Críticas`, `Cobertura`, `Técnicas`.
  - barras inferiores: `CRÍT`, `COV`, `TEC`.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Hotfix Riesgo 0/N y Detalle de Alerta de Sistema
- Se ajusta el cálculo para que, cuando la cobertura sea `0/N` (sin oficiales activos
  con nominal > 0), el `riesgo` sea `100%` sin ambigüedad.
- Se agrega fallback de detalle para alertas de sistema (`SIN_COBERTURA`):
  - al hacer click ya no muestra “oficial no encontrado”,
  - abre un detalle de alerta de sistema con motivo, severidad y faltantes.
- Se mejora matching de oficial por ID con `trim()` para reducir falsos
  “oficial no encontrado” por espacios en datos.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Hotfix Overflow Alertas + Telemetría Real
- `AlertasCard`:
  - se corrige overflow visual en tamaños compactos con escalado responsivo
    de gauges, donut, sparkline y tipografías.
  - se elimina restricción rígida que forzaba ancho mínimo y provocaba desborde.
- `TelemetriaCard`:
  - se alinea a métricas reales de analytics (`activos/nominal`, `nivel telemetría`).
  - se elimina actividad sintética cuando no hay datos:
    - señal y batería ya no muestran curvas artificiales.
  - `MULTI-LINE SIGNALS` en diálogo usa series reales:
    - batería,
    - GPS,
    - estado de alerta.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Informe Impreso (Robustez Logos + Cuantificación Clara)
- Se corrige la carga de logos institucionales en la vista previa imprimible:
  - ahora se embeben como `data URI` (base64) desde assets para evitar fallos
    por rutas en pestañas `Blob URL`.
  - fallback automático a ruta web si no se puede resolver el asset.
- Se corrige la interpretación de `alertas_tipo` en el informe individual:
  - antes se mostraba como `Críticas/Altas/Medias`,
  - ahora se muestra como tipos operativos reales:
    - `GPS/Distancia`,
    - `Otras`,
    - `Falta reporte`.
- Se actualizan títulos y tablas de cuantificación para reducir ambigüedad
  en lectura ejecutiva del supervisor.
- Verificación:
  - `flutter analyze` OK
  - `flutter test` OK

### Webapp - Telemetría (Semántica Clara + Botones Operativos)
- Se mejora la legibilidad del panel superior izquierdo de telemetría:
  - nuevo bloque `RESUMEN TELEMETRÍA` con etiquetas humanas:
    - `Dispositivos vigilados`,
    - `GPS offline`,
    - `Batería <20%`,
    - `Críticos telemetría`,
    - `Nivel consolidado`.
- Se aclara el significado operativo de cada módulo on-click:
  - `ENERGY CELL`: batería del último reporte.
  - `SPECTRUM RADAR`: distribución real de `GPS/Batería/Estado/Cobertura`
    (deja de ser animación sintética).
  - `CORE DIAGNOSTICS`: ficha técnica legible (`Oficial`, `Dispositivo`,
    `Último ping`, `Batería`, `GPS`, `Estado`).
  - `MULTI-LINE SIGNALS`: tendencia de señales con leyenda explícita
    (`BATERÍA`, `GPS`, `ALERTA`).
- Botones de acción dejan de ser solo visuales:
  - `REINICIAR ENLACE`: ahora fuerza resincro real de
    `telemetría + reportes + alertas`.
  - `PING`: evalúa frescura real del último reporte y muestra estado
    `OK / DEGRADADO / CRÍTICO` con segundos transcurridos.

### Webapp - Telemetría Hotfix (Legibilidad + Filtro por Grupo)
- Se elimina ruido visual en panel on-click de telemetría:
  - scanlines ya no pisan el bloque `RESUMEN TELEMETRÍA`,
  - panel superior izquierdo con fondo más opaco y filas legibles.
- Se corrige fuente de datos para evitar cruce entre grupos:
  - `CORE DIAGNOSTICS`, `ENERGY CELL` y cálculo de panel usan ahora
    telemetría filtrada por `grupo` activo.
- Encabezado derecho ajustado a 2 filas sin invadir el resumen superior.
- `SPECTRUM RADAR` migra a barras lineales gruesas y legibles:
  - `GPS OK`,
  - `BAT OK`,
  - `EST NORMAL`,
  - `COBERTURA`.
- Se retiran botones inferiores `REINICIAR ENLACE` y `PING` del diálogo
  por baja utilidad operativa en esta vista.

### Webapp - Telemetría (Selector por Oficial con Prioridad)
- `CORE DIAGNOSTICS` deja de mostrar un único oficial implícito.
- Se agrega selector de oficial limitado al grupo operativo activo (ALFA/BRAVO).
- Orden del selector por prioridad telemétrica:
  - primero oficiales con estado crítico/fallos de GPS/batería baja,
  - luego por hora de último ping más reciente.
- Resaltado visual de prioridad en selector y panel de diagnóstico:
  - `CRÍTICA`, `ALTA`, `MEDIA`, `NORMAL`.
- `ENERGY CELL` y `CORE DIAGNOSTICS` ahora se actualizan según el oficial
  seleccionado (misma fuente de datos y mismo grupo).

### Webapp - Telemetría Layout (Selector Integrado en Energy)
- Reacomodo visual solicitado:
  - se elimina la franja horizontal independiente del selector,
  - el bloque de `ENERGY CELL` se divide en dos:
    - superior: selector desplegable de oficial,
    - inferior: visual de batería (`ENERGY CELL`).
- Objetivo: aumentar área útil vertical para `SPECTRUM RADAR` y
  `MULTI-LINE SIGNALS` y mejorar lectura en pantalla.
- `ENERGY CELL` deja de mostrar solo un porcentaje aislado:
  - indicador grande `%`,
  - estado energético literal (`CRÍTICA/BAJA/MEDIA/ÓPTIMA`),
  - barra de progreso visible,
  - tendencia de batería de últimos reportes del oficial seleccionado.

### Webapp - Inconsistencias (Lectura Limpia + Perfil Directo)
- `inconsistencias_view.dart`:
  - se elimina el flujo de resolución por PIN desde la lista de inconsistencias
    (evita overflow y reduce fricción operativa en esta pantalla).
  - cada fila ahora prioriza lectura humana:
    - badge de prioridad más compacto (`CRÍTICA/ALTA/MEDIA/BAJA`),
    - línea 1: oficial + estado,
    - línea 2: motivo de inconsistencia (ej. `GPS FALSO`).
  - al hacer click en una inconsistencia, abre directamente
    `DetalladoPerfilOficialDialog` del oficial, en lugar del modal de PIN.
- `dashboard_view.dart`:
  - actualización de llamadas a `InconsistenciasView` para el nuevo flujo sin
    callback de resolución.
- Verificación:
  - `flutter analyze lib/presentation/views/inconsistencias_view.dart lib/presentation/views/dashboard_view.dart` OK
  - `flutter test` OK

### Webapp - Inconsistencias OnClick (Compacto + Gráficos Legibles)
- `dashboard_view.dart` (`ANÁLISIS DE INCONSISTENCIAS LÓGICAS`):
  - se compacta el layout del diálogo para mantener proporciones similares al resto
    del dashboard (menos bloques sobredimensionados).
  - `ESPECTRO POR TIPO` migra a barras compactas estables (top tipos) para evitar
    panel monocolor cuando hay pocos datos.
  - `EVOLUCIÓN TEMPORAL` usa serie de 8 horas con mensaje contextual cuando no hay
    eventos en la ventana.
  - `DISTRIBUCIÓN POR PRIORIDAD` fija categorías (`CRÍTICA/ALTA/MEDIA/BAJA`) para
    que el gráfico no colapse visualmente con una sola prioridad activa.
  - tarjetas KPI superiores (`TOTAL/CRÍTICAS/ABIERTAS/RESUELTAS`) en formato
    compacto para reducir ruido visual.
- Verificación:
  - `flutter analyze lib/presentation/views/dashboard_view.dart` OK
  - `flutter test` OK

### Webapp - Inconsistencias (Filtro Estricto por Grupo Activo)
- Corregida fuga de registros entre grupos en inconsistencias:
  - `dashboard_controller.dart`:
    - nuevo filtro robusto por grupo activo (`ALFA/BRAVO`) para inconsistencias,
      con resolución por `grupo` en fila y fallback por `id_oficial`.
    - `inconsistenciasFiltered`, `inconsistenciasAbiertas` e
      `inconsistenciasEnRevision` ahora operan sobre el grupo activo.
    - nuevo getter `inconsistenciasDelGrupoActivo`.
  - `dashboard_view.dart`:
    - diálogo `ANÁLISIS DE INCONSISTENCIAS LÓGICAS` ahora usa
      `inconsistenciasDelGrupoActivo` (ya no mezcla oficiales de otro grupo).
- Verificación:
  - `flutter analyze lib/presentation/controllers/dashboard_controller.dart lib/presentation/views/dashboard_view.dart` OK
  - `flutter test` OK

### Webapp - Estadísticas (Card Compacta + OnClick Grupal/Global)
- `stats_widget.dart`:
  - tarjeta pequeña simplificada para lectura inmediata (sin saturación visual):
    - solo `COV`, `CUMP`, `RISK`,
    - semáforo por carriles (`Alertas`, `Incons`, `Telem`),
    - microtendencias `RPT_7D` y `ACT_7D`.
  - removidos bloques secundarios que sobrecargaban la tarjeta y generaban
    problemas de legibilidad/overflow en espacios reducidos.
- `dashboard_view.dart` (`_showEstadisticasDialog`):
  - rediseño del onClick con enfoque exclusivo de grupo (sin vista personal):
    - KPIs del grupo activo (`RPT`, `CUMP`, `COV`, `RISK`),
    - comparación global (`RPT GLOBAL`, `CUMP GLB`),
    - influencia del grupo sobre el global (`INFL RPT`, `INFL ACT`).
  - nuevos gráficos operativos:
    - actividad diaria del grupo por tramos de 3 horas,
    - actividad semanal del grupo,
    - influencia semanal del grupo en el global (%).
  - se mantiene semáforo de carriles para lectura rápida de prioridades.
- Verificación:
  - `flutter analyze lib/presentation/widgets/stats_widget.dart lib/presentation/views/dashboard_view.dart` OK
  - `flutter test` OK

### Webapp - Estadísticas OnClick (Selector de Período HOY/7D/30D)
- `dashboard_view.dart` (`_showEstadisticasDialog`):
  - se agrega selector de período:
    - `HOY`
    - `7D`
    - `30D`
  - los KPIs y gráficos se recalculan dinámicamente por período seleccionado:
    - `RPT GRUPO`, `CUMP G`, `COV G`, `RISK G`,
    - `RPT GLOBAL`, `CUMP GLB`,
    - `INFL RPT`, `INFL ACT`.
  - mantiene enfoque operativo grupal (sin vista personal en esta pantalla).
  - gráficos:
    - actividad del período del grupo,
    - actividad semanal del grupo,
    - influencia semanal del grupo sobre el global.
- Verificación:
  - `flutter analyze lib/presentation/views/dashboard_view.dart lib/presentation/widgets/stats_widget.dart` OK
  - `flutter test` OK

### Webapp - Dashboard Comandante (Tabs Flotantes + Sin Modo Espía)
- `commander_dashboard_view.dart`:
  - removida pestaña `MODO ESPIA` del header (se desactiva de interfaz hasta
    nueva definición funcional).
  - navegación de header ajustada para mantener estética operativa:
    - `MAPA HIST` y `ESTADISTICAS` ya no reemplazan toda la pantalla,
    - ahora abren ventanas flotantes (`Dialog`) sobre el panel operativo.
  - base de comandante queda en modo `OPERATIVO` persistente.
- `ESTADISTICAS` comandante globalizada:
  - reemplazo de vista por análisis consolidado con comparativa:
    - `GLOBAL`, `ALFA`, `BRAVO`,
    - influencia de grupos en el global,
    - recomendaciones automáticas de acción operativa.
  - se retira flujo de estadística individual en esta pantalla.
- impresión desde perfil comandante:
  - nuevo botón `IMPRIMIR` en header.
  - opciones:
    - informe global,
    - informe por grupo (`ALFA/BRAVO`),
    - informe individual (manteniendo lógica previa del supervisor).

### Webapp - index.html (Splash Web con Ciclo Completo de 3 Logotipos)
- carga inicial web ajustada para replicar arranque móvil:
  - ciclo animado de 3 logotipos (`logo.png`, `logo2.png`, `logo3.png`).
  - el loader no se cierra hasta completar al menos un ciclo completo de logos.
  - luego del ciclo, se oculta únicamente cuando llega `flutter-first-frame`.

- Verificación:
  - `flutter analyze lib/presentation/views/commander_dashboard_view.dart lib/presentation/views/dashboard_view.dart lib/presentation/widgets/stats_widget.dart` OK
  - `flutter test` OK
  - `flutter build web --release` OK

## 2026-02-23

### Webapp - Fix Vista Previa de Impresion
- Corregido error de pestaña `about:blank` al imprimir reporte individual.
- El render de impresión web cambia de `data:` URL a `Blob URL` para evitar
  truncado cuando el informe es grande.
- Nuevo flujo en supervisor:
  - abre vista previa del documento en nueva pestaña,
  - botón `Imprimir / Guardar PDF`,
  - botón `Cerrar`.
- Ya no dispara impresión ciega; ahora el supervisor revisa el formato antes.

### Webapp - Informe Individual Inteligente (Supervisor)
- El reporte individual deja de imprimir JSON crudo.
- Nuevo formato ejecutivo en lenguaje claro:
  - puntaje integral (0-100),
  - calificación literal (`EXCELENTE`, `BUENO`, `REGULAR`, `CRITICO`),
  - conclusión operativa,
  - cuantificación completa (reportes, alertas, partes, inconsistencias,
    batería y distancia),
  - razonamiento de evaluación inteligente,
  - acciones recomendadas.
- Se agrega sección de interacción con radio base:
  - total de eventos, intentos de contacto, respuestas, fallos,
  - bitácora cronológica de comunicación (últimos eventos).
- Se agrega tabla de inconsistencias del oficial en el periodo.

### Webapp - Informe Ejecutivo Institucional + Autenticidad
- Upgrade del informe individual a formato más crítico e interpretativo:
  - índice de riesgo operativo,
  - índice de confiabilidad,
  - criticidad por niveles,
  - factor de riesgo dominante,
  - narrativa ejecutiva de impacto.
- Gráficos incorporados en la vista previa imprimible:
  - barras de Confiabilidad/Riesgo/Cobertura/Cumplimiento,
  - distribución de severidad de alertas,
  - tendencia de reportes 7 días,
  - estado energético por buckets.
- Encabezado institucional con logos de `assets/images`.
- Bloque de autenticidad:
  - código de verificación único por informe,
  - QR de verificación del payload del reporte.
- Constancia formal de supervisión:
  - nombre del supervisor logueado,
  - cargo/grado operativo derivado del perfil autenticado,
  - fecha/hora de emisión.

### Supervisor - Impresion Directa de Reporte Individual
- Se agrega boton directo `Imprimir Reporte Individual` en el header del
  dashboard de supervisor.
- El flujo abre selector de oficial del grupo activo y envia el informe a
  impresion directamente desde navegador.
- Restriccion operativa aplicada:
  - Supervisor: solo impresion/evaluacion individual.
  - Evaluaciones grupales/globales permanecen en modulo de comandante/director.
- Se agrega servicio de impresion web:
  - `lib/core/services/report_print_service.dart`
  - `lib/core/services/report_print_service_web.dart`
  - `lib/core/services/report_print_service_stub.dart`

### SQL Consolidado de Limpieza/Hardening (Supabase)
- Nuevo script operativo unificado:
  - `docs/supabase_cleanup_hardening_optimized_2026-02-23.sql`
- Alcance del script:
  - Limpia politicas RLS heredadas/permisivas en tablas criticas.
  - Endurece acceso en `login_logs`, `oficial_sesiones`, `oficiales`,
    `allowed_admins`, `audit_eventos`, `deleted_records_backup`.
  - Mantiene compatibilidad con arquitectura actual:
    - app movil en `anon` para operacion de campo,
    - webapp en `authenticated`.
  - Normaliza `login_logs.status` y `oficial_sesiones.estado`.
  - Elimina registros de diagnostico tecnico (`diag_*`) en `login_logs`.
  - Aplica indices de rendimiento sobre tablas de alto trafico.
  - Incluye consultas de verificacion post-ejecucion.
- Hotfix critico posterior:
  - Se ajusta manejo de tablas de auditoria (`audit_eventos`,
    `deleted_records_backup`) a modo `insert-only` para `anon/authenticated`.
  - Motivo: triggers de auditoria de tablas operativas requerian insertar en
    auditoria; bloquear completamente esas tablas provocaba rechazo de
    inserciones operativas (ej. `monitoreo_reportes`).

### Hotfix Auditoria de Sesiones (WebApp)
- Se refuerza el registro de `login_logs` para supervisor/director:
  - `registrarLoginLog` ahora normaliza `email/status` y retorna resultado.
  - Insercion con payload extendido (`actor_tipo`, `metadata`) y fallback
    automatico a payload legacy si el esquema no tiene columnas nuevas.
  - Se agrega diagnostico explicito cuando falla el registro.
- Cierre de sesion mas robusto:
  - `cerrarSesionLogActiva` ya no depende de coincidencia exacta de estado.
  - Busca la sesion activa mas reciente de forma case-insensitive en cliente.
  - Si no hay sesion activa, registra `logout` igualmente.
- `AuthController` ahora deja trazas de warning cuando no se pudo registrar o
  cerrar `login_logs`, para facilitar debugging en campo.

## 2026-02-19

### Handoff Nocturno (continuidad para manana)

### SQL / Supabase
- `docs/supabase_sla_reportes_estricto.sql`:
  - Corregida lectura de heartbeat para esquemas mixtos:
    - `last_heartbeat`, `heartbeat_at`, `updated_at`, `login_at`.
  - Compatibilidad de estado de sesion en vista SLA:
    - `ACTIVA` y `ACTIVE`.
  - Normalizacion de joins por oficial en `v_sla_reportes_estado`:
    - `trim(...::text)` en `oficiales.id_oficial`, `oficial_sesiones.id_oficial`, `monitoreo_reportes.id_oficial_ref`.
- `docs/supabase_sla_reportes_cron.sql`:
  - Corregido delimitador del bloque `DO` (`$do$ ... $do$`) para evitar error de sintaxis con `cron.schedule`.
- `docs/supabase_fix_oficial_sesiones_rls.sql`:
  - Nuevo fix dedicado para `oficial_sesiones`:
    - compatibilidad de columnas (`login_at`, `last_heartbeat`, `logout_at`),
    - normalizacion de estados (`ACTIVA/CERRADA/EXPIRADA/FORZADA` + legacy),
    - grants/policies RLS para `authenticated`/`anon`,
    - indices operativos por `id_oficial/device_id/last_heartbeat`.

### Movil (repo hermano)
- Ruta del repo movil: `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt`
- Objetivo aplicado:
  - Mantener reportes de control (cada 6 min) y reducir carga en segundo plano.
  - Evitar `SIN_SESION` por falta de heartbeat.
- Cambios principales:
  - `lib/data/repositories/supabase_repository.dart`:
    - Apertura/heartbeat/cierre de sesion operativa robustos.
    - Compatibilidad de estado: `ACTIVA/active`, `CERRADA`, `EXPIRADA`.
    - Recuperacion automatica de sesion cuando heartbeat no encuentra fila activa.
  - `lib/data/services/background_service.dart`:
    - Reportes ligeros para monitoreo (sin sensores pesados en background).
    - Poll de comunicaciones ajustado de `6s` a `25s` para menor consumo.
    - Tick de reporte en 1 min con rate-limit interno estricto de 6 min.
    - Heartbeat liviano periodico para sostener sesion operativa.
    - Se elimina corte duro por fuera de turno para evitar perdida total de trazas.

### Build generado
- APK debug mas reciente:
  - `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt\build\app\outputs\flutter-apk\app-debug.apk`
- Estado de compilacion:
  - `flutter analyze` OK
  - `flutter build apk --debug` OK

### Estado funcional al cierre
- `monitoreo_reportes` ingresa datos, pero durante pruebas hubo huecos grandes (no estable todavia para SLA estricto continuo).
- En pruebas previas hubo `estado_sla = SIN_SESION` por desalineacion de heartbeat/sesion.
- Se aplicaron fixes para sesion + vista SLA y queda validacion nocturna pendiente con el APK final.

### Checklist de arranque manana
1. Instalar APK debug mas reciente (ruta arriba).
2. Iniciar sesion una sola vez.
3. Dejar app minimizada y telefono bloqueado >= 12 min (sin abrir app).
4. Ejecutar:
   - `docs/supabase_smoke_test_5min.sql`
   - Query de `oficial_sesiones` (ultimo heartbeat)
   - Query de `v_sla_reportes_estado` por oficial
5. Si persiste `SIN_SESION`, aplicar fix SQL especifico de RLS/policies en `oficial_sesiones` (pendiente preparar script dedicado).

### Plan operativo del dia
- Checklist formal creada en:
  - `docs/CHECKLIST_SEGURIDAD_FIABILIDAD_2026-02-19.md`
  - Incluye pasos, criterios de "hecho" y validaciones SQL por bloque.

### Ajustes Android de fiabilidad (Tecno/Honor) - 19/02 madrugada-manana
- Inyectado canal nativo Android para controles de sistema:
  - `requestIgnoreBatteryOptimizations`
  - `isIgnoringBatteryOptimizations`
  - `openIgnoreBatteryOptimizationSettings`
  - `getRestrictBackgroundStatus` (Data Saver)
  - `openDataUsageSettings`
- Integrado en onboarding y validacion de prerrequisitos:
  - Solicitud explicita de "No optimizar bateria" (no solo `openAppSettings`).
  - Bloqueo guiado si hay restriccion de datos en segundo plano.
- Estado:
  - Foreground service ya estaba activo en manifiesto.
  - FCM push de alta prioridad aun pendiente (no existe `firebase_messaging` en el repo movil).

### Continuidad tecnica (movil) - 19/02 tarde
- Repo movil activo: `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt`
- Objetivo del bloque:
  - estabilizar segundo plano/notificaciones,
  - evitar duplicados aleatorios de reportes,
  - endurecer validacion de voz en partes.

#### Cambios implementados
- `android_alarm_manager_plus` inyectado como watchdog:
  - scheduler periodico y reprogramacion en reinicio.
  - callback forzado a `ensureServiceRunning + runOperationalSnapshotNow(force: true)`.
- Arranque robusto:
  - `main.dart` movido a bootstrap asincrono para evitar pantalla blanca por init bloqueante.
- `AndroidManifest.xml` completado con componentes de AlarmManager:
  - `AlarmService`, `AlarmBroadcastReceiver`, `RebootBroadcastReceiver`,
  - permiso `SCHEDULE_EXACT_ALARM`.
- Validaciones Android de datos de fondo:
  - cambiadas de bloqueo duro a advertencia cuando el fabricante no expone ajuste por app.
- Flujo de voz en partes (`home_screen.dart`):
  - reinicio de sesion de microfono,
  - locale dinamico para STT,
  - boton manual `REINICIAR MICROFONO`,
  - cierre y bloqueo de slot al 3er fallo en parte obligatorio,
  - modo biometrico directo para partes cuando `requireRealVoiceBiometricForPartes=true` (no depende de STT para aprobar).
- Segundo plano/notificaciones:
  - poll de comunicaciones reforzado en loop de 1 minuto,
  - `runOperationalSnapshotNow` inicializa notificaciones antes de poll,
  - diagnostico `bg_diag_status` extendido con `COMM_OK_Rx_Py`.
- Reportes operativos estabilizados:
  - envio por slot fijo de 6 minutos (anclado),
  - `id_reporte` deterministico por slot para evitar rafagas duplicadas,
  - `fecha_hora` alineada al inicio de slot,
  - marca `DELAY_xs` cuando el envio entra tarde.

#### Build
- APK debug vigente:
  - `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt\build\app\outputs\flutter-apk\app-debug.apk`
- Estado de calidad:
  - `flutter analyze` OK
  - `flutter build apk --debug` OK

#### Pendientes de validacion (proxima sesion)
1. Prueba controlada 12-15 min con app minimizada + telefono bloqueado.
2. Confirmar entrega de notificaciones (radio + parte sorpresa) en lockscreen.
3. Verificar SLA:
   - gap esperado ~360s (+ tolerancia),
   - sin duplicados `gap_sec=1` en `monitoreo_reportes`.
4. Revisar diagnostico footer:
   - `BG: COMM_OK_Rx_Py` o error puntual.

## 2026-02-18

### Hotfix Beta (RTC Radio A-B) - 17:06 (-04)
- Radio llamada migra de evento simulado a audio RTC real (WebRTC) entre supervisor y oficial.
- Señalizacion RTC implementada sobre `radio_mensajes` usando payload tecnico `__RTC__` con `tipo='RADIO'` para compatibilidad con constraints actuales.
- Webapp radio:
  - Inicio de llamada con negociacion `OFFER/ANSWER/ICE`.
  - Cierre remoto/local con `HANGUP`.
  - Estado visual de llamada (`NEGOCIANDO`, `AUDIO CONECTADO`, `FINALIZADA`).
- Bitacora `radio_llamadas` se mantiene para inicio/fin/duracion (sin almacenar audio).
- Limpieza UX:
  - Mensajes tecnicos RTC ocultos del chat visible.
  - Mensajes tecnicos RTC excluidos de badges/no leidos/notificaciones.
- Dependencia agregada: `flutter_webrtc: ^1.3.0`.
- Validacion: `flutter analyze` OK (webapp y movil).

### Added
- Nuevas vistas SQL para separar modulos web: `v_webapp_inconsistencias_logicas`, `v_webapp_telemetria_actual`, `v_webapp_alertas_operativas` en `docs/supabase_webapp_split_operativo.sql`.
- Bitacora de llamadas de radio (inicio/fin/duracion) en `docs/supabase_radio_llamadas_log.sql`.
- Flujo UI para iniciar/finalizar llamada de radio desde supervisor (`lib/presentation/widgets/supervisor_quick_actions.dart`) con respaldo a eventos `CALL_START/CALL_END`.
- Manual descriptivo completo por rol (Supervisor vs Comandante) en `docs/MANUAL_WEBAPP_SUPERVISOR_COMANDANTE.md`.
- Scripts SQL para desbloqueo y actualizacion de grados en oficiales:
  - `docs/supabase_fix_oficiales_supervisor_rls.sql`
  - `docs/supabase_update_grados_oficiales.sql`
  - `docs/supabase_migracion_grados_por_catalogo.sql`
  - `docs/supabase_fix_radio_mensajes_tipo_chk.sql`

### Changed
- Repositorio Supabase desacoplado por dominio:
  - Inconsistencias logicas separadas de alertas operativas.
  - Telemetria consumida desde vista dedicada y fallback controlado.
  - Alertas operativas con `motivo_alerta`, `tipo_alerta` y `severidad`.
- Dashboard supervisor ajustado para usar listas separadas (`alertasOperativas`, `telemetriaActual`, `inconsistencias`).
- Tarjetas de alertas y feed del mapa mejoradas para lectura rapida:
  - Muestra explicita de motivo.
  - Muestra explicita de distancia en metros.
  - Orden de prioridad por severidad y fecha.
- Alertas agrupadas y radio base priorizan no leidos:
  - Lista de alertas con "NUEVAS" primero.
  - Bandeja radio por oficial con badge por canal y prioridad visual.
- Logica de parte sorpresa en webapp ajustada a solicitud directa:
  - Se solicita parte al instante.
  - Chat y llamada quedan como opcion (no obligatorios).
- Chat de radio webapp distingue eventos formales de parte:
  - Tipo `PARTE_NOVEDAD` resaltado como "PARTE CON NOVEDAD".
- Vista de oficiales con semaforo operativo real (rojo/naranja/violeta) y priorizacion visual de oficiales con mayor riesgo.
- Etiquetado de inconsistencias enfocado en eventos logicos/forenses (voz/gps/foto/imei), evitando ruido operativo.
- Grados migrados a catalogo nominal en UI:
  - Tarjetas de perfil/listado ahora renderizan icono por nombre real de grado (no por indice numerico).
  - Formulario de `Gestionar Oficiales` usa lista de grados reales (`SARGENTO` ... `CORONEL`).
  - Compatibilidad hacia atras con grados numericos (`1..14`) durante transicion.
- Solicitud de parte sorpresa ahora dispara tambien evento de radio `CONTROL_SORPRESA`
  para notificacion inmediata en movil.
- Estabilidad de radio movil:
  - Reconexion automatica del stream de radio tras error/corte.
  - Reinicio forzado de canal radio al volver la app a primer plano.
  - Mensaje de error de radio con detalle resumido para diagnostico rapido.
- Compatibilidad de tipos en radio:
  - Fallback automatico a `tipo='RADIO'` cuando Supabase rechaza tipos nuevos por `radio_mensajes_tipo_chk`.
  - Script SQL para corregir constraint de `radio_mensajes.tipo` con catalogo completo.
- Separacion de modulos `Partes Sorpresa` vs `Radio`:
  - Webapp: se eliminó accion de `Parte Sorpresa` desde dialogo de radio.
  - Movil: el registro de parte (obligatorio/sorpresa) ya no envia eventos al chat radio.
  - Movil: unificacion de acceso en footer para abrir `PARTE SORPRESA` en la misma ventana de partes.
- UI de `Partes Sorpresa` web:
  - Dialogo mas compacto.
  - Tipografia y colores ajustados para alto contraste sobre fondo oscuro.

### Fixed
- Correcciones de tipado y consultas en `supabase_repository.dart` tras separar vistas/tablas.
- Ajustes de panel tecnico de telemetria para datos tipo `Map<String, dynamic>`.
- Validacion final sin errores:
  - `flutter analyze` OK
  - `flutter test` OK

### Cross-App Note (WebApp + Móvil)
- En app móvil (`C:\Users\sccpa\Desktop\sccp_mobile_rebuilt`) se dejó alineado el flujo de novedad:
  - Botón "PARTE CON NOVEDAD + ABRIR CHAT".
  - Registro formal como parte + aviso de radio `PARTE_NOVEDAD`.
  - `PARTE_NOVEDAD` con alerta sonora y visual diferenciada.
- Mapeo de grados alineado entre webapp y móvil:
  - Nuevo util `grado_assets.dart` en ambos proyectos para resolver `grado -> icono`.
  - Soporte de equivalencias (`SGTO`, `TTE`, `CNL`, numerico) a grado nominal canonico.

## 2026-02-17

### Added
- Capa analitica diaria/mensual para comandante con alcance `GLOBAL`, `POR GRUPO` e `INDIVIDUAL`.
- Integracion de `partes_oficiales` e `inconsistencias` en los KPIs de cumplimiento operativo.
- Documentacion operativa en `docs/monitoring_analytics_logic.md`.
- SQL de soporte en `docs/monitoring_analytics_schema.sql` (estadisticas + compatibilidad `login_logs`).
- Pipeline de analitica en tiempo real para dashboard supervisor con filtros por ventana operativa y ultimo reporte por oficial.

### Changed
- Panel avanzado de estadisticas ahora incluye selector de periodo `DIA/MES` y tercer tab `INDIVIDUAL`.
- KPIs ampliados: cobertura, cumplimiento de geocerca, cumplimiento de partes, inconsistencias abiertas/cerradas.
- Mapa tactico: se agrego base `DIPROVE` y se actualizo iconografia de pin institucional.
- Tarjeta y modal de estadisticas migrados a visualizacion predominantemente grafica con etiquetas tecnicas compactas (`RPT`, `ACT`, `COV`, `GEO50`, `RISK`, `DIST`, `BAT`, `ALT`).

## 2026-02-16

### Added
- Flujo de administracion de oficiales guiado por pasos en `lib/presentation/widgets/gestion_oficiales_dialog.dart`.
- Modo de operacion claro: `REGISTRAR`, `MODIFICAR`, `ELIMINAR`.
- Reemplazo rapido de oficial saliente/entrante con validacion por PIN.
- Documentacion persistente de memoria de trabajo en `docs/PROJECT_MEMORY_2026-02-16.md`.

### Changed
- Se elimino el uso de `turno` en el formulario de gestion y en acciones masivas del dialogo.
- En la lista de oficiales del dialogo se muestra `ID + GRUPO` para reducir ruido.
- Registro de reo mantiene ingreso manual (solo cuando se activa `REGISTRAR REO NUEVO`).
- Responsive del dashboard: PC intacto y movil apilado vertical con breakpoint adaptativo.

### Fixed
- Correcciones de estabilidad en el dialogo de gestion tras ajustes de flujo.
- Validaciones de seleccion para operaciones de modificar/eliminar y reemplazo.
