-- DTEX - bucket de evidencias para reportes con foto del custodio.
--
-- Ejecutar en Supabase SQL Editor antes de probar reportes con foto.
-- Bucket: dtex-reportes

begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'dtex-reportes',
  'dtex-reportes',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists dtex_reportes_public_read
  on storage.objects;
drop policy if exists dtex_reportes_anon_insert
  on storage.objects;
drop policy if exists dtex_reportes_auth_insert
  on storage.objects;

create policy dtex_reportes_public_read
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'dtex-reportes');

create policy dtex_reportes_anon_insert
  on storage.objects
  for insert
  to anon
  with check (bucket_id = 'dtex-reportes');

create policy dtex_reportes_auth_insert
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'dtex-reportes');

commit;

-- Verificacion:
-- select id, name, public, file_size_limit, allowed_mime_types
-- from storage.buckets
-- where id = 'dtex-reportes';
