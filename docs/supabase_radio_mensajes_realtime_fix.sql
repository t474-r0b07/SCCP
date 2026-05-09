-- =========================================================
-- SCCP - RADIO MENSAJES / REALTIME FIX
-- =========================================================
-- Objetivo:
-- 1) Verificar que radio_mensajes existe y tiene políticas para app/web.
-- 2) Garantizar publicación realtime para radio_mensajes y radio_llamadas.
-- 3) Dejar trazabilidad para diagnóstico de "no recibo mensajes/llamadas".
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Diagnóstico rápido de tablas
-- ---------------------------------------------------------
select
  table_schema,
  table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('radio_mensajes', 'radio_llamadas')
order by table_name;

-- ---------------------------------------------------------
-- 1) Permisos / RLS para radio_mensajes
-- ---------------------------------------------------------
grant select, insert, update on public.radio_mensajes to authenticated, anon;
alter table if exists public.radio_mensajes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_mensajes'
      and policyname = 'radio_mensajes_select_auth_anon'
  ) then
    create policy radio_mensajes_select_auth_anon
      on public.radio_mensajes
      for select
      to authenticated, anon
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_mensajes'
      and policyname = 'radio_mensajes_insert_auth_anon'
  ) then
    create policy radio_mensajes_insert_auth_anon
      on public.radio_mensajes
      for insert
      to authenticated, anon
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_mensajes'
      and policyname = 'radio_mensajes_update_auth_anon'
  ) then
    create policy radio_mensajes_update_auth_anon
      on public.radio_mensajes
      for update
      to authenticated, anon
      using (true)
      with check (true);
  end if;
end $$;

create index if not exists idx_radio_mensajes_oficial_timestamp
  on public.radio_mensajes(id_oficial, "timestamp" desc);

create index if not exists idx_radio_mensajes_timestamp
  on public.radio_mensajes("timestamp" desc);

-- ---------------------------------------------------------
-- 2) Publicación realtime (imprescindible para streams)
-- ---------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_publication p on p.oid = pr.prpubid
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'radio_mensajes'
  ) then
    alter publication supabase_realtime add table public.radio_mensajes;
  end if;

  if not exists (
    select 1
    from pg_publication_rel pr
    join pg_class c on c.oid = pr.prrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_publication p on p.oid = pr.prpubid
    where p.pubname = 'supabase_realtime'
      and n.nspname = 'public'
      and c.relname = 'radio_llamadas'
  ) then
    alter publication supabase_realtime add table public.radio_llamadas;
  end if;
end $$;

-- ---------------------------------------------------------
-- 3) Verificación de políticas y publicación
-- ---------------------------------------------------------
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('radio_mensajes', 'radio_llamadas')
order by tablename, policyname;

select
  p.pubname as publication,
  n.nspname as schema_name,
  c.relname as table_name
from pg_publication_rel pr
join pg_class c on c.oid = pr.prrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_publication p on p.oid = pr.prpubid
where p.pubname = 'supabase_realtime'
  and n.nspname = 'public'
  and c.relname in ('radio_mensajes', 'radio_llamadas')
order by c.relname;

commit;
