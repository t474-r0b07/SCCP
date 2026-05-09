-- SCCP - HARDENING PIN ADMIN
-- Fecha: 2026-02-27
-- Objetivo: validar PIN sin exponer hash/texto del PIN al cliente.
-- Requisito: extension pgcrypto habilitada.

create extension if not exists pgcrypto;

create or replace function public.fn_verify_admin_pin(
  p_email text,
  p_pin text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match boolean := false;
begin
  if coalesce(trim(p_email), '') = '' or coalesce(trim(p_pin), '') = '' then
    return false;
  end if;

  select exists (
    select 1
    from public.allowed_admins a
    where lower(a.email) = lower(trim(p_email))
      and a.activo = true
      and (
        (
          a.pin_seguridad like '$2%'
          and crypt(trim(p_pin), a.pin_seguridad) = a.pin_seguridad
        )
        or a.pin_seguridad = trim(p_pin)
      )
  )
  into v_match;

  return v_match;
end;
$$;

revoke all on function public.fn_verify_admin_pin(text, text) from public;
grant execute on function public.fn_verify_admin_pin(text, text) to authenticated;
