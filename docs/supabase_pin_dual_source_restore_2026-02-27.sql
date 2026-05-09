-- SCCP - RESTORE PIN DUAL SOURCE (allowed_admins + auth.users metadata)
-- Fecha: 2026-02-27
-- Objetivo:
-- 1) Mantener validacion estricta por RPC (sin fallback cliente inseguro).
-- 2) Restaurar compatibilidad con estructura dual de PIN.
-- 3) Sin retroceder seguridad: PIN se mantiene hasheado (bcrypt).

begin;

create extension if not exists pgcrypto;

create or replace function public.fn_pin_matches(
  p_stored text,
  p_input text
)
returns boolean
language plpgsql
as $$
declare
  v_stored text := coalesce(trim(p_stored), '');
  v_input text := coalesce(trim(p_input), '');
begin
  if v_stored = '' or v_input = '' then
    return false;
  end if;

  if v_stored like '$2%' then
    return crypt(v_input, v_stored) = v_stored;
  end if;

  -- Compatibilidad temporal con plaintext legacy.
  return v_stored = v_input;
end;
$$;

create or replace function public.fn_verify_admin_pin(
  p_email text,
  p_pin text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_input text := trim(coalesce(p_pin, ''));
  v_pin_allowed text;
  v_pin_auth text;
begin
  if v_email = '' or v_input = '' then
    return false;
  end if;

  -- Fuente primaria: allowed_admins (estructura SCCP vigente)
  select a.pin_seguridad
  into v_pin_allowed
  from public.allowed_admins a
  where lower(a.email) = v_email
    and a.activo = true
  limit 1;

  if coalesce(trim(v_pin_allowed), '') <> '' then
    return public.fn_pin_matches(v_pin_allowed, v_input);
  end if;

  -- Compatibilidad: auth.users metadata (estructura histórica)
  select coalesce(
           u.raw_user_meta_data->>'pin_seguridad',
           u.raw_user_meta_data->>'pin',
           u.raw_user_meta_data->>'security_pin',
           ''
         )
  into v_pin_auth
  from auth.users u
  where lower(u.email) = v_email
  limit 1;

  if coalesce(trim(v_pin_auth), '') <> '' then
    return public.fn_pin_matches(v_pin_auth, v_input);
  end if;

  return false;
end;
$$;

revoke all on function public.fn_verify_admin_pin(text, text) from public;
grant execute on function public.fn_verify_admin_pin(text, text) to authenticated;

create or replace function public.fn_update_admin_pin_secure(
  p_admin_id text,
  p_new_pin text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_admin_id text := trim(coalesce(p_admin_id, ''));
  v_new_pin text := trim(coalesce(p_new_pin, ''));
  v_hash text;
  v_email text;
  v_rows integer := 0;
begin
  if v_admin_id = '' or v_new_pin = '' then
    return false;
  end if;

  if length(v_new_pin) < 4 then
    return false;
  end if;

  v_hash := crypt(v_new_pin, gen_salt('bf', 12));

  update public.allowed_admins a
  set
    pin_seguridad = v_hash,
    updated_at = now()
  where a.id::text = v_admin_id
    and a.activo = true;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return false;
  end if;

  select a.email
  into v_email
  from public.allowed_admins a
  where a.id::text = v_admin_id
  limit 1;

  -- Sync dual-source en auth.users metadata.
  begin
    update auth.users u
    set
      raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb) ||
        jsonb_build_object(
          'pin_seguridad', v_hash,
          'pin', v_hash,
          'security_pin', v_hash
        ),
      updated_at = now()
    where lower(u.email) = lower(coalesce(v_email, ''));
  exception
    when others then
      -- No rompe update principal si auth.users no es editable en este entorno.
      null;
  end;

  return true;
end;
$$;

revoke all on function public.fn_update_admin_pin_secure(text, text) from public;
grant execute on function public.fn_update_admin_pin_secure(text, text) to authenticated;

-- Normaliza PIN legacy en allowed_admins a bcrypt (idempotente).
update public.allowed_admins
set
  pin_seguridad = crypt(pin_seguridad, gen_salt('bf', 12)),
  updated_at = now()
where coalesce(trim(pin_seguridad), '') <> ''
  and pin_seguridad not like '$2%';

-- Sync inicial allowed_admins -> auth.users (dual source).
update auth.users u
set
  raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb) ||
    jsonb_build_object(
      'pin_seguridad', a.pin_seguridad,
      'pin', a.pin_seguridad,
      'security_pin', a.pin_seguridad
    ),
  updated_at = now()
from public.allowed_admins a
where lower(u.email) = lower(a.email)
  and a.activo = true
  and coalesce(trim(a.pin_seguridad), '') <> '';

commit;

-- Verificación rápida:
-- select public.fn_verify_admin_pin('director@dominio.com', '123456');
