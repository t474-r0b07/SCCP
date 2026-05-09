-- =========================================================
-- SCCP - SLA ESTRICTO DE REPORTES (6 MIN)
-- =========================================================
-- Objetivo:
-- 1) Medir en tiempo real si cada oficial ACTIVO tiene reporte reciente.
-- 2) Registrar inconsistencia automatica cuando se rompe el SLA.
-- 3) Evitar duplicados por ventana de control.
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Configuracion SLA
-- ---------------------------------------------------------
create table if not exists public.sla_configuracion (
  clave text primary key,
  valor_texto text,
  valor_num integer,
  updated_at timestamp with time zone not null default now()
);

insert into public.sla_configuracion (clave, valor_num)
values
  ('SLA_REPORTES_MINUTOS', 6),
  ('SLA_TOLERANCIA_SEGUNDOS', 45),
  ('SLA_HEARTBEAT_MAX_MINUTOS', 30)
on conflict (clave) do nothing;

-- ---------------------------------------------------------
-- 1) Vista de estado SLA por oficial activo
-- ---------------------------------------------------------
create or replace view public.v_sla_reportes_estado as
with cfg as (
  select
    coalesce((select valor_num from public.sla_configuracion where clave = 'SLA_REPORTES_MINUTOS'), 6) as sla_min,
    coalesce((select valor_num from public.sla_configuracion where clave = 'SLA_TOLERANCIA_SEGUNDOS'), 45) as tol_sec,
    coalesce((select valor_num from public.sla_configuracion where clave = 'SLA_HEARTBEAT_MAX_MINUTOS'), 30) as hb_max_min
),
sesiones_activas as (
  select
    trim(coalesce(s.id_oficial::text, '')) as id_oficial_norm,
    max(
      coalesce(
        nullif(to_jsonb(s)->>'last_heartbeat', '')::timestamp with time zone,
        nullif(to_jsonb(s)->>'heartbeat_at', '')::timestamp with time zone,
        nullif(to_jsonb(s)->>'updated_at', '')::timestamp with time zone,
        nullif(to_jsonb(s)->>'login_at', '')::timestamp with time zone
      )
    ) as last_heartbeat
from public.oficial_sesiones s
  where upper(trim(coalesce(s.estado, ''))) in ('ACTIVA', 'ACTIVE')
  group by trim(coalesce(s.id_oficial::text, ''))
),
universo as (
  select
    trim(coalesce(o.id_oficial::text, '')) as id_oficial,
    o.nombre_oficial,
    o.grupo,
    sa.last_heartbeat
  from public.oficiales o
  left join sesiones_activas sa
    on sa.id_oficial_norm = trim(coalesce(o.id_oficial::text, ''))
  where coalesce(o.activo, true) = true
),
ultimo_reporte as (
  select
    trim(coalesce(r.id_oficial_ref::text, '')) as id_oficial,
    max(r.fecha_hora) as last_report_at
  from public.monitoreo_reportes r
  group by trim(coalesce(r.id_oficial_ref::text, ''))
)
select
  u.id_oficial,
  u.nombre_oficial,
  u.grupo,
  u.last_heartbeat,
  ur.last_report_at,
  round(extract(epoch from (now() - ur.last_report_at))::numeric, 0) as age_report_sec,
  round(extract(epoch from (now() - u.last_heartbeat))::numeric, 0) as age_hb_sec,
  case
    when u.last_heartbeat is null then 'SIN_SESION'
    when u.last_heartbeat < now() - make_interval(mins => (select hb_max_min from cfg)) then 'SIN_HEARTBEAT'
    when ur.last_report_at is null then 'SIN_REPORTE'
    when ur.last_report_at < now() - make_interval(mins => (select sla_min from cfg))
         - make_interval(secs => (select tol_sec from cfg)) then 'FUERA_SLA'
    else 'OK'
  end as estado_sla
from universo u
left join ultimo_reporte ur on ur.id_oficial = u.id_oficial;

grant select on public.v_sla_reportes_estado to authenticated, anon;

-- ---------------------------------------------------------
-- 2) Funcion: registrar faltantes SLA (idempotente por ventana)
-- ---------------------------------------------------------
create or replace function public.fn_sla_reportes_registrar_faltantes(
  p_ref timestamp with time zone default now()
)
returns table (
  oficiales_evaluados integer,
  inconsistencias_insertadas integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sla_min integer := coalesce((select valor_num from public.sla_configuracion where clave = 'SLA_REPORTES_MINUTOS'), 6);
  v_tol_sec integer := coalesce((select valor_num from public.sla_configuracion where clave = 'SLA_TOLERANCIA_SEGUNDOS'), 45);
  v_eval integer := 0;
  v_ins integer := 0;
begin
  with candidatos as (
    select
      v.id_oficial,
      v.nombre_oficial,
      v.grupo,
      v.last_report_at,
      v.age_report_sec,
      v.estado_sla,
      date_trunc('minute', p_ref)
        - make_interval(mins => (extract(minute from p_ref)::int % greatest(v_sla_min, 1)))
        as ventana_control
    from public.v_sla_reportes_estado v
    where v.estado_sla in ('FUERA_SLA', 'SIN_REPORTE')
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
      c.id_oficial,
      'SLA_' || c.id_oficial || '_' || to_char(c.ventana_control, 'YYYYMMDDHH24MI'),
      'SIN_REPORTE_EN_VENTANA',
      'SLA reportes roto (' || c.estado_sla || ') | ultimo='
        || coalesce(to_char(c.last_report_at at time zone 'America/La_Paz', 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
        || ' | age_sec=' || coalesce(c.age_report_sec::text, 'NULL'),
      'ALTA',
      'EN_REVISION',
      p_ref,
      false
    from candidatos c
    where not exists (
      select 1
      from public.inconsistencias i
      where i.id_oficial = c.id_oficial
        and upper(coalesce(i.tipo_inconsistencia, '')) = 'SIN_REPORTE_EN_VENTANA'
        and coalesce(i.id_reporte, '') = 'SLA_' || c.id_oficial || '_' || to_char(c.ventana_control, 'YYYYMMDDHH24MI')
    )
    returning 1
  )
  select
    (select count(*) from public.v_sla_reportes_estado),
    coalesce((select count(*) from ins), 0)
  into v_eval, v_ins;

  return query select v_eval, v_ins;
end;
$$;

grant execute on function public.fn_sla_reportes_registrar_faltantes(timestamp with time zone)
to authenticated, anon;

-- ---------------------------------------------------------
-- 3) Wrapper para jobs/cron
-- ---------------------------------------------------------
create or replace function public.fn_sla_reportes_tick()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_eval integer := 0;
  v_ins integer := 0;
begin
  select oficiales_evaluados, inconsistencias_insertadas
    into v_eval, v_ins
  from public.fn_sla_reportes_registrar_faltantes(now());

  return jsonb_build_object(
    'ok', true,
    'evaluados', v_eval,
    'insertadas', v_ins,
    'ts', now()
  );
end;
$$;

grant execute on function public.fn_sla_reportes_tick() to authenticated, anon;

commit;

-- ---------------------------------------------------------
-- 4) Verificacion rapida
-- ---------------------------------------------------------
select *
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
limit 100;

select *
from public.fn_sla_reportes_registrar_faltantes(now());
