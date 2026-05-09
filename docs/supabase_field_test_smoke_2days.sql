-- SCCP - SMOKE TEST CAMPO (2 dias)
-- Ejecutar despues de deploy y despues del reset.

-- 1) Ultimos reportes recibidos
select
  id_reporte,
  id_oficial_ref,
  fecha_hora,
  estado_alerta,
  nivel_bateria,
  gps_real
from public.monitoreo_reportes
order by fecha_hora desc
limit 20;

-- 2) Estado de sesiones activas
select
  count(*) as sesiones_activas
from public.oficial_sesiones
where upper(coalesce(estado, '')) in ('ACTIVA', 'ACTIVE');

-- 3) Partes oficiales recientes (excluye eventos VOZ_ de registro)
-- Compatible con esquemas que usan:
--   - id_oficial_ref o id_oficial
--   - fecha_hora o timestamp
--   - tipo_parte o tipo
select
  (to_jsonb(p) ->> 'id_reporte') as id_reporte,
  coalesce(
    to_jsonb(p) ->> 'id_oficial_ref',
    to_jsonb(p) ->> 'id_oficial'
  ) as id_oficial_ref,
  coalesce(
    to_jsonb(p) ->> 'fecha_hora',
    to_jsonb(p) ->> 'timestamp'
  ) as fecha_hora,
  coalesce(
    to_jsonb(p) ->> 'tipo_parte',
    to_jsonb(p) ->> 'tipo'
  ) as tipo_parte,
  coalesce(
    to_jsonb(p) ->> 'resultado_voz',
    to_jsonb(p) ->> 'estado_voz'
  ) as resultado_voz
from public.partes_oficiales p
where coalesce(to_jsonb(p) ->> 'id_reporte', '') not like 'VOZ_%'
order by coalesce(
  nullif(to_jsonb(p) ->> 'fecha_hora', '')::timestamptz,
  nullif(to_jsonb(p) ->> 'timestamp', '')::timestamptz
) desc nulls last
limit 20;

-- 4) Inconsistencias abiertas
select
  id_inconsistencia,
  id_oficial,
  tipo_inconsistencia,
  estado,
  fecha_deteccion
from public.inconsistencias
where upper(coalesce(estado, '')) in ('ABIERTA', 'EN_REVISION')
order by fecha_deteccion desc
limit 30;

-- 5) Login logs recientes
select
  id_log,
  admin_email,
  status,
  timestamp,
  duracion_minutos
from public.login_logs
order by timestamp desc
limit 30;

-- 6) SLA (informativo)
-- Esta vista no se limpia con TRUNCATE. Refleja estado actual de oficiales activos.
select
  id_oficial,
  estado_sla,
  age_report_sec,
  age_hb_sec,
  last_report_at,
  last_heartbeat
from public.v_sla_reportes_estado
order by age_report_sec desc nulls last
limit 30;
