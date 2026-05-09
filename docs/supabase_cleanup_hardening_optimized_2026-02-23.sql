-- =========================================================
-- SCCP - CLEANUP + HARDENING + OPTIMIZATION (COMPAT)
-- Fecha: 2026-02-23
-- Objetivo:
-- 1) Limpiar politicas RLS permisivas heredadas.
-- 2) Endurecer tablas sensibles sin romper app movil (anon) ni webapp.
-- 3) Normalizar login_logs/oficial_sesiones y crear indices operativos.
-- 4) Eliminar basura tecnica de diagnostico.
-- =========================================================
--
-- IMPORTANTE:
-- - Script idempotente (se puede re-ejecutar).
-- - Compatible con arquitectura actual:
--   * movil: anon + background
--   * webapp: authenticated
-- - No revoca usage de schema public para no romper clientes anon existentes.

begin;

set local lock_timeout = '8s';
set local statement_timeout = '120s';

-- ---------------------------------------------------------
-- 0) Helper de autorizacion de management (si no existe)
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
  -- SQL editor/migraciones sin JWT.
  if v_role = '' and v_email = '' then
    return true;
  end if;

  if v_role = 'SERVICE_ROLE' then
    return true;
  end if;

  if v_email = '' then
    return false;
  end if;

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

revoke all on function public.fn_is_management_actor() from public;
grant execute on function public.fn_is_management_actor() to authenticated;

-- ---------------------------------------------------------
-- 1) LOGIN_LOGS: compat + hardening + limpieza
-- ---------------------------------------------------------
do $$
declare
  v_pol record;
  v_con record;
begin
  if to_regclass('public.login_logs') is null then
    return;
  end if;

  alter table public.login_logs
    add column if not exists actor_tipo text default 'ADMIN',
    add column if not exists session_id uuid,
    add column if not exists device_id text,
    add column if not exists metadata jsonb default '{}'::jsonb;

  update public.login_logs
  set status = lower(coalesce(status, 'active'))
  where status is distinct from lower(coalesce(status, 'active'));

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

  alter table public.login_logs
    add constraint login_logs_status_chk
    check (lower(coalesce(status, '')) in ('active', 'logout', 'expired', 'forced'));

  -- Limpia politicas previas (incluye "Allow all ...").
  for v_pol in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'login_logs'
  loop
    execute format('drop policy if exists %I on public.login_logs', v_pol.policyname);
  end loop;

  -- Grants minimos compatibles.
  revoke all on public.login_logs from anon, authenticated;
  grant insert on public.login_logs to anon, authenticated;
  grant select, update on public.login_logs to authenticated;

  alter table public.login_logs enable row level security;

  create policy login_logs_insert_auth_anon
    on public.login_logs
    for insert
    to anon, authenticated
    with check (
      char_length(trim(coalesce(admin_email, ''))) > 0
      and lower(coalesce(status, 'active')) in ('active', 'logout', 'expired', 'forced')
    );

  create policy login_logs_select_authenticated
    on public.login_logs
    for select
    to authenticated
    using (true);

  create policy login_logs_update_authenticated
    on public.login_logs
    for update
    to authenticated
    using (true)
    with check (
      lower(coalesce(status, 'active')) in ('active', 'logout', 'expired', 'forced')
    );

  -- Limpieza de basura tecnica de diagnostico.
  delete from public.login_logs
  where lower(coalesce(admin_email, '')) like 'diag_%@sccp.local'
     or lower(coalesce(metadata->>'source', '')) like 'diag_%';

end $$;

create index if not exists idx_login_logs_admin_status_ts
  on public.login_logs(admin_email, status, "timestamp" desc);

-- ---------------------------------------------------------
-- 2) OFICIAL_SESIONES: compat + hardening operativo
-- ---------------------------------------------------------
do $$
declare
  v_pol record;
  v_con record;
begin
  if to_regclass('public.oficial_sesiones') is null then
    return;
  end if;

  alter table public.oficial_sesiones
    add column if not exists login_at timestamp with time zone,
    add column if not exists last_heartbeat timestamp with time zone,
    add column if not exists logout_at timestamp with time zone,
    add column if not exists updated_at timestamp with time zone not null default now();

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
  set estado = case upper(trim(coalesce(s.estado, '')))
    when 'ACTIVE' then 'ACTIVA'
    when 'CLOSED' then 'CERRADA'
    when 'EXPIRED' then 'EXPIRADA'
    when 'FORCED' then 'FORZADA'
    else coalesce(s.estado, 'ACTIVA')
  end;

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
    execute format('alter table public.oficial_sesiones drop constraint %I', v_con.conname);
  end loop;

  alter table public.oficial_sesiones
    add constraint oficial_sesiones_estado_check
    check (
      upper(trim(coalesce(estado, ''))) in (
        'ACTIVA', 'CERRADA', 'EXPIRADA', 'FORZADA',
        'ACTIVE', 'CLOSED', 'EXPIRED', 'FORCED'
      )
    );

  -- Limpia politicas previas.
  for v_pol in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'oficial_sesiones'
  loop
    execute format('drop policy if exists %I on public.oficial_sesiones', v_pol.policyname);
  end loop;

  revoke all on public.oficial_sesiones from anon, authenticated;
  grant select, insert, update on public.oficial_sesiones to anon, authenticated;

  alter table public.oficial_sesiones enable row level security;

  create policy oficial_sesiones_select_auth_anon
    on public.oficial_sesiones
    for select
    to anon, authenticated
    using (true);

  create policy oficial_sesiones_insert_auth_anon
    on public.oficial_sesiones
    for insert
    to anon, authenticated
    with check (
      char_length(trim(coalesce(id_oficial, ''))) > 0
      and upper(trim(coalesce(estado, 'ACTIVA'))) in (
        'ACTIVA', 'CERRADA', 'EXPIRADA', 'FORZADA',
        'ACTIVE', 'CLOSED', 'EXPIRED', 'FORCED'
      )
    );

  create policy oficial_sesiones_update_auth_anon
    on public.oficial_sesiones
    for update
    to anon, authenticated
    using (true)
    with check (
      upper(trim(coalesce(estado, 'ACTIVA'))) in (
        'ACTIVA', 'CERRADA', 'EXPIRADA', 'FORZADA',
        'ACTIVE', 'CLOSED', 'EXPIRED', 'FORCED'
      )
    );
end $$;

create index if not exists idx_oficial_sesiones_oficial_device
  on public.oficial_sesiones(id_oficial, device_id);
create index if not exists idx_oficial_sesiones_last_heartbeat
  on public.oficial_sesiones(last_heartbeat desc);
create index if not exists idx_oficial_sesiones_activa
  on public.oficial_sesiones(id_oficial, device_id, last_heartbeat desc)
  where upper(trim(coalesce(estado, ''))) in ('ACTIVA', 'ACTIVE');

-- ---------------------------------------------------------
-- 3) OFICIALES + ALLOWED_ADMINS: hardening de catalogo
-- ---------------------------------------------------------
do $$
declare
  v_pol record;
begin
  if to_regclass('public.oficiales') is not null then
    -- Trigger de guardia de catalogo (permite update de IMEI por app).
    create or replace function public.trg_guard_oficiales_catalogo()
    returns trigger
    language plpgsql
    security definer
    set search_path = public
    as $fn$
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

      if (
           new.nombre_oficial is distinct from old.nombre_oficial
        or new.grupo is distinct from old.grupo
        or new.turno is distinct from old.turno
        or new.reo_asignado is distinct from old.reo_asignado
        or new.grado is distinct from old.grado
        or new.activo is distinct from old.activo
      ) then
        if not public.fn_is_management_actor() then
          raise exception 'Operacion no autorizada: catalogo solo por supervisor/director';
        end if;
      end if;

      return new;
    end;
    $fn$;

    drop trigger if exists trg_guard_oficiales_catalogo on public.oficiales;
    create trigger trg_guard_oficiales_catalogo
      before insert or update or delete on public.oficiales
      for each row execute function public.trg_guard_oficiales_catalogo();

    for v_pol in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = 'oficiales'
    loop
      execute format('drop policy if exists %I on public.oficiales', v_pol.policyname);
    end loop;

    revoke all on public.oficiales from anon, authenticated;
    grant select, update on public.oficiales to anon, authenticated;
    grant insert, delete on public.oficiales to authenticated;

    alter table public.oficiales enable row level security;

    create policy oficiales_select_auth_anon
      on public.oficiales
      for select
      to anon, authenticated
      using (true);

    create policy oficiales_update_auth_anon
      on public.oficiales
      for update
      to anon, authenticated
      using (true)
      with check (true);

    create policy oficiales_insert_management
      on public.oficiales
      for insert
      to authenticated
      with check (public.fn_is_management_actor());

    create policy oficiales_delete_management
      on public.oficiales
      for delete
      to authenticated
      using (public.fn_is_management_actor());
  end if;

  if to_regclass('public.allowed_admins') is not null then
    for v_pol in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = 'allowed_admins'
    loop
      execute format('drop policy if exists %I on public.allowed_admins', v_pol.policyname);
    end loop;

    revoke all on public.allowed_admins from anon, authenticated;
    grant select, update, insert, delete on public.allowed_admins to authenticated;

    alter table public.allowed_admins enable row level security;

    create policy allowed_admins_select_authenticated
      on public.allowed_admins
      for select
      to authenticated
      using (
        lower(coalesce(email, '')) = lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''))
        or public.fn_is_management_actor()
      );

    create policy allowed_admins_update_authenticated
      on public.allowed_admins
      for update
      to authenticated
      using (
        lower(coalesce(email, '')) = lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''))
        or public.fn_is_management_actor()
      )
      with check (
        lower(coalesce(email, '')) = lower(coalesce(nullif(current_setting('request.jwt.claim.email', true), ''), ''))
        or public.fn_is_management_actor()
      );

    create policy allowed_admins_insert_management
      on public.allowed_admins
      for insert
      to authenticated
      with check (public.fn_is_management_actor());

    create policy allowed_admins_delete_management
      on public.allowed_admins
      for delete
      to authenticated
      using (public.fn_is_management_actor());
  end if;
end $$;

create index if not exists idx_oficiales_id_activo
  on public.oficiales(id_oficial, activo);
create index if not exists idx_oficiales_imei
  on public.oficiales(imei);
create index if not exists idx_allowed_admins_email_lower
  on public.allowed_admins(lower(email));

-- ---------------------------------------------------------
-- 4) Tablas sensibles de auditoria: insert-only para cliente
--    (compat con triggers de auditoria)
-- ---------------------------------------------------------
do $$
declare
  v_tbl text;
  v_pol record;
begin
  for v_tbl in select unnest(array['audit_eventos', 'deleted_records_backup'])
  loop
    if to_regclass(format('public.%s', v_tbl)) is null then
      continue;
    end if;

    execute format('revoke all on public.%I from anon, authenticated', v_tbl);
    execute format('grant insert on public.%I to anon, authenticated', v_tbl);
    execute format('alter table public.%I enable row level security', v_tbl);

    for v_pol in
      select policyname
      from pg_policies
      where schemaname = 'public'
        and tablename = v_tbl
    loop
      execute format('drop policy if exists %I on public.%I', v_pol.policyname, v_tbl);
    end loop;

    execute format(
      'create policy %I on public.%I for insert to anon, authenticated with check (true)',
      v_tbl || '_insert_auth_anon',
      v_tbl
    );
  end loop;
end $$;

-- ---------------------------------------------------------
-- 5) Indices operativos (performance)
-- ---------------------------------------------------------
create index if not exists idx_monitoreo_oficial_fecha
  on public.monitoreo_reportes(id_oficial_ref, fecha_hora desc);
create index if not exists idx_monitoreo_fecha
  on public.monitoreo_reportes(fecha_hora desc);
create index if not exists idx_inconsistencias_oficial_fecha
  on public.inconsistencias(id_oficial, fecha_deteccion desc);
create index if not exists idx_inconsistencias_estado_fecha
  on public.inconsistencias(estado, fecha_deteccion desc);
create index if not exists idx_partes_oficiales_oficial_ts
  on public.partes_oficiales(id_oficial, "timestamp" desc);
create index if not exists idx_partes_sorpresa_oficial_ts
  on public.partes_sorpresa(id_oficial, "timestamp" desc);
create index if not exists idx_radio_mensajes_oficial_ts
  on public.radio_mensajes(id_oficial, "timestamp" desc);
create index if not exists idx_radio_mensajes_ts
  on public.radio_mensajes("timestamp" desc);

commit;

-- =========================================================
-- Verificacion recomendada post-ejecucion
-- =========================================================
-- 1) Politicas en tablas criticas
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename in (
    'login_logs',
    'oficial_sesiones',
    'oficiales',
    'allowed_admins',
    'audit_eventos',
    'deleted_records_backup'
  )
order by tablename, policyname;

-- 2) Grants efectivos en tablas criticas
select
  table_schema,
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'login_logs',
    'oficial_sesiones',
    'oficiales',
    'allowed_admins',
    'audit_eventos',
    'deleted_records_backup'
  )
order by table_name, grantee, privilege_type;

-- 3) Salud rapida de sesiones y login logs
select count(*) as total_login_logs from public.login_logs;
select count(*) as sesiones_activas
from public.oficial_sesiones
where upper(trim(coalesce(estado, ''))) in ('ACTIVA', 'ACTIVE');
