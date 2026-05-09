-- =========================================================
-- SCCP - MIGRACION DE GRADOS (CATALOGO OFICIAL)
-- =========================================================
-- Objetivo:
-- Migrar el campo `public.oficiales.grado` desde valores numericos
-- al nombre real del grado, usando la tabla de equivalencias.
--
-- Requisito previo:
-- Si te bloquea permisos/RLS, ejecuta primero:
--   docs/supabase_fix_oficiales_supervisor_rls.sql
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 0) Ajuste de constraint de grado (compatibilidad transitoria)
-- ---------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.oficiales'::regclass
      and conname = 'oficiales_grado_check'
  ) then
    alter table public.oficiales
      drop constraint oficiales_grado_check;
  end if;

  alter table public.oficiales
    add constraint oficiales_grado_check
    check (
      grado is null
      or upper(trim(grado)) in (
        -- legacy numerico
        '1','2','3','4','5','6','7','8','9','10','11','12','13','14',
        -- canonico nominal
        'SARGENTO',
        'SARGENTO SEGUNDO',
        'SARGENTO PRIMERO',
        'SARGENTO MAYOR',
        'SUBOFICIAL SEGUNDO',
        'SUBOFICIAL PRIMERO',
        'SUBOFICIAL MAYOR',
        'SUBOFICIAL SUPERIOR',
        'SUBTENIENTE',
        'TENIENTE',
        'CAPITAN',
        'MAYOR',
        'TENIENTE CORONEL',
        'CORONEL',
        -- abreviaturas de compatibilidad
        'SGTO',
        'SGTO SEGUNDO',
        'SGTO PRIMERO',
        'SGTO MAYOR',
        'SOF SEGUNDO',
        'SOF PRIMERO',
        'SOF MAYOR',
        'SOF SUPERIOR',
        'SUB TTE',
        'TTE',
        'CAP',
        'MY',
        'TTE CNL',
        'CNL'
      )
    );
end $$;

-- ---------------------------------------------------------
-- 1) Tabla de equivalencias (desde tu hoja de grados)
-- ---------------------------------------------------------
create temporary table tmp_catalogo_grados (
  grado_anterior text not null,
  grado_nuevo text not null,
  icono text not null
) on commit drop;

insert into tmp_catalogo_grados (grado_anterior, grado_nuevo, icono)
values
  ('1',  'SARGENTO',            'sgto.png'),
  ('2',  'SARGENTO SEGUNDO',    'sgtoseg.png'),
  ('3',  'SARGENTO PRIMERO',    'sgtopri.png'),
  ('4',  'SARGENTO MAYOR',      'sgtomy.png'),
  ('5',  'SUBOFICIAL SEGUNDO',  'sofseg.png'),
  ('6',  'SUBOFICIAL PRIMERO',  'sofpri.png'),
  ('7',  'SUBOFICIAL MAYOR',    'sofmy.png'),
  ('8',  'SUBOFICIAL SUPERIOR', 'sofsup.png'),
  ('9',  'SUBTENIENTE',         'subtte.png'),
  ('10', 'TENIENTE',            'tte.png'),
  ('11', 'CAPITAN',             'cap.png'),
  ('12', 'MAYOR',               'my.png'),
  ('13', 'TENIENTE CORONEL',    'ttecnl.png'),
  ('14', 'CORONEL',             'cnl.png');

-- ---------------------------------------------------------
-- 2) Migracion de grados en oficiales
-- ---------------------------------------------------------
with actualizados as (
  update public.oficiales o
     set grado = c.grado_nuevo
    from tmp_catalogo_grados c
   where trim(coalesce(o.grado::text, '')) = c.grado_anterior
  returning o.id_oficial, o.grado
)
select count(*) as filas_actualizadas
from actualizados;

-- ---------------------------------------------------------
-- 3) Verificacion por distribucion de grados
-- ---------------------------------------------------------
select
  grado,
  count(*) as cantidad
from public.oficiales
group by grado
order by
  case grado
    when 'SARGENTO' then 1
    when 'SARGENTO SEGUNDO' then 2
    when 'SARGENTO PRIMERO' then 3
    when 'SARGENTO MAYOR' then 4
    when 'SUBOFICIAL SEGUNDO' then 5
    when 'SUBOFICIAL PRIMERO' then 6
    when 'SUBOFICIAL MAYOR' then 7
    when 'SUBOFICIAL SUPERIOR' then 8
    when 'SUBTENIENTE' then 9
    when 'TENIENTE' then 10
    when 'CAPITAN' then 11
    when 'MAYOR' then 12
    when 'TENIENTE CORONEL' then 13
    when 'CORONEL' then 14
    else 999
  end,
  grado;

-- ---------------------------------------------------------
-- 4) (Opcional) Filas que siguen numericas o vacias
-- ---------------------------------------------------------
select
  id_oficial,
  nombre_oficial,
  grado
from public.oficiales
where trim(coalesce(grado::text, '')) ~ '^[0-9]+$'
   or trim(coalesce(grado::text, '')) = ''
order by id_oficial;

commit;
