-- =========================================================
-- SCCP - LOG DE LLAMADAS RADIO (VOZ EN VIVO)
-- =========================================================
-- Objetivo:
-- Registrar inicio/fin/duración de comunicación tipo "walkie-talkie"
-- sin guardar audio, pero dejando trazabilidad para informes.
--
-- Ejecutar en Supabase SQL Editor.

begin;

create table if not exists public.radio_llamadas (
  id_llamada text primary key,
  id_oficial text not null,
  de_usuario text not null,
  para_usuario text not null,
  inicio_llamada timestamp with time zone not null default now(),
  fin_llamada timestamp with time zone,
  duracion_segundos integer,
  estado text not null default 'ACTIVA'
    check (estado in ('ACTIVA', 'FINALIZADA', 'CANCELADA')),
  resumen text,
  created_at timestamp with time zone not null default now()
);

comment on table public.radio_llamadas is
  'Bitácora de comunicación de radio (sin almacenamiento de audio).';

create index if not exists idx_radio_llamadas_oficial_inicio
  on public.radio_llamadas(id_oficial, inicio_llamada desc);

create index if not exists idx_radio_llamadas_estado
  on public.radio_llamadas(estado);

grant select, insert, update on public.radio_llamadas to authenticated, anon;

alter table if exists public.radio_llamadas enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_radio_llamadas_duracion_non_negative'
      and conrelid = 'public.radio_llamadas'::regclass
  ) then
    alter table public.radio_llamadas
      add constraint chk_radio_llamadas_duracion_non_negative
      check (duracion_segundos is null or duracion_segundos >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_radio_llamadas_fin_ge_inicio'
      and conrelid = 'public.radio_llamadas'::regclass
  ) then
    alter table public.radio_llamadas
      add constraint chk_radio_llamadas_fin_ge_inicio
      check (fin_llamada is null or fin_llamada >= inicio_llamada);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_llamadas'
      and policyname = 'radio_llamadas_select_auth_anon'
  ) then
    create policy radio_llamadas_select_auth_anon
      on public.radio_llamadas
      for select
      to authenticated, anon
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_llamadas'
      and policyname = 'radio_llamadas_insert_auth_anon'
  ) then
    create policy radio_llamadas_insert_auth_anon
      on public.radio_llamadas
      for insert
      to authenticated, anon
      with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'radio_llamadas'
      and policyname = 'radio_llamadas_update_auth_anon'
  ) then
    create policy radio_llamadas_update_auth_anon
      on public.radio_llamadas
      for update
      to authenticated, anon
      using (true)
      with check (true);
  end if;
end $$;

create or replace function public.fn_radio_llamadas_autocierre()
returns trigger
language plpgsql
as $$
begin
  if new.estado in ('FINALIZADA', 'CANCELADA') then
    if new.fin_llamada is null then
      new.fin_llamada := now();
    end if;

    new.duracion_segundos := greatest(
      extract(epoch from (new.fin_llamada - new.inicio_llamada))::integer,
      0
    );
  end if;

  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where t.tgname = 'trg_radio_llamadas_autocierre'
      and n.nspname = 'public'
      and c.relname = 'radio_llamadas'
      and not t.tgisinternal
  ) then
    create trigger trg_radio_llamadas_autocierre
      before update on public.radio_llamadas
      for each row
      execute function public.fn_radio_llamadas_autocierre();
  end if;
end $$;

commit;
