-- =========================================================
-- HOTFIX URGENTE - AUDIT TRIGGER PERMISSIONS
-- Fecha: 2026-02-23
-- Uso: ejecutar de inmediato si falla insercion operativa con:
--      "permission denied for table audit_eventos"
-- =========================================================

begin;

-- audit_eventos: cliente solo inserta (sin lectura/edicion)
revoke all on public.audit_eventos from anon, authenticated;
grant insert on public.audit_eventos to anon, authenticated;
alter table if exists public.audit_eventos enable row level security;

drop policy if exists audit_eventos_insert_auth_anon on public.audit_eventos;
create policy audit_eventos_insert_auth_anon
  on public.audit_eventos
  for insert
  to anon, authenticated
  with check (true);

-- deleted_records_backup: cliente solo inserta (sin lectura/edicion)
revoke all on public.deleted_records_backup from anon, authenticated;
grant insert on public.deleted_records_backup to anon, authenticated;
alter table if exists public.deleted_records_backup enable row level security;

drop policy if exists deleted_records_backup_insert_auth_anon on public.deleted_records_backup;
create policy deleted_records_backup_insert_auth_anon
  on public.deleted_records_backup
  for insert
  to anon, authenticated
  with check (true);

commit;

-- Verificacion rapida
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename in ('audit_eventos', 'deleted_records_backup')
order by tablename, policyname;

