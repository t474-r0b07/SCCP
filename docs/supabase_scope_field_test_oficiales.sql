-- SCCP - SCOPE DE OFICIALES PARA PRUEBA DE CAMPO (2 dias)
-- Objetivo: que SLA y dashboard solo consideren oficiales de prueba.
-- Ejecutar despues del reset y antes de iniciar monitoreo real.

begin;

-- 1) Apaga todos los oficiales del catalogo
update public.oficiales
set activo = false,
    updated_at = now();

-- 2) Activa solo los oficiales de prueba de campo
update public.oficiales
set activo = true,
    updated_at = now()
where id_oficial in ('5538491', '5538492');

-- 3) Limpia sesiones viejas para iniciar desde cero
truncate table public.oficial_sesiones restart identity cascade;

-- 4) Limpia inconsistencias SLA antiguas (si existen)
delete from public.inconsistencias
where coalesce(id_reporte, '') like 'SLA_%';

commit;

-- 5) Verificacion rapida
select id_oficial, activo
from public.oficiales
where id_oficial in ('5538491', '5538492')
order by id_oficial;

select count(*) as oficiales_activos_total
from public.oficiales
where activo = true;
