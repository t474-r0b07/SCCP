-- DTEX - alineacion conservadora de schema Supabase
-- Revisar en staging antes de ejecutar en produccion.

-- OTP: el codigo cliente genera 6 digitos. Si la columna quedo como
-- character(1) o character sin longitud util, esta migracion preserva el valor
-- existente y habilita el flujo real de 6 digitos.
alter table public.dtex_misiones
  alter column codigo_otp type varchar(6)
  using left(trim(codigo_otp::text), 6);

alter table public.dtex_misiones
  alter column codigo_otp set not null;

alter table public.dtex_misiones
  drop constraint if exists dtex_misiones_codigo_otp_chk;

alter table public.dtex_misiones
  add constraint dtex_misiones_codigo_otp_chk
  check (codigo_otp ~ '^[0-9]{6}$');

-- Conducta final: alinear con el CHECK ya informado para que el cliente nunca
-- envie texto libre.
alter table public.dtex_misiones
  drop constraint if exists dtex_misiones_conducta_final_chk;

alter table public.dtex_misiones
  add constraint dtex_misiones_conducta_final_chk
  check (
    conducta_final is null
    or conducta_final in (
      'SIN_INCIDENCIAS',
      'CON_OBSERVACIONES',
      'CON_INCIDENCIAS_GRAVES'
    )
  );

-- Estados operativos DTEX. Se mantiene compatibilidad con los nombres actuales
-- del codigo y se agrega REGISTRO_REALIZADO para el paso posterior al OTP.
alter table public.dtex_misiones
  drop constraint if exists dtex_misiones_estado_chk;

alter table public.dtex_misiones
  add constraint dtex_misiones_estado_chk
  check (
    estado in (
      'PENDIENTE',
      'REGISTRO_REALIZADO',
      'EN_RUTA',
      'EN_DESTINO',
      'RETORNANDO',
      'CERRADA',
      'EMERGENCIA',
      'CANCELADA'
    )
  );

