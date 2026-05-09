-- DTEX - datos de prueba para login real en app Android custodio.
-- Ejecutar despues de:
-- 1. docs/supabase_dtex_schema_alignment.sql
-- 2. docs/supabase_dtex_custodio_public_rpc.sql
--
-- Credenciales de prueba en Android:
--   Nombre: CUSTODIO PRUEBA DTEX
--   Codigo: 123456

begin;

create extension if not exists pgcrypto;

do $$
declare
  v_id_destino uuid;
  v_destino_nombre text;
  v_id_mision uuid;
  v_supervisor_email text;
  v_supervisor_nombre text;
begin
  select email,
         nombre
    into v_supervisor_email,
         v_supervisor_nombre
  from public.allowed_admins
  where activo = true
    and upper(coalesce(nivel_acceso, '')) in (
      'SUDO',
      'SUPERVISOR_DTEX',
      'SUPERVISOR',
      'DIRECTOR',
      'ADMIN',
      'ADMINISTRADOR',
      'COMANDANTE'
    )
  order by case upper(coalesce(nivel_acceso, ''))
    when 'SUDO' then 1
    when 'SUPERVISOR_DTEX' then 2
    when 'SUPERVISOR' then 3
    else 4
  end,
  email
  limit 1;

  if v_supervisor_email is null then
    raise exception
      'No hay supervisor activo en allowed_admins. Crea/activa uno con nivel SUDO, SUPERVISOR o SUPERVISOR_DTEX antes de sembrar DTEX.';
  end if;

  update public.dtex_destinos
  set tipo = 'JUDICIAL',
      direccion = 'Palacio de Justicia, Tarija',
      latitud = -21.532975,
      longitud = -64.732031,
      radio_metros = 80,
      activo = true
  where lower(regexp_replace(trim(nombre), '\s+', ' ', 'g')) =
        lower('DESTINO PRUEBA DTEX ANDROID');

  select id_destino,
         nombre
    into v_id_destino,
         v_destino_nombre
  from public.dtex_destinos
  where lower(regexp_replace(trim(nombre), '\s+', ' ', 'g')) in (
    lower('Palacio de Justicia'),
    lower('DESTINO PRUEBA DTEX ANDROID')
  )
  order by case
    when lower(regexp_replace(trim(nombre), '\s+', ' ', 'g')) =
         lower('Palacio de Justicia') then 1
    else 2
  end
  limit 1;

  if v_id_destino is null then
    v_id_destino := gen_random_uuid();
    v_destino_nombre := 'DESTINO PRUEBA DTEX ANDROID';

    insert into public.dtex_destinos (
      id_destino,
      nombre,
      tipo,
      direccion,
      latitud,
      longitud,
      radio_metros,
      activo
    )
    values (
      v_id_destino,
      'DESTINO PRUEBA DTEX ANDROID',
      'JUDICIAL',
      'Palacio de Justicia, Tarija',
      -21.532975,
      -64.732031,
      80,
      true
    );
  end if;

  if v_id_destino is null then
    raise exception
      'No se pudo resolver id_destino para la mision de prueba DTEX.';
  end if;

  select id_mision
    into v_id_mision
  from public.dtex_misiones
  where codigo_otp = '123456'
    and custodio_nombre = 'CUSTODIO PRUEBA DTEX'
    and estado in (
      'PENDIENTE',
      'REGISTRO_REALIZADO',
      'EN_RUTA',
      'EN_DESTINO',
      'RETORNANDO',
      'EMERGENCIA'
    )
  order by hora_salida_autorizada desc
  limit 1;

  if v_id_mision is null then
    insert into public.dtex_misiones (
      id_mision,
      tipo_diligencia,
      reo_nombre,
      reo_ci,
      reo_expediente,
      custodio_nombre,
      custodio_codigo,
      custodio_grado,
      id_destino,
      destino_nombre,
      hora_salida_autorizada,
      tiempo_max_estadia_min,
      referencia_legal,
      codigo_otp,
      otp_usado,
      estado,
      supervisor_email,
      supervisor_nombre,
      notas
    )
    values (
      gen_random_uuid(),
      'JUDICIAL',
      'INTERNO PRUEBA DTEX',
      '0000000',
      'EXP-DTEX-ANDROID',
      'CUSTODIO PRUEBA DTEX',
      'DTEX-001',
      'SGTO',
      v_id_destino,
      v_destino_nombre,
      now(),
      120,
      'PRUEBA_ANDROID_DTEX_2026_05_08',
      '123456',
      false,
      'PENDIENTE',
      v_supervisor_email,
      coalesce(v_supervisor_nombre, 'Supervisor DTEX Prueba'),
      'Mision generada para validar login, tracking y geocerca en app Android custodio.'
    )
    returning id_mision into v_id_mision;
  else
    update public.dtex_misiones
    set estado = 'PENDIENTE',
        otp_usado = false,
        otp_usado_at = null,
        ts_inicio_real = null,
        ts_llegada_destino = null,
        ts_salida_destino = null,
        ts_cierre = null,
        conducta_final = null,
        hora_salida_autorizada = now(),
        tiempo_max_estadia_min = 120,
        id_destino = v_id_destino,
        destino_nombre = v_destino_nombre,
        supervisor_email = v_supervisor_email,
        supervisor_nombre = coalesce(v_supervisor_nombre, 'Supervisor DTEX Prueba'),
        updated_at = now()
    where id_mision = v_id_mision;
  end if;

  raise notice 'DTEX prueba Android lista. id_mision=%, custodio=%, codigo=%, supervisor=%',
    v_id_mision,
    'CUSTODIO PRUEBA DTEX',
    '123456',
    v_supervisor_email;
end $$;

commit;

-- Verificacion rapida:
-- select public.dtex_validar_acceso_custodio('CUSTODIO PRUEBA DTEX', '123456');
