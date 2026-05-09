# SCCP SESSION CHANGELOG - 2026-02-26

Fecha de corte: 2026-02-26 14:25 (America/La_Paz aprox)
Autor: Codex (sesion de correcciones criticas)
Build/compile: NO ejecutado por solicitud del usuario
Analisis: flutter analyze ejecutado en archivos tocados (OK)

## Estado global
- Codigo corregido en webapp y movil para los incidentes reportados.
- Estado real: IMPLEMENTADO + ANALIZADO, pendiente validacion en campo (dispositivos reales/red real).
- Respuesta corta a "todo hecho?": hecho en codigo casi todo lo pedido; falta confirmacion operativa de campo para cerrar al 100%.

## WEBAPP - Cambios implementados

### 1) Header y acciones (sin romper vista PC)
- Supervisor: acciones compactas por icono, sin boton gigante de texto en header.
- Director/Comandante: header con iconos compactos alineados (imprimir, parte sorpresa, radio, seguridad, cerrar sesion).
- Archivos:
  - lib/presentation/views/dashboard_view.dart
  - lib/presentation/views/commander_dashboard_view.dart

### 2) Cerrar sesion y UX de alertas
- Cierre de sesion visible y accesible en dashboards.
- Boton para "MARCAR TODAS VISTAS" en alertas.
- Archivos:
  - lib/presentation/views/dashboard_view.dart
  - lib/presentation/widgets/alertas_card.dart

### 3) Estado de partes e inconsistencias con explicacion
- Dialogo "Estado de Partes" para ver pendientes/cumplidos/vencidos.
- Inconsistencias con explicacion operativa (no solo etiqueta tecnica).
- Archivos:
  - lib/presentation/views/dashboard_view.dart
  - lib/presentation/views/inconsistencias_view.dart

### 4) Radio: notificacion grande en esquina/top de webapp
- Antes: solo badge/punto en icono en algunos casos.
- Ahora: al llegar mensaje de radio entrante, ademas de notificacion web, aparece alerta in-app grande tipo toast/snackbar superior.
- Se blindo bootstrap de notificaciones para no quedar "mudo".
- Archivos:
  - lib/presentation/controllers/dashboard_controller.dart
  - lib/core/services/browser_notification_web.dart

### 5) Responsive movil (sin romper desktop)
- Alertas: micrograficos redistribuidos, escalado mayor en vertical movil.
- Inconsistencias: micrograficos usan mas altura real, no quedan en media tarjeta.
- Mapa movil: rotacion bloqueada (solo drag + zoom).
- Login e Index splash: modo compacto/ultra-compacto para pantallas chicas.
- Archivos:
  - lib/presentation/widgets/alertas_card.dart
  - lib/presentation/views/inconsistencias_view.dart
  - lib/presentation/widgets/tactical_map.dart
  - lib/presentation/views/commander_dashboard_view.dart
  - lib/presentation/views/login_view.dart
  - lib/presentation/views/index_view.dart

### 6) Horas "del futuro" en web
- Correccion UTC -> hora local en parse/render de fechas de reportes/alertas/telemetria/inconsistencias.
- Archivos:
  - lib/data/models/monitoreo_reporte_model.dart
  - lib/presentation/controllers/dashboard_controller.dart
  - lib/presentation/widgets/telemetria_card.dart
  - lib/presentation/widgets/alertas_card.dart
  - lib/presentation/views/inconsistencias_view.dart

### 7) Reduccion de falsos "GPS falso" en web
- Heuristica de salto GPS sospechoso ahora ignora pares de puntos con gps_real=false.
- Archivo:
  - lib/presentation/controllers/dashboard_controller.dart

## MOVIL - Cambios implementados

### 1) Background resiliente y recuperacion automatica
- Watchdog: aunque falle levantar foreground service, el callback sigue intentando snapshot/catch-up.
- Snapshot ahora tambien dispara scheduler de partes + heartbeat refresh.
- Reanudacion inicia snapshot forzado para recuperar rapido.
- Archivos:
  - lib/data/services/alarm_watchdog_service.dart
  - lib/data/services/background_service.dart
  - lib/presentation/screens/home_screen.dart
  - lib/presentation/providers/auth_provider.dart

### 2) Cola/catch-up y latencia
- Ajustes de capacidad de cola y flush por ciclo.
- Flush de pendientes tambien en ciclos sin slots nuevos (evita depender de apertura manual).
- Polling de comunicaciones mas frecuente.
- Archivo:
  - lib/data/services/background_service.dart

### 3) Partes y notificaciones
- Control de replay para evitar tormenta de notificaciones antiguas al reconectar.
- Archivo:
  - lib/data/services/notification_service.dart

### 4) Voz primer inicio
- Regla de onboarding/voice enrollment endurecida para no saltar registro de voz cuando falta perfil.
- Archivo:
  - lib/presentation/providers/auth_provider.dart

### 5) Login logs a Supabase
- Normalizacion de estados para login_logs (evita fallos por estados no permitidos).
- Archivo:
  - lib/data/repositories/supabase_repository.dart

### 6) GPS falso (movil)
- Antes: 1 lectura con isMocked=true ya marcaba GPS_FALSO.
- Ahora: requiere confirmacion consecutiva (2 lecturas) para reducir falsos positivos.
- Archivo:
  - lib/data/services/background_service.dart

### 7) Cierre de app tras permisos/onboarding
- Se redujo arranque agresivo durante transicion de permisos para evitar cierre al volver de dialogs/settings.
- Archivo:
  - lib/presentation/providers/auth_provider.dart

## Validaciones ejecutadas en esta sesion
- Web: flutter analyze sobre archivos tocados -> OK
- Movil: flutter analyze sobre archivos tocados y varias corridas completas -> OK
- Build APK/Web: NO ejecutado (por solicitud explicita)

## Pendiente de validacion en campo (obligatorio)
1. Movil: dejar app minimizada/bloqueada > 90 min y verificar que reporta/recupera sin reapertura manual.
2. Movil: flujo primer login + permisos + onboarding de voz, confirmar que no se cierra.
3. Web: recibir radio desde movil y confirmar popup grande + badge.
4. Web: revisar que horas mostradas coinciden con hora local real (no "futuro").
5. Web movil: validar cards Alertas/Inconsistencias en varios telefonos (vertical).

## Si al reiniciar quieres continuar rapido
- Abrir este archivo y ejecutar pruebas de la seccion "Pendiente de validacion en campo".
- Si algun punto falla, reportar: hora exacta, oficial, captura, y ultimo estado visible en UI.

## Actualizacion de corte - 2026-02-26 14:43 (-04)

### Respuesta directa a "estan todas las correcciones hechas?"
- No se puede marcar 100% cerrado en campo todavia.
- Estado actual: implementado en codigo + `flutter analyze` en archivos criticos OK.
- Falta validacion operativa real para cerrar definitivo.

### Hecho confirmado en codigo (webapp + movil)
- Webapp: cierre de sesion visible en dashboards.
- Webapp: alerta radio entrante con popup in-app (no solo badge).
- Webapp: conversion de timestamps a hora local para evitar horas "futuro".
- Webapp: mejoras responsive movil sin forzar cambios destructivos en desktop.
- Webapp: boton para marcar alertas vistas.
- Movil: hardening de background/catch-up para reducir huecos de reportes.
- Movil: ajuste anti falsos positivos de GPS_FALSO (confirmacion consecutiva).
- Movil: ajuste de onboarding/voz primer inicio y estabilizacion de arranque.
- Movil: normalizacion de estados para login logs en Supabase.

### Pendiente de validar en campo (bloqueante para cierre)
1. App minimizada/bloqueada por 90 min sin reapertura manual: confirmar envio continuo y catch-up.
2. Primer inicio (permisos + voz): confirmar que no se cierra la app.
3. Webapp: confirmar popup grande de radio en produccion.
4. Supabase: confirmar que login/logout/modificaciones vuelven a registrarse de punta a punta.
5. Dashboard desktop (PC): confirmar layout final sin regresiones visuales.

### Nota de ejecucion
- No se ejecutaron builds en esta pasada por tu instruccion previa.

## Actualizacion critica movil - 2026-02-26 15:28 (-04)

- Se corrigió en `sccp_mobile_rebuilt` un incidente de reporte inicial degradado
  (`SIN_GPS_PERMISO_DENEGADO`) por orden de arranque previo a sesión operativa lista.
- Se implementó flag `operational_ready` para bloquear reportes/background
  hasta completar permisos/onboarding.
- Referencia detallada: `sccp_mobile_rebuilt/docs/SESSION_CHANGELOG_2026-02-26_codex.md`.

## Actualizacion continuidad - 2026-02-26 14:58 (-04)

### Pedido atendido en esta pasada
- Se documenta continuidad para retomar tras reinicio sin perder contexto.
- Se dejaron correcciones en progreso del dashboard (director/supervisor) con foco en:
  - desactivar rojo persistente de alertas cuando ya fueron revisadas,
  - eliminar nominal fijo `20` en estado operativo.

### Cambios de codigo aplicados ahora (webapp)
- `lib/presentation/widgets/alertas_card.dart`
  - estado de "alerta vista" unificado con `DashboardController` (ya no estado local aislado).
  - utiliza `alertAcknowledgementVersion` para refresco reactivo entre tarjetas.
  - clave de episodio alineada con la del controlador para evitar desincronizacion.
- `lib/presentation/widgets/estado_operativo_card.dart`
  - nominal esperado ahora toma el total real del grupo (`oficialesGrupo.length`), no hardcode `20`.
  - contador de riesgo usa alertas activas **no leidas**.
  - agregado boton `MARCAR TODAS VISTAS`.
  - al abrir un oficial desde el selector, marca vistas sus alertas activas relacionadas.

### Pendiente inmediato (siguiente bloque al volver)
1. `lib/presentation/views/commander_dashboard_view.dart`
   - mapa historico: mostrar hora por punto y tooltip de rango.
   - compactar puntos por umbral de 50 m para no ensuciar el mapa.
2. `lib/presentation/controllers/commander_controller.dart`
   - agregar helper para agrupar historial por desplazamiento (`>50m` abre nuevo tramo).
3. revisar visual del contador y estado de alerta en desktop y movil (sin romper layout PC).

### Compilacion/Build
- `flutter build` NO ejecutado en esta pasada.

## Actualizacion seguridad - 2026-02-27 11:15 (-04)

### Correccion 1/5 - PIN admin en modo fail-closed
- `verificarPinAdmin` ahora usa solo RPC `fn_verify_admin_pin`; se eliminó fallback inseguro contra `allowed_admins.pin_seguridad`.
- `actualizarPinAdmin` ahora usa solo RPC `fn_update_admin_pin_secure`; se eliminó update directo de `pin_seguridad` desde cliente.
- Se añadieron scripts de backend para endurecer PIN:
  - `docs/supabase_verify_admin_pin_rpc.sql` (soporte hash bcrypt + compatibilidad temporal plaintext)
  - `docs/supabase_update_admin_pin_secure_rpc.sql` (actualización hasheada con `pgcrypto`)

### Validacion
- `flutter analyze lib/data/repositories/supabase_repository.dart` -> OK

### Nota operativa
- Hasta desplegar RPCs en Supabase, el cambio de PIN queda bloqueado por seguridad (sin bypass inseguro).

## Actualizacion metricas - 2026-02-27 11:22 (-04)

### Correccion 4/5 - Calidad de indicadores en dashboard
- `lib/presentation/widgets/estado_operativo_card.dart`:
  - Ajustada cadencia de cumplimiento a 6 minutos (`10` reportes esperados por hora).
  - Corregida condición inalcanzable de inactividad (`missingReports >= 5` con base 4); ahora evalúa sobre base real y umbral operativo.
- `lib/presentation/widgets/detallado_perfil_oficial_dialog.dart`:
  - Eliminado historial de cumplimiento hardcodeado; ahora se calcula desde reportes/partes reales de los últimos 7 días.
  - Corregida cronología de actividad reciente: ya no se recorta antes de ordenar (se ordena todo y luego se muestra top 5).

### Validacion
- `flutter analyze lib/presentation/widgets/estado_operativo_card.dart lib/presentation/widgets/detallado_perfil_oficial_dialog.dart` -> OK

## Barrida integral - 2026-02-27 12:04 (-04)

### Alcance
- Revisión completa de lógica, sintaxis, flujo y nexos entre `mobile`, `command_center` y `shared`.

### Cambios aplicados (monitor/command_center)
- Se eliminó `pin_seguridad` del modelo `AllowedAdmin` para evitar exposición accidental de campo sensible en capa cliente.
  - Archivo: `lib/data/models/allowed_admin_model.dart`
- Se conectó `AppConstants.tableRadioMensajes/tableRadioLlamadas` al paquete compartido (`sccp_shared`) para alinear contrato de tablas.
  - Archivo: `lib/core/constants/app_constants.dart`

### Higiene de workspace
- Limpieza de artefactos generados (`build` y `.dart_tool`) en:
  - `sccp_mobile_rebuilt`
  - `sccp_command_center`
  - `sccp_suite/packages/sccp_shared`

### Validación
- `flutter analyze` completo en los tres proyectos: OK
- `flutter test` completo en los tres proyectos: OK

### Observación de nexo
- El paquete `sccp_shared` estaba declarado pero casi no consumido; se dejó enlazado explícitamente en constantes de radio para reducir drift entre apps.

## Ajuste iconos header web - 2026-02-27

- Corregido render de 2 iconos en acciones de header (Supervisor y Comandante) con variantes de mayor compatibilidad web:
  - `Icons.assignment_turned_in_rounded` -> `Icons.assignment_turned_in`
  - `Icons.multitrack_audio_rounded` -> `Icons.radio`
- Archivos:
  - `lib/presentation/views/dashboard_view.dart`
  - `lib/presentation/views/commander_dashboard_view.dart`
- Validación: `flutter analyze` OK en ambos archivos.
