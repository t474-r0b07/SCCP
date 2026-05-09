-- =========================================================
-- SCCP - WEBAPP SPLIT OPERATIVO
-- =========================================================
-- Objetivo:
-- 1) Inconsistencias: solo lógicas/forenses.
-- 2) Telemetría: estado técnico actual por oficial.
-- 3) Alertas: operativas con motivo y severidad legible.
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- A) Inconsistencias lógicas (NO operativas)
-- ---------------------------------------------------------
create or replace view public.v_webapp_inconsistencias_logicas as
select i.*
from public.inconsistencias i
where upper(coalesce(i.tipo_inconsistencia, '')) in (
  'GPS_FALSO',
  'VOZ_NO_COINCIDE',
  'UBICACION_FOTO_NO_COINCIDE',
  'FOTO_UBICACION_NO_COINCIDE',
  'MANIPULACION_GPS',
  'COORDENADAS_IMPOSIBLES',
  'IMEI_CAMBIADO'
);

grant select on public.v_webapp_inconsistencias_logicas to authenticated, anon;

-- ---------------------------------------------------------
-- B) Telemetría actual (último reporte por oficial)
-- ---------------------------------------------------------
create or replace view public.v_webapp_telemetria_actual as
with latest as (
  select
    r.*,
    row_number() over (
      partition by r.id_oficial_ref
      order by r.fecha_hora desc
    ) as rn
  from public.monitoreo_reportes r
)
select
  l.id_reporte,
  l.id_oficial_ref,
  l.nombre_oficial,
  l.grupo,
  l.fecha_hora,
  l.nivel_bateria,
  l.gps_real,
  l.imei,
  l.estado_alerta,
  case
    when l.fecha_hora < now() - interval '10 minutes' then 'OFFLINE'
    else 'ONLINE'
  end as estado_dispositivo
from latest l
where l.rn = 1;

grant select on public.v_webapp_telemetria_actual to authenticated, anon;

-- ---------------------------------------------------------
-- C) Alertas operativas (motivo + tipo + severidad)
-- ---------------------------------------------------------
create or replace view public.v_webapp_alertas_operativas as
select
  r.id_reporte as id_alerta,
  r.id_oficial_ref,
  r.nombre_oficial,
  r.grupo,
  r.fecha_hora,
  r.estado_alerta,
  r.distancia_metros,
  r.nivel_bateria,
  r.gps_real,
  r.parte_novedad,
  case
    when coalesce(r.distancia_metros, 0) > 100
      or upper(coalesce(r.estado_alerta, '')) = 'CRITICO'
      then 3
    when coalesce(r.distancia_metros, 0) > 50
      or upper(coalesce(r.estado_alerta, '')) = 'ALERTA'
      then 2
    else 1
  end as severidad,
  case
    when coalesce(r.distancia_metros, 0) > 50 then 'ABANDONO_CONTROL'
    when upper(coalesce(r.parte_novedad, '')) not in ('', 'NINGUNA', 'SIN NOVEDAD') then 'INCUMPLIMIENTO_PARTE'
    when r.gps_real is false or coalesce(r.nivel_bateria, 100) < 20 then 'TELEMETRIA'
    else 'OPERATIVA'
  end as tipo_alerta,
  case
    when coalesce(r.distancia_metros, 0) > 50 then
      'FUERA DE RANGO (' || round(coalesce(r.distancia_metros, 0))::text || 'm)'
    when upper(coalesce(r.parte_novedad, '')) not in ('', 'NINGUNA', 'SIN NOVEDAD') then
      'PARTE/NOVEDAD'
    when r.gps_real is false then
      'GPS NO CONFIABLE'
    when coalesce(r.nivel_bateria, 100) < 20 then
      'BATERIA BAJA'
    when upper(coalesce(r.estado_alerta, '')) = 'CRITICO' then
      'ALERTA CRITICA'
    else
      'ALERTA OPERATIVA'
  end as motivo_alerta
from public.monitoreo_reportes r
where upper(coalesce(r.estado_alerta, 'NORMAL')) in ('ALERTA', 'CRITICO')
   or coalesce(r.distancia_metros, 0) > 50
   or r.gps_real is false
   or coalesce(r.nivel_bateria, 100) < 20
   or upper(coalesce(r.parte_novedad, '')) not in ('', 'NINGUNA', 'SIN NOVEDAD');

grant select on public.v_webapp_alertas_operativas to authenticated, anon;

commit;
