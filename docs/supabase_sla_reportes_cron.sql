-- =========================================================
-- SCCP - CRON SLA REPORTES (cada 1 minuto)
-- =========================================================
-- Requiere:
-- 1) Haber ejecutado docs/supabase_sla_reportes_estricto.sql
-- 2) extension pg_cron habilitada en el proyecto

begin;

create extension if not exists pg_cron;

do $do$
declare
  v_job_id integer;
begin
  -- Elimina job anterior con el mismo nombre si existe.
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'sccp_sla_reportes_tick'
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'sccp_sla_reportes_tick',
    '* * * * *',
    $$select public.fn_sla_reportes_tick();$$
  );
end $do$;

commit;

-- Verificacion
select jobid, jobname, schedule, command, active
from cron.job
where jobname = 'sccp_sla_reportes_tick';
