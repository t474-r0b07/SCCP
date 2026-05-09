-- DTEX - escalamiento de alertas a inconsistencias administrativas.
--
-- Objetivo:
-- - Convertir alertas DTEX graves o no resueltas en filas de
--   public.inconsistencias para que entren al flujo administrativo del
--   supervisor.
-- - Evitar duplicados usando id_reporte = 'DTEX_ALERT_' || id_alerta.
--
-- Ejecutar despues de:
-- 1. docs/supabase_dtex_schema_alignment.sql
-- 2. docs/supabase_dtex_custodio_public_rpc.sql

begin;

create or replace view public.v_dtex_alertas_inconsistencia_candidatas as
select
  a.id_alerta,
  a.id_mision,
  a.ts,
  upper(coalesce(a.tipo, 'INCONSISTENCIA')) as tipo,
  upper(coalesce(a.severidad, 'AVISO')) as severidad,
  a.descripcion,
  a.latitud,
  a.longitud,
  coalesce(a.resuelta, false) as resuelta,
  m.custodio_codigo,
  m.custodio_nombre,
  m.custodio_grado,
  m.destino_nombre,
  m.estado as estado_mision,
  case
    when upper(coalesce(a.severidad, '')) = 'EMERGENCIA' then 'CRITICA'
    when upper(coalesce(a.tipo, '')) in (
      'UBICACION_APAGADA',
      'BATERIA_CRITICA',
      'APP_SUSPENDIDA',
      'PARADA_NO_AUTORIZADA'
    ) then 'ALTA'
    when upper(coalesce(a.tipo, '')) in (
      'DESVIO_RUTA',
      'GPS_PRECISION_BAJA',
      'SIN_CONEXION'
    ) then 'MEDIA'
    else 'BAJA'
  end as prioridad_sugerida
from public.dtex_alertas a
join public.dtex_misiones m
  on m.id_mision = a.id_mision
where coalesce(a.resuelta, false) = false;

grant select on public.v_dtex_alertas_inconsistencia_candidatas
  to anon, authenticated;

create or replace function public.fn_dtex_alertas_registrar_inconsistencias(
  p_ref timestamptz default now(),
  p_min_age_minutes integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_evaluadas integer := 0;
  v_insertadas integer := 0;
begin
  with candidatas as (
    select *
    from public.v_dtex_alertas_inconsistencia_candidatas c
    where
      c.severidad = 'EMERGENCIA'
      or c.prioridad_sugerida in ('CRITICA', 'ALTA')
      or c.ts <= p_ref - make_interval(mins => greatest(p_min_age_minutes, 0))
  ),
  ins as (
    insert into public.inconsistencias (
      id_oficial,
      id_reporte,
      tipo_inconsistencia,
      descripcion,
      prioridad,
      estado,
      fecha_deteccion,
      resuelta
    )
    select
      coalesce(nullif(trim(c.custodio_codigo), ''), c.custodio_nombre),
      'DTEX_ALERT_' || c.id_alerta::text,
      'DTEX_' || c.tipo,
      'DTEX alerta ' || c.tipo
        || ' | severidad=' || c.severidad
        || ' | custodio=' || coalesce(c.custodio_grado || ' ', '') || c.custodio_nombre
        || ' | destino=' || coalesce(c.destino_nombre, 'N/D')
        || ' | estado_mision=' || coalesce(c.estado_mision, 'N/D')
        || ' | descripcion=' || coalesce(c.descripcion, ''),
      c.prioridad_sugerida,
      'EN_REVISION',
      coalesce(c.ts, p_ref),
      false
    from candidatas c
    where not exists (
      select 1
      from public.inconsistencias i
      where coalesce(i.id_reporte, '') = 'DTEX_ALERT_' || c.id_alerta::text
    )
    returning 1
  )
  select
    (select count(*) from candidatas),
    coalesce((select count(*) from ins), 0)
  into v_evaluadas, v_insertadas;

  return jsonb_build_object(
    'ok', true,
    'alertas_evaluadas', v_evaluadas,
    'inconsistencias_insertadas', v_insertadas
  );
end;
$$;

grant execute on function public.fn_dtex_alertas_registrar_inconsistencias(
  timestamptz,
  integer
) to anon, authenticated;

commit;

-- Verificacion rapida:
-- select * from public.v_dtex_alertas_inconsistencia_candidatas
-- order by ts desc
-- limit 20;
--
-- select public.fn_dtex_alertas_registrar_inconsistencias(now(), 0);
--
-- select id_oficial, id_reporte, tipo_inconsistencia, prioridad, estado, fecha_deteccion
-- from public.inconsistencias
-- where coalesce(id_reporte, '') like 'DTEX_ALERT_%'
-- order by fecha_deteccion desc
-- limit 20;
