# Project Memory - 2026-02-16

## Estado funcional actual
- Supervisor y comandante separados por acceso.
- Dashboard con responsive adaptativo (desktop sin cambios, movil apilado).
- Gestion de oficiales simplificada para uso no tecnico.

## Decisiones de UX ya tomadas
- No usar selector de reo por lista para asignacion normal.
- Reo nuevo se registra manualmente y solo cuando se activa el switch correspondiente.
- Flujo recomendado para supervisor:
  1) Elegir operacion.
  2) Elegir grupo.
  3) Seleccionar oficial (si aplica).
  4) Guardar con PIN.
- No mostrar ni editar turnos (operacion de 24h).

## Archivos clave tocados hoy
- `lib/presentation/views/dashboard_view.dart`
- `lib/presentation/widgets/gestion_oficiales_dialog.dart`
- `CHANGELOG.md`
- `docs/PROJECT_MEMORY_2026-02-16.md`

## Pendientes sugeridos (proxima sesion)
- Ajustar textos finales y mensajes de confirmacion del dialogo segun lenguaje operativo policial.
- QA visual en movil real (2-3 modelos) para confirmar alturas ideales por tarjeta.
- Revisar si se desea ocultar/mostrar acciones masivas segun rol.
