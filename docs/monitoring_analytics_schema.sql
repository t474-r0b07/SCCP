-- =========================================================
-- SCCP MONITORING ANALYTICS + LOGIN LOG COMPAT
-- Inyectar en Supabase SQL Editor
-- =========================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- 1) Compatibilidad login_logs (sesiones administrativas web)
-- ---------------------------------------------------------
alter table public.login_logs
  add column if not exists session_id uuid default gen_random_uuid(),
  add column if not exists device_id text,
  add column if not exists actor_tipo text default 'ADMIN';

create index if not exists idx_login_logs_email_status
  on public.login_logs(admin_email, status, "timestamp" desc);

-- ---------------------------------------------------------
-- 2) Sesion operativa por oficial (app movil)
-- ---------------------------------------------------------
create table if not exists public.oficial_sesiones (
  id_sesion uuid primary key default gen_random_uuid(),
  id_oficial text not null references public.oficiales(id_oficial),
  imei text,
  device_id text,
  estado text not null default 'ACTIVA'
    check (estado in ('ACTIVA','CERRADA','EXPIRADA','FORZADA')),
  inicio_turno timestamp with time zone not null default now(),
  heartbeat_at timestamp with time zone,
  fin_turno timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create index if not exists idx_oficial_sesiones_oficial_estado
  on public.oficial_sesiones(id_oficial, estado);

create index if not exists idx_oficial_sesiones_heartbeat
  on public.oficial_sesiones(heartbeat_at desc);

-- ---------------------------------------------------------
-- 3) Funcion util: limites de periodo operativo
--    DIA: ventana 09:00 -> +24h
--    MES: desde primer dia del mes -> ahora
-- ---------------------------------------------------------
create or replace function public.fn_monitoring_period_bounds(
  p_period text default 'DIA',
  p_ref timestamp with time zone default now()
)
returns table (
  start_ts timestamp with time zone,
  end_ts timestamp with time zone,
  bucket_count integer
)
language plpgsql
stable
as $$
declare
  v_day_start timestamp with time zone;
begin
  if upper(coalesce(p_period,'DIA')) = 'DIA' then
    if extract(hour from p_ref) < 9 then
      v_day_start := date_trunc('day', p_ref - interval '1 day') + interval '9 hour';
    else
      v_day_start := date_trunc('day', p_ref) + interval '9 hour';
    end if;

    return query
    select v_day_start, v_day_start + interval '1 day', 24;
  else
    return query
    select date_trunc('month', p_ref), date_trunc('day', p_ref) + interval '1 day', extract(day from p_ref)::int;
  end if;
end;
$$;

-- ---------------------------------------------------------
-- 4) Funcion principal de estadisticas dashboard
--    Alcance: GLOBAL / GRUPO / OFICIAL
-- ---------------------------------------------------------
create or replace function public.fn_monitoring_dashboard_stats(
  p_period text default 'DIA',
  p_group text default null,
  p_oficial text default null,
  p_ref timestamp with time zone default now()
)
returns jsonb
language sql
stable
as $$
with bounds as (
  select * from public.fn_monitoring_period_bounds(p_period, p_ref)
),
scope_oficiales as (
  select o.id_oficial, o.grupo, o.activo
  from public.oficiales o
  where o.activo = true
    and (p_oficial is null or o.id_oficial = p_oficial)
    and (p_group is null or upper(o.grupo) = upper(p_group))
),
reportes as (
  select r.*
  from public.monitoreo_reportes r
  join scope_oficiales s on s.id_oficial = r.id_oficial_ref
  join bounds b on true
  where r.fecha_hora >= b.start_ts and r.fecha_hora < b.end_ts
),
incons as (
  select i.*
  from public.inconsistencias i
  join scope_oficiales s on s.id_oficial = i.id_oficial
  join bounds b on true
  where i.fecha_deteccion >= b.start_ts and i.fecha_deteccion < b.end_ts
),
partes as (
  select p.*
  from public.partes_oficiales p
  join scope_oficiales s on s.id_oficial = p.id_oficial
  join bounds b on true
  where p."timestamp" >= b.start_ts and p."timestamp" < b.end_ts
),
base_kpi as (
  select
    (select count(*) from reportes) as total_reportes,
    (select count(distinct id_oficial_ref) from reportes) as activos,
    (select count(*) from scope_oficiales) as nominales,
    coalesce((select avg(distancia_metros) from reportes),0)::numeric as distancia_prom,
    coalesce((select avg(case when coalesce(distancia_metros,0) <= 50 then 100 else 0 end) from reportes),0)::numeric as cumplimiento_geocerca,
    (select count(*) from partes where upper(coalesce(estado,'')) <> 'RECHAZADO' and upper(coalesce(resultado_voz,'')) <> 'RECHAZADO') as partes_ok,
    (select count(*) from incons where coalesce(resuelta,false) = false and upper(coalesce(estado,'')) <> 'CERRADA') as inconsistencias_abiertas,
    (select count(*) from incons where coalesce(resuelta,false) = true or upper(coalesce(estado,'')) = 'CERRADA') as inconsistencias_cerradas
),
partes_expected as (
  select
    case
      when upper(coalesce(p_period,'DIA')) = 'DIA' then 5
      else 5 * extract(day from p_ref)::int
    end * (select nominales from base_kpi) as expected_count
),
dist_buckets as (
  select jsonb_build_array(
    count(*) filter (where coalesce(distancia_metros,0) <= 50),
    count(*) filter (where coalesce(distancia_metros,0) > 50 and coalesce(distancia_metros,0) <= 100),
    count(*) filter (where coalesce(distancia_metros,0) > 100 and coalesce(distancia_metros,0) <= 200),
    count(*) filter (where coalesce(distancia_metros,0) > 200)
  ) as value
  from reportes
),
battery_buckets as (
  select jsonb_build_array(
    count(*) filter (where coalesce(nivel_bateria,0) <= 20),
    count(*) filter (where coalesce(nivel_bateria,0) > 20 and coalesce(nivel_bateria,0) <= 60),
    count(*) filter (where coalesce(nivel_bateria,0) > 60)
  ) as value
  from reportes
),
alert_type_buckets as (
  select jsonb_build_array(
    count(*) filter (
      where upper(coalesce(tipo_inconsistencia,'')) in ('DISTANCIA_EXCEDIDA','FUERA_ZONA','GPS_FALSO')
    ),
    count(*) filter (
      where upper(coalesce(tipo_inconsistencia,'')) not in ('DISTANCIA_EXCEDIDA','FUERA_ZONA','GPS_FALSO','FALTA_REPORTE')
    ),
    count(*) filter (where upper(coalesce(tipo_inconsistencia,'')) = 'FALTA_REPORTE')
  ) as value
  from incons
),
activity_series as (
  select jsonb_agg(cnt order by bucket) as value
  from (
    select g.bucket,
      coalesce(
        case
          when upper(coalesce(p_period,'DIA')) = 'DIA' then (
            select count(*)
            from reportes r
            where extract(hour from r.fecha_hora) = g.bucket
          )
          else (
            select count(*)
            from reportes r
            where extract(day from r.fecha_hora)::int = g.bucket + 1
          )
        end,
      0) as cnt
    from generate_series(
      0,
      case
        when upper(coalesce(p_period,'DIA')) = 'DIA' then 23
        else (select bucket_count - 1 from bounds)
      end
    ) as g(bucket)
  ) s
)
select jsonb_build_object(
  'periodo', upper(coalesce(p_period,'DIA')),
  'rango_inicio', (select start_ts from bounds),
  'rango_fin', (select end_ts from bounds),
  'total_reportes', (select total_reportes from base_kpi),
  'total_oficiales_activos', (select activos from base_kpi),
  'total_oficiales_nominales', (select nominales from base_kpi),
  'cobertura_pct',
    case
      when (select nominales from base_kpi) = 0 then 0
      else round(((select activos from base_kpi)::numeric / (select nominales from base_kpi)::numeric) * 100, 2)
    end,
  'cumplimiento_pct', round((select cumplimiento_geocerca from base_kpi), 2),
  'cumplimiento_partes_pct',
    case
      when (select expected_count from partes_expected) = 0 then 0
      else round(((select partes_ok from base_kpi)::numeric / (select expected_count from partes_expected)::numeric) * 100, 2)
    end,
  'partes_completados', (select partes_ok from base_kpi),
  'partes_esperados', (select expected_count from partes_expected),
  'inconsistencias_abiertas', (select inconsistencias_abiertas from base_kpi),
  'inconsistencias_cerradas', (select inconsistencias_cerradas from base_kpi),
  'distancia_promedio', round((select distancia_prom from base_kpi), 2),
  'distancia_buckets', (select value from dist_buckets),
  'alertas_tipo', (select value from alert_type_buckets),
  'bateria_buckets', (select value from battery_buckets),
  'actividad_horaria', (select value from activity_series)
);
$$;

-- ---------------------------------------------------------
-- Ejemplos:
-- select public.fn_monitoring_dashboard_stats('DIA', null, null, now());
-- select public.fn_monitoring_dashboard_stats('MES', 'ALFA', null, now());
-- select public.fn_monitoring_dashboard_stats('MES', null, 'OFI-001', now());
-- ---------------------------------------------------------
