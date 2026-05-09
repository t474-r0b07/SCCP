# GUIA DE CONTINUIDAD POST REINICIO

Fecha: 2026-02-26
Objetivo: retomar rapido el trabajo sin perder estado ni volver atras.

## 1) Abrir y validar contexto

1. Abrir VSCode en:
   - `C:\Users\sccpa\Desktop\sccp_command_center`
   - `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt`
2. Leer primero:
   - `docs/SESSION_CHANGELOG_2026-02-26_codex.md` (webapp)
   - `C:\Users\sccpa\Desktop\sccp_mobile_rebuilt\docs\SESSION_CHANGELOG_2026-02-26_codex.md` (movil)
3. Confirmar archivos tocados en webapp:
   - `lib/presentation/widgets/alertas_card.dart`
   - `lib/presentation/widgets/estado_operativo_card.dart`
   - (pendiente siguiente bloque) `lib/presentation/views/commander_dashboard_view.dart`
   - (pendiente siguiente bloque) `lib/presentation/controllers/commander_controller.dart`

## 2) Continuar el bloque pendiente (director mapa historico)

1. Implementar compactacion de historial por desplazamiento:
   - regla: mientras la variacion entre reportes consecutivos sea `<= 50 m`, agrupar.
   - si supera `50 m`, abrir nuevo punto/tramo.
2. Mostrar en mapa:
   - hora/rango de hora por punto,
   - cantidad de reportes agrupados por punto.
3. Mantener:
   - drag + zoom en movil,
   - sin romper distribucion desktop.

## 3) Validaciones minimas (sin build)

Ejecutar solo analisis:

```bash
cd C:\Users\sccpa\Desktop\sccp_command_center
flutter analyze lib/presentation/widgets/alertas_card.dart
flutter analyze lib/presentation/widgets/estado_operativo_card.dart
flutter analyze lib/presentation/controllers/commander_controller.dart
flutter analyze lib/presentation/views/commander_dashboard_view.dart
```

No ejecutar `flutter build` en esta etapa.

## 4) QA funcional rapido (manual)

1. Dashboard supervisor/director:
   - abrir alertas, marcar vistas, confirmar que el estado rojo baja.
2. Estado operativo:
   - verificar que contador use nominal real del grupo (ej. `2/18`, no `2/20` fijo).
3. Mapa historico director:
   - confirmar menos puntos visuales cuando no hay movimiento real.
   - confirmar que al pasar por punto se vea hora/rango.

## 5) Criterio de cierre de este bloque

Bloque cerrado cuando:
- alertas vistas se reflejan en todas las tarjetas,
- contador no usa hardcode,
- mapa historico muestra hora y compresion por 50 m,
- `flutter analyze` en archivos tocados queda limpio.
