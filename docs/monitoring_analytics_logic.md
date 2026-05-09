# Logica de analitica SCCP (Web Monitor)

## 1) Objetivo operativo
Generar tarjetas y graficos para lectura rapida por:
- alcance global,
- por grupo (`ALFA` / `BRAVO`),
- por oficial.

Con dos periodos:
- `DIA` (ventana operativa 08:00-08:00),
- `MES` (acumulado del mes en curso).

## 2) Tablas base y uso
- `oficiales`: universo nominal, grupo, IMEI, estado activo.
- `monitoreo_reportes`: actividad, bateria, gps, distancia a punto de control, estado alerta.
- `inconsistencias`: eventos disciplinarios y tecnicos clasificados.
- `partes_oficiales`: cumplimiento de partes obligatorios.
- `login_logs`: auditoria de sesiones administrativas web.

## 3) KPIs principales por tarjeta
- `Reportes`: total de registros de `monitoreo_reportes` en el rango.
- `Activos/Nominales`: oficiales con al menos un reporte vs oficiales activos esperados.
- `Cobertura %`: `activos / nominales * 100`.
- `Distancia promedio`: promedio `distancia_metros`.
- `Cumplimiento geocerca %`: `% de reportes con distancia <= 50m`.
- `Cumplimiento partes %`: `partes_completados / partes_esperados * 100`.
- `Inconsistencias abiertas/cerradas`: conteo por estado/resuelta.

## 4) Clasificacion de alertas (grafico por tipo)
- `ABANDONO`: `DISTANCIA_EXCEDIDA`, `FUERA_ZONA`, `GPS_FALSO`.
- `INCONSISTENCIA`: resto de tipos operativos.
- `FALTA_REPORTE`: tipo `FALTA_REPORTE`.

## 5) Series para graficos
- Distribucion de distancia: buckets `0-50`, `51-100`, `101-200`, `200+`.
- Bateria: buckets `<=20`, `21-60`, `>60`.
- Actividad:
  - `DIA`: por hora (24 buckets).
  - `MES`: por dia del mes.
- Tendencia 7 dias: conteo diario de reportes para contexto de ritmo operativo.

## 6) Reglas de consistencia
- Punto de control del reo es fijo (domicilio) y referencia principal para distancia.
- Rango de alerta geocerca: `50m`.
- Un oficial no debe contarse doble en activos; se usa `distinct id_oficial_ref`.
- Si no hay datos de inconsistencias en rango, el sistema cae a inferencia por `estado_alerta` y distancia.

## 7) Recomendaciones de visualizacion
- Primera fila: KPIs de volumen y cobertura.
- Segunda fila: cumplimiento geocerca/partes + estado de inconsistencias.
- Graficos: distancia y alertas siempre visibles; actividad y bateria en segunda prioridad.
- Mantener etiquetas cortas y color semantico estable (rojo=riesgo, cyan=operativo, verde=ok).
