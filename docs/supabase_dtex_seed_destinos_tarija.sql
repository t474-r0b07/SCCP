-- DTEX - destinos predefinidos Tarija para pruebas operativas.
--
-- Fuente: /home/f-society/Descargas/dtex_ubicaciones.csv
-- Ejecutar despues de tener creada la tabla public.dtex_destinos.
--
-- Notas:
-- - El script es idempotente: actualiza por nombre normalizado o inserta si no existe.
-- - SIGEP Tarija queda pendiente porque el CSV no trae latitud/longitud.
-- - Tipos DTEX usados por la app:
--     JUDICIAL, HOSPITALARIO, ADMINISTRATIVO

begin;

create extension if not exists pgcrypto;

create temp table tmp_dtex_destinos_seed (
  nombre text not null,
  categoria text not null,
  tipo text not null,
  direccion text not null,
  latitud double precision not null,
  longitud double precision not null,
  radio_metros integer not null default 80
) on commit drop;

insert into tmp_dtex_destinos_seed (
  nombre,
  categoria,
  tipo,
  direccion,
  latitud,
  longitud,
  radio_metros
)
values
  ('Palacio de Justicia', 'Judicial/Institucional', 'JUDICIAL', 'Palacio de Justicia, Tarija', -21.532975, -64.732031, 80),
  ('Fiscalía Departamental', 'Judicial/Institucional', 'JUDICIAL', 'Gral. Trigo, Tarija', -21.540100, -64.728683, 80),
  ('Tribunal Dptl. de Justicia', 'Judicial/Institucional', 'JUDICIAL', 'Palacio de Justicia, Tarija', -21.532909, -64.732090, 80),
  ('SEGIP (Central)', 'Judicial/Institucional', 'ADMINISTRATIVO', 'Av. de la Integración, Tarija', -21.525602, -64.742580, 80),
  ('SERECI', 'Judicial/Institucional', 'ADMINISTRATIVO', 'Campero 630, Tarija', -21.532711, -64.735124, 80),
  ('INTRAID', 'Judicial/Institucional', 'ADMINISTRATIVO', 'Junín, Tarija', -21.531162, -64.726409, 80),
  ('Hospital Regional San Juan de Dios', 'Salud Pública', 'HOSPITALARIO', 'Tarija', -21.529022, -64.725502, 120),
  ('Hospital del Quemado', 'Salud Pública', 'HOSPITALARIO', 'Tarija', -21.531027, -64.727212, 100),
  ('Hospital Oncológico', 'Salud Pública', 'HOSPITALARIO', 'Tarija - verificar ubicación', -21.520315, -64.714429, 100),
  ('Hospital Obrero Nº7 CNS', 'Salud Pública', 'HOSPITALARIO', 'Rosendo Estensoro 1365, Tarija', -21.534969, -64.720366, 100),
  ('Hospital 2° Nivel San Antonio', 'Salud Pública', 'HOSPITALARIO', 'Tarija', -21.529343, -64.760763, 100),
  ('Centro de Salud San Jorge', 'Salud Pública', 'HOSPITALARIO', 'Tarija', -21.552571, -64.696867, 80),
  ('Centro de Salud Palmarcito', 'Salud Pública', 'HOSPITALARIO', 'C. Esmeralda, Tarija', -21.536090, -64.709695, 80),
  ('Caja de Salud CORDES', 'Caja/Clínica', 'HOSPITALARIO', 'Juan Misael Saracho 948, Tarija', -21.529570, -64.734986, 80),
  ('Clínica Yapur', 'Caja/Clínica', 'HOSPITALARIO', 'Virginio Lema 441, Tarija', -21.536572, -64.729890, 80),
  ('Clínica La Familia', 'Caja/Clínica', 'HOSPITALARIO', 'C. Núñez del Prado, Tarija', -21.525802, -64.735936, 80),
  ('SANITTES Centro Médico', 'Caja/Clínica', 'HOSPITALARIO', 'Ingavi 1246, Tarija', -21.536716, -64.722211, 80),
  ('Centro Médico San Martín', 'Caja/Clínica', 'HOSPITALARIO', 'Av. Los Parrales 0196, Tarija', -21.532290, -64.746171, 80),
  ('Clínica Ntra. Sra. de Lucía', 'Caja/Clínica', 'HOSPITALARIO', 'Gral. Trigo, Tarija', -21.535252, -64.735283, 80);

do $$
declare
  v_actualizados integer := 0;
  v_insertados integer := 0;
begin
  update public.dtex_destinos d
  set tipo = s.tipo,
      direccion = s.direccion,
      latitud = s.latitud,
      longitud = s.longitud,
      radio_metros = s.radio_metros,
      activo = true
  from tmp_dtex_destinos_seed s
  where lower(regexp_replace(trim(d.nombre), '\s+', ' ', 'g')) =
        lower(regexp_replace(trim(s.nombre), '\s+', ' ', 'g'));

  get diagnostics v_actualizados = row_count;

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
  select
    gen_random_uuid(),
    s.nombre,
    s.tipo,
    s.direccion,
    s.latitud,
    s.longitud,
    s.radio_metros,
    true
  from tmp_dtex_destinos_seed s
  where not exists (
    select 1
    from public.dtex_destinos d
    where lower(regexp_replace(trim(d.nombre), '\s+', ' ', 'g')) =
          lower(regexp_replace(trim(s.nombre), '\s+', ' ', 'g'))
  );

  get diagnostics v_insertados = row_count;

  raise notice 'DTEX destinos Tarija listos. actualizados=%, insertados=%, pendiente_sin_coordenadas=%',
    v_actualizados,
    v_insertados,
    'SIGEP Tarija';
end $$;

commit;

-- Verificacion rapida:
-- select nombre, tipo, direccion, latitud, longitud, radio_metros, activo
-- from public.dtex_destinos
-- where nombre in (
--   'Palacio de Justicia',
--   'Hospital Regional San Juan de Dios',
--   'Clínica Yapur'
-- )
-- order by nombre;
