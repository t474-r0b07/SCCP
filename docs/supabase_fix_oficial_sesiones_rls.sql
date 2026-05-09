-- =========================================================
-- SCCP - FIX OFICIAL_SESIONES (COMPAT + RLS)
-- =========================================================
-- Objetivo:
-- 1) Alinear columnas legacy/canonicas de sesion operativa.
-- 2) Normalizar estados de sesion (ACTIVA/CERRADA/EXPIRADA/FORZADA).
-- 3) Desbloquear insert/update desde app movil (anon/authenticated).
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Columnas de compatibilidad (si faltan)
-- ---------------------------------------------------------
alter table if exists public.oficial_sesiones
  add column if not exists login_at timestamp with time zone,
  add column if not exists last_heartbeat timestamp with time zone,
  add column if not exists logout_at timestamp with time zone,
  add column if not exists updated_at timestamp with time zone not null default now();

-- ---------------------------------------------------------
-- 1) Backfill desde columnas legacy
-- ---------------------------------------------------------
update public.oficial_sesiones s
set login_at = coalesce(
  s.login_at,
  nullif(to_jsonb(s)->>'inicio_turno', '')::timestamp with time zone,
  nullif(to_jsonb(s)->>'created_at', '')::timestamp with time zone,
  now()
)
where s.login_at is null;

update public.oficial_sesiones s
set last_heartbeat = coalesce(
  s.last_heartbeat,
  nullif(to_jsonb(s)->>'heartbeat_at', '')::timestamp with time zone,
  s.login_at
)
where s.last_heartbeat is null;

update public.oficial_sesiones s
set logout_at = coalesce(
  s.logout_at,
  nullif(to_jsonb(s)->>'fin_turno', '')::timestamp with time zone
)
where s.logout_at is null
  and nullif(to_jsonb(s)->>'fin_turno', '') is not null;

-- ---------------------------------------------------------
-- 2) Normalizacion de estado
-- ---------------------------------------------------------
do $$
declare
  v_con record;
begin
  -- Elimina cualquier check legacy que valide estado con catalogo antiguo.
  for v_con in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.oficial_sesiones'::regclass
      and c.contype = 'c'
      and (
        lower(c.conname) like '%estado%'
        or pg_get_constraintdef(c.oid) ilike '%estado%'
      )
  loop
    execute format(
      'alter table public.oficial_sesiones drop constraint %I',
      v_con.conname
    );
  end loop;
end $$;

update public.oficial_sesiones
set estado = case upper(trim(coalesce(estado, '')))
  when 'ACTIVE' then 'ACTIVA'
  when 'CLOSED' then 'CERRADA'
  when 'EXPIRED' then 'EXPIRADA'
  when 'FORCED' then 'FORZADA'
  else coalesce(estado, 'ACTIVA')
end;

alter table public.oficial_sesiones
  add constraint oficial_sesiones_estado_check
  check (
    upper(trim(coalesce(estado, ''))) in (
      'ACTIVA', 'CERRADA', 'EXPIRADA', 'FORZADA',
      'ACTIVE', 'CLOSED', 'EXPIRED', 'FORCED'
    )
  );

-- ---------------------------------------------------------
-- 3) Indices operativos
-- ---------------------------------------------------------
create index if not exists idx_oficial_sesiones_oficial_device
  on public.oficial_sesiones(id_oficial, device_id);

create index if not exists idx_oficial_sesiones_last_heartbeat
  on public.oficial_sesiones(last_heartbeat desc);

create index if not exists idx_oficial_sesiones_activa
  on public.oficial_sesiones(id_oficial, device_id, last_heartbeat desc)
  where upper(trim(coalesce(estado, ''))) in ('ACTIVA', 'ACTIVE');

-- ---------------------------------------------------------
-- 4) Grants + RLS
-- ---------------------------------------------------------
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on public.oficial_sesiones to authenticated, anon;

alter table if exists public.oficial_sesiones enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'oficial_sesiones'
      and policyname = 'oficial_sesiones_select_auth_anon'
  ) then
    create policy oficial_sesiones_select_auth_anon
      on public.oficial_sesiones
      for select
      to authenticated, anon
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'oficial_sesiones'
      and policyname = 'oficial_sesiones_insert_auth_anon'
  ) then
    create policy oficial_sesiones_insert_auth_anon
      on public.oficial_sesiones
      for insert
      to authenticated, anon
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'oficial_sesiones'
      and policyname = 'oficial_sesiones_update_auth_anon'
  ) then
    create policy oficial_sesiones_update_auth_anon
      on public.oficial_sesiones
      for update
      to authenticated, anon
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'oficial_sesiones'
      and policyname = 'oficial_sesiones_delete_auth_anon'
  ) then
    create policy oficial_sesiones_delete_auth_anon
      on public.oficial_sesiones
      for delete
      to authenticated, anon
      using (true);
  end if;
end $$;

commit;

-- ---------------------------------------------------------
-- 5) Verificacion rapida
-- ---------------------------------------------------------
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename = 'oficial_sesiones'
order by policyname;

select
  id_sesion,
  id_oficial,
  device_id,
  estado,
  login_at,
  last_heartbeat,
  logout_at
from public.oficial_sesiones
order by coalesce(last_heartbeat, login_at) desc
limit 20;
