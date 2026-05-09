-- SCCP - BLOQUEO DE ACCESO WEB A 3 USUARIOS AUTORIZADOS
-- Ejecutar en Supabase SQL Editor (proyecto de prueba/campo).
-- 1) Reemplaza los 3 correos por los reales ANTES de ejecutar.
-- 2) Este script deja solo esos 3 con acceso web activo.

begin;

-- ==========================
-- CONFIGURACION (EDITAR)
-- ==========================
-- Reemplaza estos correos por los reales:
-- director@dominio.com
-- supervisor1@dominio.com
-- supervisor2@dominio.com

with autorizados as (
  select lower(email) as email, nivel
  from (
    values
      ('director@dominio.com', 'DIRECTOR'),
      ('supervisor1@dominio.com', 'SUPERVISOR'),
      ('supervisor2@dominio.com', 'SUPERVISOR')
  ) v(email, nivel)
)

-- ==========================
-- allowed_admins: solo 3 activos
-- ==========================
, desactivar_otros as (
  update public.allowed_admins a
  set activo = false,
      updated_at = now()
  where lower(a.email) not in (select email from autorizados)
  returning a.email
)
, activar_autorizados as (
  update public.allowed_admins a
  set activo = true,
      nivel_acceso = z.nivel,
      updated_at = now()
  from autorizados z
  where lower(a.email) = z.email
  returning a.email
)

-- ==========================
-- auth.users: bloquear resto de cuentas
-- ==========================
, bloquear_auth_no_autorizados as (
  update auth.users u
  set banned_until = 'infinity'
  where lower(coalesce(u.email, '')) not in (select email from autorizados)
  returning u.email
)
, desbloquear_auth_autorizados as (
  update auth.users u
  set banned_until = null
  where lower(coalesce(u.email, '')) in (select email from autorizados)
  returning u.email
)
select 'OK_LOCK_3_ADMINS' as status;

commit;

-- ==========================
-- VERIFICACION RAPIDA
-- ==========================
-- Debe devolver solo 3 filas activas en allowed_admins.
select
  email,
  nombre,
  nivel_acceso,
  activo
from public.allowed_admins
where activo = true
order by nivel_acceso desc, email asc;

-- Debe devolver solo 3 usuarios NO baneados en auth.users.
select
  email,
  banned_until
from auth.users
where banned_until is null
order by email asc;

