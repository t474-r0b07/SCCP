# DTEX - Continuidad 2026-05-06

## Regla de trabajo

- SCCP actual funciona y no debe retroceder.
- No tocar radio, partes sorpresa, analitica comandante, telemetria ni flujo SCCP salvo entradas DTEX estrictamente controladas.
- Avance siguiente enfocado netamente en DTEX.

## Estado al cierre

- WebApp compila y sirve en local.
- Servidor local usado para prueba:
  - `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080`
  - URL: `http://127.0.0.1:8080`
  - Estado: detenido al cierre de jornada.
- `curl http://127.0.0.1:8080` devolvio HTML durante prueba.

## Cambios DTEX aplicados hoy

- Roles admin alineados:
  - `SUDO`
  - `SUPERVISOR`
  - `SUPERVISOR_DTEX`
  - compatibilidad mantenida con `DIRECTOR`, `ADMIN`, `ADMINISTRADOR`, `COMANDANTE`.
- `SUPERVISOR_DTEX` queda limitado a:
  - Diligencias DTEX,
  - Seguridad de Cuenta,
  - Cerrar Sesion.
- Comandante/SUDO tiene entrada DTEX desde header comandante.
- Estados DTEX centralizados:
  - `PENDIENTE`
  - `REGISTRO_REALIZADO`
  - `EN_RUTA`
  - `EN_DESTINO`
  - `RETORNANDO`
  - `CERRADA`
  - `EMERGENCIA`
  - `CANCELADA`
- `conducta_final` paso de texto libre a selector:
  - `SIN_INCIDENCIAS`
  - `CON_OBSERVACIONES`
  - `CON_INCIDENCIAS_GRAVES`
- Labels de alertas DTEX agregados:
  - `DESVIO`
  - `DETENIDO`
  - `UBICACION_APAGADA`
  - `INCONSISTENCIA`

## Archivos clave tocados

- `lib/data/models/allowed_admin_model.dart`
- `lib/presentation/controllers/auth_controller.dart`
- `lib/data/models/dtex_mision_model.dart`
- `lib/data/models/dtex_alerta_model.dart`
- `lib/data/repositories/dtex_repository.dart`
- `lib/presentation/controllers/dtex_controller.dart`
- `lib/presentation/views/dtex_view.dart`
- `lib/presentation/views/dashboard_view.dart`
- `lib/presentation/views/commander_dashboard_view.dart`
- `docs/supabase_dtex_schema_alignment.sql`
- `docs/dtex_qr_pwa_strategy.md`

## Validacion ejecutada

- `dart format` OK.
- `flutter analyze` sobre archivos tocados OK.
- `flutter analyze` completo OK.
- `flutter test` completo OK.
- Web server local levanto correctamente.

## Pendientes para manana

1. Revisar credenciales/roles de acceso:
   - El usuario anterior del operador no funciono durante la prueba.
   - Verificar en Supabase `auth.users` y `allowed_admins`.
   - Confirmar que el email usado exista en ambas capas y que `allowed_admins.activo = true`.
   - Confirmar `nivel_acceso` correcto: `SUDO`, `SUPERVISOR` o `SUPERVISOR_DTEX`.
2. Revisar/aplicar en Supabase, primero en staging si existe:
   - `docs/supabase_dtex_schema_alignment.sql`
   - especialmente `codigo_otp varchar(6)` y CHECK de estados/conducta.
3. Probar login con un usuario DTEX real.
4. Probar apertura de `Diligencias DTEX`.
5. Probar crear mision DTEX solo despues de validar schema.
6. Siguiente implementacion:
   - ruta aislada `/dtex/custodio`,
   - validacion OTP,
   - pantalla PWA temporal para custodio,
   - QR/link desde el panel DTEX.

## Prompt recomendado para retomar

```text
Retomamos en /home/kad-pmb/Documentos/sccp_command_center.
Regla principal: SCCP funciona y no debe romperse; avanzar netamente DTEX.
Leer primero CHANGELOG.md y docs/DTEX_CONTINUIDAD_2026-05-06.md.
Pendiente inmediato: resolver credenciales/roles de acceso DTEX porque el usuario anterior no funciono, revisar Supabase auth.users + allowed_admins, confirmar nivel_acceso SUDO/SUPERVISOR/SUPERVISOR_DTEX y activo=true. Luego validar/aplicar docs/supabase_dtex_schema_alignment.sql y probar creacion de mision. Siguiente feature: ruta aislada /dtex/custodio con OTP/QR/PWA temporal.
```

