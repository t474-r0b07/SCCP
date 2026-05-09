-- =========================================================
-- SCCP - ACTUALIZACION MASIVA DE GRADOS
-- =========================================================
-- Objetivo:
-- Actualizar `public.oficiales.grado` en bloque usando una tabla de cambios.
--
-- Requisito previo:
-- Si te bloquea permisos, ejecuta primero:
--   docs/supabase_fix_oficiales_supervisor_rls.sql
--
-- Ejecutar en Supabase SQL Editor.

begin;

-- ---------------------------------------------------------
-- 1) PEGA AQUI TU TABLA DE CAMBIOS
-- ---------------------------------------------------------
create temporary table tmp_cambios_grado (
  id_oficial text not null,
  grado_nuevo text not null
) on commit drop;

-- Formato:
--   ('ID_OFICIAL','GRADO_REAL')
-- Ejemplo:
--   ('4991582','SARGENTO 2DO'),
--   ('10662099','CABO');
insert into tmp_cambios_grado (id_oficial, grado_nuevo)
values
  ('REEMPLAZAR_ID_1', 'REEMPLAZAR_GRADO_1'),
  ('REEMPLAZAR_ID_2', 'REEMPLAZAR_GRADO_2');

with normalizados as (
  select
    trim(id_oficial) as id_oficial,
    trim(grado_nuevo) as grado_nuevo
  from tmp_cambios_grado
  where trim(id_oficial) <> ''
    and trim(grado_nuevo) <> ''
), actualizados as (
  update public.oficiales o
     set grado = n.grado_nuevo
    from normalizados n
   where o.id_oficial = n.id_oficial
  returning o.id_oficial
)
select count(*) as filas_actualizadas
from actualizados;

-- ---------------------------------------------------------
-- 2) VERIFICA RESULTADO (lista aplicada)
-- ---------------------------------------------------------
select
  o.id_oficial,
  o.nombre_oficial,
  o.grado as grado_actual
from public.oficiales o
join tmp_cambios_grado c
  on c.id_oficial = o.id_oficial
order by o.id_oficial;

-- ---------------------------------------------------------
-- 3) (Opcional) Identifica IDs que no existen en catalogo
-- ---------------------------------------------------------
select
  c.id_oficial,
  c.grado_nuevo
from tmp_cambios_grado c
left join public.oficiales o
  on o.id_oficial = c.id_oficial
where o.id_oficial is null;

commit;
