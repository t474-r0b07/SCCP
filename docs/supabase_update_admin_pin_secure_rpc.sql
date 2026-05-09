-- SCCP - HARDENING PIN ADMIN (ACTUALIZACION)
-- Fecha: 2026-02-27
-- Objetivo: actualizar PIN solo via RPC y guardarlo hasheado.
-- Requisito: extension pgcrypto habilitada.

create extension if not exists pgcrypto;

create or replace function public.fn_update_admin_pin_secure(
  p_admin_id text,
  p_new_pin text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows integer := 0;
begin
  if coalesce(trim(p_admin_id), '') = '' or coalesce(trim(p_new_pin), '') = '' then
    return false;
  end if;

  if length(trim(p_new_pin)) < 4 then
    return false;
  end if;

  update public.allowed_admins
  set
    pin_seguridad = crypt(trim(p_new_pin), gen_salt('bf', 12)),
    updated_at = now()
  where id::text = trim(p_admin_id)
    and activo = true;

  get diagnostics v_rows = row_count;
  return v_rows > 0;
end;
$$;

revoke all on function public.fn_update_admin_pin_secure(text, text) from public;
grant execute on function public.fn_update_admin_pin_secure(text, text) to authenticated;
