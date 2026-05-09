# SCCP - Netlify Security Lockdown v1.1.3

Objetivo:  
- Solo tú administras Netlify.  
- Solo 3 usuarios autorizados ingresan a la webapp (director + 2 supervisores).

## 1) Bloquear administración de Netlify solo para ti
1. Entra a `Netlify > Team settings > Members`.
2. Elimina cualquier miembro distinto a tu cuenta.
3. En `User settings > Security`, activa `Two-factor authentication (2FA)`.
4. En `User settings > Applications > Personal access tokens`, revoca tokens viejos y deja solo los necesarios.
5. Si usas `Deploy hooks`, regenera el hook y no lo compartas por chat público.

## 2) Aplicar seguridad HTTP del sitio
1. Este repo ya incluye `web/_headers` con hardening.
2. Al publicar una nueva build web, Netlify aplicará esos headers automáticamente.

## 3) Bloquear acceso web a solo 3 usuarios SCCP
1. Abre Supabase SQL Editor.
2. Ejecuta el script: `docs/supabase_lock_access_3_admins.sql`.
3. Antes de ejecutar, reemplaza los 3 correos de ejemplo por los reales.
4. Verifica que:
   - `public.allowed_admins` tenga solo esos 3 en `activo=true`.
   - `auth.users` deje no-baneados solo esos 3 correos.

## 4) Regla operativa
- No crear usuarios extra en `auth.users` ni `allowed_admins` para producción/campo.
- Cualquier alta/baja pasa por ese mismo script para mantener control.

