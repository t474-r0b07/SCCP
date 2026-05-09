-- DTEX - RPCs para webapp publica del custodio
-- Ejecutar despues de docs/supabase_dtex_schema_alignment.sql.
-- Objetivo: que /dtex/custodio funcione con anon key sin abrir inserts
-- directos sobre tablas DTEX.

begin;

-- Si estas RPCs ya existian con otros nombres de parametros, PostgreSQL no
-- permite reemplazarlas solo con create or replace. Se eliminan por firma para
-- recrearlas con el contrato esperado por PostgREST/Supabase.
drop function if exists public.dtex_validar_otp(text);
drop function if exists public.dtex_validar_acceso_custodio(text, text);
drop function if exists public.dtex_cambiar_estado(
  uuid,
  text,
  double precision,
  double precision
);
drop function if exists public.dtex_reportar_tracking_gps(
  uuid,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  boolean
);
drop function if exists public.dtex_insertar_alerta(
  uuid,
  text,
  text,
  text,
  double precision,
  double precision
);

create or replace function public.dtex_validar_otp(p_codigo text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text := trim(coalesce(p_codigo, ''));
  v_mision public.dtex_misiones%rowtype;
  v_destino public.dtex_destinos%rowtype;
  v_now timestamptz := now();
begin
  if v_codigo !~ '^[0-9]{6}$' then
    return jsonb_build_object(
      'ok', false,
      'error', 'OTP invalido'
    );
  end if;

  select *
    into v_mision
  from public.dtex_misiones
  where codigo_otp = v_codigo
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

  if not found then
    return jsonb_build_object(
      'ok', false,
      'error', 'OTP invalido, cerrado o cancelado'
    );
  end if;

  if v_mision.hora_salida_autorizada
      + make_interval(mins => coalesce(v_mision.tiempo_max_estadia_min, 60) + 240)
      < v_now then
    return jsonb_build_object(
      'ok', false,
      'error', 'OTP expirado'
    );
  end if;

  update public.dtex_misiones
  set otp_usado = true,
      otp_usado_at = coalesce(otp_usado_at, v_now),
      updated_at = v_now
  where id_mision = v_mision.id_mision
  returning * into v_mision;

  select *
    into v_destino
  from public.dtex_destinos
  where id_destino = v_mision.id_destino
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'id_mision', v_mision.id_mision,
    'mision', to_jsonb(v_mision),
    'destino', to_jsonb(v_destino)
  );
end;
$$;

create or replace function public.dtex_validar_acceso_custodio(
  p_nombre text,
  p_codigo text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nombre text := lower(regexp_replace(trim(coalesce(p_nombre, '')), '\s+', ' ', 'g'));
  v_codigo text := upper(trim(coalesce(p_codigo, '')));
  v_mision public.dtex_misiones%rowtype;
  v_destino public.dtex_destinos%rowtype;
  v_now timestamptz := now();
begin
  if length(v_nombre) < 3 or length(v_codigo) < 4 then
    return jsonb_build_object(
      'ok', false,
      'error', 'Nombre o codigo incompleto'
    );
  end if;

  select *
    into v_mision
  from public.dtex_misiones
  where upper(trim(codigo_otp::text)) = v_codigo
    and lower(regexp_replace(trim(custodio_nombre), '\s+', ' ', 'g')) = v_nombre
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

  if not found then
    return jsonb_build_object(
      'ok', false,
      'error', 'Acceso no autorizado para esta diligencia'
    );
  end if;

  if v_mision.hora_salida_autorizada
      + make_interval(mins => coalesce(v_mision.tiempo_max_estadia_min, 60) + 240)
      < v_now then
    return jsonb_build_object(
      'ok', false,
      'error', 'Codigo expirado'
    );
  end if;

  update public.dtex_misiones
  set otp_usado = true,
      otp_usado_at = coalesce(otp_usado_at, v_now),
      updated_at = v_now
  where id_mision = v_mision.id_mision
  returning * into v_mision;

  select *
    into v_destino
  from public.dtex_destinos
  where id_destino = v_mision.id_destino
  limit 1;

  return jsonb_build_object(
    'ok', true,
    'id_mision', v_mision.id_mision,
    'mision', to_jsonb(v_mision),
    'destino', to_jsonb(v_destino)
  );
end;
$$;

create or replace function public.dtex_cambiar_estado(
  p_id_mision uuid,
  p_estado text,
  p_lat double precision default null,
  p_lng double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text := upper(trim(coalesce(p_estado, '')));
  v_mision public.dtex_misiones%rowtype;
  v_now timestamptz := now();
begin
  if v_estado not in (
    'REGISTRO_REALIZADO',
    'EN_RUTA',
    'EN_DESTINO',
    'RETORNANDO',
    'CERRADA',
    'EMERGENCIA'
  ) then
    return jsonb_build_object(
      'ok', false,
      'error', 'Estado no permitido'
    );
  end if;

  update public.dtex_misiones
  set estado = v_estado,
      otp_usado = case
        when v_estado = 'REGISTRO_REALIZADO' then true
        else otp_usado
      end,
      otp_usado_at = case
        when v_estado = 'REGISTRO_REALIZADO' then coalesce(otp_usado_at, v_now)
        else otp_usado_at
      end,
      ts_inicio_real = case
        when v_estado = 'EN_RUTA' then coalesce(ts_inicio_real, v_now)
        else ts_inicio_real
      end,
      ts_llegada_destino = case
        when v_estado = 'EN_DESTINO' then coalesce(ts_llegada_destino, v_now)
        else ts_llegada_destino
      end,
      ts_salida_destino = case
        when v_estado = 'RETORNANDO' then coalesce(ts_salida_destino, v_now)
        else ts_salida_destino
      end,
      ts_cierre = case
        when v_estado = 'CERRADA' then coalesce(ts_cierre, v_now)
        else ts_cierre
      end,
      updated_at = v_now
  where id_mision = p_id_mision
    and estado in (
      'PENDIENTE',
      'REGISTRO_REALIZADO',
      'EN_RUTA',
      'EN_DESTINO',
      'RETORNANDO',
      'EMERGENCIA'
    )
  returning * into v_mision;

  if not found then
    return jsonb_build_object(
      'ok', false,
      'error', 'Mision no encontrada o no activa'
    );
  end if;

  if v_estado = 'EMERGENCIA' then
    insert into public.dtex_alertas (
      id_mision,
      tipo,
      severidad,
      latitud,
      longitud,
      descripcion,
      resuelta
    )
    values (
      p_id_mision,
      'INCONSISTENCIA',
      'EMERGENCIA',
      p_lat,
      p_lng,
      'Emergencia reportada desde la webapp del custodio.',
      false
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id_mision', v_mision.id_mision,
    'estado', v_mision.estado,
    'mision', to_jsonb(v_mision)
  );
end;
$$;

create or replace function public.dtex_reportar_tracking_gps(
  p_id_mision uuid,
  p_lat double precision,
  p_lng double precision,
  p_precision_m double precision default null,
  p_velocidad_ms double precision default null,
  p_rumbo double precision default null,
  p_altitud double precision default null,
  p_bateria_pct integer default null,
  p_gps_activo boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_punto uuid;
begin
  if p_lat is null or p_lng is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'Coordenadas requeridas'
    );
  end if;

  if not exists (
    select 1
    from public.dtex_misiones
    where id_mision = p_id_mision
      and estado in ('EN_RUTA', 'EN_DESTINO', 'RETORNANDO', 'EMERGENCIA')
  ) then
    return jsonb_build_object(
      'ok', false,
      'error', 'Mision no activa para tracking'
    );
  end if;

  insert into public.dtex_tracking_gps (
    id_mision,
    latitud,
    longitud,
    precision_m,
    velocidad_ms,
    rumbo,
    altitud,
    bateria_pct,
    gps_activo
  )
  values (
    p_id_mision,
    p_lat,
    p_lng,
    p_precision_m,
    p_velocidad_ms,
    p_rumbo,
    p_altitud,
    p_bateria_pct,
    coalesce(p_gps_activo, true)
  )
  returning id_punto into v_id_punto;

  return jsonb_build_object(
    'ok', true,
    'id_punto', v_id_punto
  );
end;
$$;

create or replace function public.dtex_insertar_alerta(
  p_id_mision uuid,
  p_tipo text,
  p_severidad text,
  p_descripcion text,
  p_latitud double precision default null,
  p_longitud double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id_alerta uuid;
begin
  if not exists (
    select 1
    from public.dtex_misiones
    where id_mision = p_id_mision
      and estado in ('EN_RUTA', 'EN_DESTINO', 'RETORNANDO', 'EMERGENCIA')
  ) then
    return jsonb_build_object(
      'ok', false,
      'error', 'Mision no activa para alerta'
    );
  end if;

  insert into public.dtex_alertas (
    id_mision,
    tipo,
    severidad,
    latitud,
    longitud,
    descripcion,
    resuelta
  )
  values (
    p_id_mision,
    upper(trim(coalesce(p_tipo, 'INCONSISTENCIA'))),
    upper(trim(coalesce(p_severidad, 'AVISO'))),
    p_latitud,
    p_longitud,
    trim(coalesce(p_descripcion, 'Evento DTEX')),
    false
  )
  returning id_alerta into v_id_alerta;

  return jsonb_build_object(
    'ok', true,
    'id_alerta', v_id_alerta
  );
end;
$$;

grant execute on function public.dtex_validar_otp(text)
  to anon, authenticated;
grant execute on function public.dtex_validar_acceso_custodio(text, text)
  to anon, authenticated;
grant execute on function public.dtex_cambiar_estado(
  uuid,
  text,
  double precision,
  double precision
) to anon, authenticated;
grant execute on function public.dtex_reportar_tracking_gps(
  uuid,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  double precision,
  integer,
  boolean
) to anon, authenticated;
grant execute on function public.dtex_insertar_alerta(
  uuid,
  text,
  text,
  text,
  double precision,
  double precision
) to anon, authenticated;

notify pgrst, 'reload schema';

commit;
