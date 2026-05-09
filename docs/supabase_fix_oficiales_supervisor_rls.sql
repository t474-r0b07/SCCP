-- =========================================================
-- SCCP - FIX OFICIALES (RLS + TRIGGER CATALOGO)
-- =========================================================
-- Objetivo:
-- 1) Permitir actualizar catalogo de oficiales desde supervisor/director.
-- 2) Mantener update de IMEI desde app movil.
-- 3) Evitar bloqueos por RLS mal configurado.
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Helper de autorizacion (si no existe)
-- ---------------------------------------------------------
create or replace function public.fn_is_management_actor()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''));
  v_role text := upper(coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), ''));
  v_ok boolean := false;
begin
  -- SQL Editor/migraciones (sin JWT): permitido
  if v_role = '' and v_email = '' then
    return true;
  end if;

  if v_role = 'SERVICE_ROLE' then
    return true;
  end if;

  if v_email = '' then
    return false;
  end if;

  -- Evita fallo de compilacion/ejecucion si la tabla aun no existe.
  if to_regclass('public.allowed_admins') is null then
    return false;
  end if;

  execute $sql$
    select exists (
      select 1
      from public.allowed_admins a
      where lower(a.email) = $1
        and coalesce(a.activo, true) = true
        and upper(coalesce(a.nivel_acceso, 'SUPERVISOR')) in ('SUPERVISOR', 'DIRECTOR')
    )
  $sql$
  into v_ok
  using v_email;

  return v_ok;
end;
$$;

-- ---------------------------------------------------------
-- 1) Trigger de control catalogo oficiales
-- ---------------------------------------------------------
create or replace function public.trg_guard_oficiales_catalogo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if not public.fn_is_management_actor() then
      raise exception 'Operacion no autorizada: alta de oficial solo por supervisor/director';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    if not public.fn_is_management_actor() then
      raise exception 'Operacion no autorizada: baja de oficial solo por supervisor/director';
    end if;
    return old;
  end if;

  -- UPDATE
  -- IMEI queda fuera para permitir vinculacion desde app movil.
  if (
       new.nombre_oficial is distinct from old.nombre_oficial
    or new.grupo is distinct from old.grupo
    or new.turno is distinct from old.turno
    or new.reo_asignado is distinct from old.reo_asignado
    or new.grado is distinct from old.grado
    or new.activo is distinct from old.activo
  ) then
    if not public.fn_is_management_actor() then
      raise exception 'Operacion no autorizada: catalogo de oficiales solo por supervisor/director';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_oficiales_catalogo on public.oficiales;
create trigger trg_guard_oficiales_catalogo
before insert or update or delete on public.oficiales
for each row execute function public.trg_guard_oficiales_catalogo();

-- ---------------------------------------------------------
-- 2) Grants base + RLS
-- ---------------------------------------------------------
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on public.oficiales to authenticated, anon;

alter table if exists public.oficiales enable row level security;

-- ---------------------------------------------------------
-- 3) Politicas recomendadas para oficiales
-- ---------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'oficiales'
      and policyname = 'oficiales_select_auth_anon'
  ) then
    create policy oficiales_select_auth_anon
      on public.oficiales
      for select
      to authenticated, anon
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'oficiales'
      and policyname = 'oficiales_update_auth_anon'
  ) then
    create policy oficiales_update_auth_anon
      on public.oficiales
      for update
      to authenticated, anon
      using (true)
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'oficiales'
      and policyname = 'oficiales_insert_management'
  ) then
    create policy oficiales_insert_management
      on public.oficiales
      for insert
      to authenticated, anon
      with check (public.fn_is_management_actor());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'oficiales'
      and policyname = 'oficiales_delete_management'
  ) then
    create policy oficiales_delete_management
      on public.oficiales
      for delete
      to authenticated, anon
      using (public.fn_is_management_actor());
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
  and tablename = 'oficiales'
order by policyname;

select
  now() as now_server_tz,
  current_user as current_user,
  current_setting('request.jwt.claim.role', true) as jwt_role,
  current_setting('request.jwt.claim.email', true) as jwt_email,
  public.fn_is_management_actor() as can_manage_catalog;
