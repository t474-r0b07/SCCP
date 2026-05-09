-- =========================================================
-- SCCP - SMOKE TEST OPERATIVO (5 MINUTOS)
-- =========================================================
-- Flujo sugerido:
-- 1) Ejecuta este script (baseline).
-- 2) Desde webapp/app haz 3 acciones:
--    a) editar y guardar 1 oficial,
--    b) enviar 1 mensaje de radio,
--    c) registrar 1 parte o generar 1 reporte operativo.
-- 3) Ejecuta de nuevo este script y compara resultados.

-- ---------------------------------------------------------
-- 0) Contexto temporal
-- ---------------------------------------------------------
select
  now() as now_server_tz,
  now() at time zone 'UTC' as now_utc,
  now() at time zone 'America/La_Paz' as now_bolivia,
  current_setting('TimeZone') as db_timezone;

-- ---------------------------------------------------------
-- 1) Radio (debe mostrar nuevos mensajes)
-- ---------------------------------------------------------
select
  id_mensaje,
  id_oficial,
  de_usuario,
  para_usuario,
  mensaje,
  tipo,
  estado,
  "timestamp",
  "timestamp" at time zone 'America/La_Paz' as timestamp_bolivia,
  round(extract(epoch from (now() - "timestamp"))::numeric, 0) as age_sec
from public.radio_mensajes
order by "timestamp" desc
limit 30;

-- ---------------------------------------------------------
-- 1.1) Llamadas de radio (bitácora inicio/fin/duración)
-- ---------------------------------------------------------
select
  id_llamada,
  id_oficial,
  de_usuario,
  para_usuario,
  inicio_llamada,
  inicio_llamada at time zone 'America/La_Paz' as inicio_bolivia,
  fin_llamada,
  fin_llamada at time zone 'America/La_Paz' as fin_bolivia,
  duracion_segundos,
  estado,
  resumen,
  round(extract(epoch from (now() - inicio_llamada))::numeric, 0) as age_sec
from public.radio_llamadas
order by inicio_llamada desc
limit 30;

-- ---------------------------------------------------------
-- 2) Reportes operativos (monitoreo)
-- ---------------------------------------------------------
select
  id_reporte,
  id_oficial_ref,
  fecha_hora,
  fecha_hora at time zone 'America/La_Paz' as fecha_hora_bolivia,
  estado_alerta,
  grupo,
  imei,
  round(extract(epoch from (now() - fecha_hora))::numeric, 0) as age_sec
from public.monitoreo_reportes
order by fecha_hora desc
limit 30;

-- ---------------------------------------------------------
-- 3) Partes oficiales (excluye VOZ_*)
-- ---------------------------------------------------------
select
  id_reporte,
  id_oficial,
  "timestamp",
  "timestamp" at time zone 'America/La_Paz' as timestamp_bolivia,
  resultado_voz,
  estado,
  novedad,
  round(extract(epoch from (now() - "timestamp"))::numeric, 0) as age_sec
from public.partes_oficiales
where id_reporte not like 'VOZ_%'
order by "timestamp" desc
limit 30;

-- ---------------------------------------------------------
-- 4) Inconsistencias recientes
-- ---------------------------------------------------------
select
  id_inconsistencia,
  id_oficial,
  tipo_inconsistencia,
  descripcion,
  prioridad,
  estado,
  fecha_deteccion,
  fecha_deteccion at time zone 'America/La_Paz' as fecha_bolivia,
  round(extract(epoch from (now() - fecha_deteccion))::numeric, 0) as age_sec
from public.inconsistencias
order by fecha_deteccion desc
limit 30;

-- ---------------------------------------------------------
-- 5) Sesiones activas
-- ---------------------------------------------------------
select
  id_sesion,
  id_oficial,
  device_id,
  estado,
  login_at,
  login_at at time zone 'America/La_Paz' as login_at_bolivia,
  last_heartbeat,
  last_heartbeat at time zone 'America/La_Paz' as hb_bolivia,
  round(extract(epoch from (now() - last_heartbeat))::numeric, 0) as hb_age_sec
from public.oficial_sesiones
order by last_heartbeat desc
limit 30;

-- ---------------------------------------------------------
-- 6) Checks de salud (deben ser 0)
-- ---------------------------------------------------------
select count(*) as reportes_futuros
from public.monitoreo_reportes
where fecha_hora > now() + interval '10 minutes';

select count(*) as inconsistencias_futuras
from public.inconsistencias
where fecha_deteccion > now() + interval '10 minutes';

-- ---------------------------------------------------------
-- 7) Resumen ultima hora
-- ---------------------------------------------------------
select
  count(*) as reportes_ultima_hora
from public.monitoreo_reportes
where fecha_hora >= now() - interval '1 hour';

select
  count(*) as radios_ultima_hora
from public.radio_mensajes
where "timestamp" >= now() - interval '1 hour';

select
  count(*) as llamadas_ultima_hora
from public.radio_llamadas
where inicio_llamada >= now() - interval '1 hour';

select
  count(*) as partes_ultima_hora
from public.partes_oficiales
where "timestamp" >= now() - interval '1 hour'
  and id_reporte not like 'VOZ_%';

-- ---------------------------------------------------------
-- 8) SLA estricto reportes (si script SLA aplicado)
-- ---------------------------------------------------------
select
  id_oficial,
  nombre_oficial,
  grupo,
  estado_sla,
  age_report_sec,
  age_hb_sec,
  last_report_at,
  last_heartbeat
from public.v_sla_reportes_estado
order by
  case estado_sla
    when 'FUERA_SLA' then 1
    when 'SIN_REPORTE' then 2
    when 'SIN_HEARTBEAT' then 3
    when 'SIN_SESION' then 4
    else 9
  end,
  age_report_sec desc nulls last
limit 50;
