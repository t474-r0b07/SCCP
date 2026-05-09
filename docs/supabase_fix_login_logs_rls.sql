-- =========================================================
-- SCCP - FIX LOGIN_LOGS (RLS + COMPAT)
-- =========================================================
-- Objetivo:
-- 1) Garantizar insercion/actualizacion de auditoria de sesiones.
-- 2) Habilitar acceso controlado desde webapp y app movil (auth/anon).
-- 3) Normalizar status para evitar rechazos por constraints legacy.
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Compatibilidad minima de columnas
-- ---------------------------------------------------------
alter table if exists public.login_logs
  add column if not exists actor_tipo text default 'ADMIN',
  add column if not exists session_id uuid,
  add column if not exists device_id text,
  add column if not exists metadata jsonb default '{}'::jsonb;

-- ---------------------------------------------------------
-- 1) Normalizacion de estado
-- ---------------------------------------------------------
update public.login_logs
set status = lower(coalesce(status, 'active'));

do $$
declare
  v_con record;
begin
  for v_con in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.login_logs'::regclass
      and c.contype = 'c'
      and (
        lower(c.conname) like '%status%'
        or pg_get_constraintdef(c.oid) ilike '%status%'
      )
  loop
    execute format('alter table public.login_logs drop constraint %I', v_con.conname);
  end loop;
end $$;

alter table public.login_logs
  add constraint login_logs_status_chk
  check (status in ('active', 'logout', 'expired', 'forced'));

-- ---------------------------------------------------------
-- 2) Index operativo
-- ---------------------------------------------------------
create index if not exists idx_login_logs_admin_status_ts
  on public.login_logs(admin_email, status, "timestamp" desc);

-- ---------------------------------------------------------
-- 3) Grants + RLS
-- ---------------------------------------------------------
grant usage on schema public to authenticated, anon;
grant select, insert, update on public.login_logs to authenticated, anon;

alter table if exists public.login_logs enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'login_logs'
      and policyname = 'login_logs_select_auth_anon'
  ) then
    create policy login_logs_select_auth_anon
      on public.login_logs
      for select
      to authenticated, anon
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'login_logs'
      and policyname = 'login_logs_insert_auth_anon'
  ) then
    create policy login_logs_insert_auth_anon
      on public.login_logs
      for insert
      to authenticated, anon
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'login_logs'
      and policyname = 'login_logs_update_auth_anon'
  ) then
    create policy login_logs_update_auth_anon
      on public.login_logs
      for update
      to authenticated, anon
      using (true)
      with check (true);
  end if;
end $$;

commit;

-- ---------------------------------------------------------
-- 4) Verificacion rapida
-- ---------------------------------------------------------
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename = 'login_logs'
order by policyname;

