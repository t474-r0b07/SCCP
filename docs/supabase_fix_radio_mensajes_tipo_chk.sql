-- =========================================================
-- SCCP - FIX CHECK radio_mensajes.tipo
-- =========================================================
-- Objetivo:
-- Corregir el constraint que bloquea envios de radio con error:
--   23514 / radio_mensajes_tipo_chk
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 1) Normaliza tipos existentes fuera del catálogo permitido
-- ---------------------------------------------------------
update public.radio_mensajes
set
  mensaje = '[' || coalesce(tipo, 'SIN_TIPO') || '] ' || coalesce(mensaje, ''),
  tipo = 'RADIO'
where upper(trim(coalesce(tipo, ''))) not in (
  'RADIO',
  'CONSULTA',
  'EMERGENCIA',
  'CONTROL_SORPRESA',
  'PARTE_NOVEDAD',
  'CALL_START',
  'CALL_END'
);

-- ---------------------------------------------------------
-- 2) Elimina checks antiguos sobre columna tipo
-- ---------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.radio_mensajes'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%tipo%'
  loop
    execute format(
      'alter table public.radio_mensajes drop constraint %I',
      r.conname
    );
  end loop;
end $$;

-- ---------------------------------------------------------
-- 3) Re-crea constraint de tipo con catálogo actualizado
-- ---------------------------------------------------------
alter table public.radio_mensajes
  add constraint radio_mensajes_tipo_chk
  check (
    upper(trim(coalesce(tipo, ''))) in (
      'RADIO',
      'CONSULTA',
      'EMERGENCIA',
      'CONTROL_SORPRESA',
      'PARTE_NOVEDAD',
      'CALL_START',
      'CALL_END'
    )
  );

-- opcional: default estable
alter table public.radio_mensajes
  alter column tipo set default 'RADIO';

-- ---------------------------------------------------------
-- 4) Verificación rápida
-- ---------------------------------------------------------
select
  conname,
  pg_get_constraintdef(oid) as constraint_def
from pg_constraint
where conrelid = 'public.radio_mensajes'::regclass
  and contype = 'c'
order by conname;

commit;
