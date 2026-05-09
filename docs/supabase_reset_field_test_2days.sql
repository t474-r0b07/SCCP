begin;

do $$
declare
  t text;
  tables text[] := array[
    'monitoreo_reportes',
    'partes_oficiales',
    'partes_sorpresa',
    'inconsistencias',
    'radio_mensajes',
    'radio_llamadas',
    'oficial_sesiones',
    'login_logs',
    'audit_eventos',
    'deleted_records_backup'
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.' || t) is not null then
      execute format('truncate table public.%I restart identity cascade', t);
    end if;
  end loop;
end $$;

commit;

select 'monitoreo_reportes' as tabla, count(*) as filas from public.monitoreo_reportes
union all
select 'partes_oficiales', count(*) from public.partes_oficiales
union all
select 'partes_sorpresa', count(*) from public.partes_sorpresa
union all
select 'inconsistencias', count(*) from public.inconsistencias
union all
select 'radio_mensajes', count(*) from public.radio_mensajes
union all
select 'radio_llamadas', count(*) from public.radio_llamadas
union all
select 'oficial_sesiones', count(*) from public.oficial_sesiones
union all
select 'login_logs', count(*) from public.login_logs
order by tabla;
