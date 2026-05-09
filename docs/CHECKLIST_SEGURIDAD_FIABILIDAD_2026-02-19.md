# SCCP - Checklist Seguridad y Fiabilidad (2026-02-19)

Estado objetivo: cerrar estabilidad de segundo plano y elevar seguridad operativa.

## 0) Base Operativa (bloqueante)
- [ ] Ejecutar `docs/supabase_fix_oficial_sesiones_rls.sql`.
- [ ] Ejecutar `docs/supabase_sla_reportes_estricto.sql`.
- [ ] Confirmar cron activo con `docs/supabase_sla_reportes_cron.sql`.
- [ ] Validar en un oficial de prueba que `estado=ACTIVA` y `hb_age_sec < 120` tras login.

Criterio de hecho:
- Sin errores SQL.
- `v_sla_reportes_estado` responde y no marca `SIN_SESION` inmediatamente después de login.

## 1) Segundo plano estricto (SLA 6 min)
- [ ] Instalar APK debug vigente en móvil de prueba.
- [ ] Login una vez, esperar 1 min en primer plano.
- [ ] Prueba A: app minimizada 12 min.
- [ ] Prueba B: app minimizada + pantalla bloqueada 12 min.
- [ ] Ejecutar smoke test y query de gaps.

Criterio de hecho:
- Brecha máxima entre reportes <= `6 min + 45 s` en ventana de prueba.
- `estado_sla` del oficial en `OK` o sin `SIN_SESION`.

Validación SQL:
```sql
select now(), id_sesion, id_oficial, estado, login_at, last_heartbeat,
round(extract(epoch from (now()-last_heartbeat))) as hb_age_sec
from public.oficial_sesiones
where id_oficial='ID_PRUEBA'
order by coalesce(last_heartbeat, login_at) desc
limit 1;
```

```sql
select id_oficial, estado_sla, age_report_sec, age_hb_sec, last_report_at, last_heartbeat
from public.v_sla_reportes_estado
where id_oficial='ID_PRUEBA';
```

## 2) FCM push para eventos críticos
- [ ] Configurar Firebase proyecto Android (google-services + token).
- [ ] Registrar token FCM por oficial/dispositivo.
- [ ] Enviar push desde backend para:
- [ ] `PARTE_SORPRESA`
- [ ] `FALTA_REPORTE`
- [ ] `ALERTA_OPERATIVA`
- [ ] Mantener polling como fallback temporal.

Criterio de hecho:
- Evento crítico llega con app bloqueada sin depender de abrir app.
- Latencia p95 <= 10 s en red normal.

## 3) Evidencia server-side (hash + HMAC)
- [ ] Definir payload canónico de evidencia.
- [ ] Firmar payload en app con HMAC.
- [ ] Verificar firma y completitud en backend.
- [ ] Registrar `validation_hash`, payload normalizado, timestamp servidor.
- [ ] Si inválido/incompleto, insertar inconsistencia automática.

Criterio de hecho:
- Toda evidencia queda auditada con firma verificable.
- Evidencia inválida genera inconsistencia sin intervención manual.

## 4) Challenge de voz dinámico por parte
- [ ] Generar frase aleatoria por solicitud de parte.
- [ ] Mostrar challenge único por solicitud.
- [ ] Validar coincidencia con challenge.
- [ ] Mantener 3 fallos => cierre + `POSIBLE_SUPLANTACION`.

Criterio de hecho:
- No se acepta parte con frase fija reutilizable.
- 3 fallos consecutivos cierran flujo e informan inconsistencia.

## 5) Hardening anti-manipulación
- [ ] Integrar Play Integrity.
- [ ] Reportar flags: root, debug, mock-location, integridad.
- [ ] Evaluar riesgo en backend (score).
- [ ] Si riesgo alto: alerta naranja automática.

Criterio de hecho:
- Riesgo de manipulación visible en backend y trazable por oficial.
- Disparadores automáticos de alerta por riesgo alto.

## 6) Cierre de sprint (aceptación)
- [ ] Ejecutar `docs/supabase_smoke_test_5min.sql` completo.
- [ ] Verificar checklist de notificaciones con app bloqueada.
- [ ] Verificar SLA 6 min con oficial de prueba.
- [ ] Registrar resultados finales en `CHANGELOG.md`.

Resultado esperado:
- Fiabilidad operativa >= 85% en pruebas reales.
- Seguridad operativa con controles automáticos de evidencia y voz.
