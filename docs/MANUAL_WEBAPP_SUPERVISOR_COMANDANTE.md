# Manual Descriptivo WebApp SCCP

## 1) Objetivo del manual
Este manual explica, en palabras simples, como se ve la WebApp y para que sirve cada parte visual.
No incluye explicaciones tecnicas internas.

## 2) Perfiles y diferencia general

| Perfil | Enfoque principal | Que puede hacer |
|---|---|---|
| Supervisor | Operacion diaria en tiempo real | Ver estado del turno, revisar alertas, usar radio, solicitar parte sorpresa, gestionar oficiales |
| Comandante | Vision de mando, control historico y analitica | Ver operativo general, revisar recorrido historico, usar panel avanzado de estadisticas, ejecutar modo espia |

## 3) Acceso y navegacion inicial

| Pantalla | Elementos visibles | Funcion para el usuario |
|---|---|---|
| Login | Campos `OPERATOR_ID` y `ACCESS_KEY`, boton `AUTHORIZE SYSTEM` | Ingreso al sistema |
| Validacion Director | Teclado PIN (`VALIDACION DIRECTOR`) | Segunda validacion para abrir panel de Comandante |
| Entrada automatica | Redireccion por rol | Supervisor entra a `Dashboard Supervisor`. Director entra a `Dashboard Comandante` |

## 4) Interfaz Supervisor (Dashboard Supervisor)

### 4.1 Encabezado superior

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Titulo `SCCP COMMAND CENTER` | Nombre del sistema | Identificacion de pantalla |
| Bloque `GRUPO ALFA/BRAVO` | Grupo activo del turno | Confirmar grupo en servicio |
| Bloque usuario/rol | Nombre y nivel de acceso | Saber quien esta operando |
| Boton `Partes Sorpresa` | Icono rayo | Abre modulo de solicitud directa de parte sorpresa |
| Boton `Radio Operativa` | Icono radio + punto/contador rojo | Abre chat/radio con prioridad de no leidos |
| Boton `Gestionar Oficiales` | Icono de gestion | Abre modulo de altas/cambios/bajas y acciones masivas |

### 4.2 Tarjeta `ESTADO OPERATIVO`

| Componente | Que muestra | Lectura simple |
|---|---|---|
| Medidor circular `TURNO` | Porcentaje de cumplimiento | Mientras mas alto, mejor estado del turno |
| Dona `Activos/Inactivos` | Relacion `activos/20` | Cuantos estan activos frente al total esperado |
| Mini grafico `TENDENCIA TURNO` | Evolucion corta reciente | Si sube, mejora actividad; si baja, se enfria |
| Indicador `RIESGO ACTIVO` | Numero de alertas activas | Si sube, hay mas presion operativa |
| Toque sobre tarjeta | Abre `ALERTAS DEL DIA - GRUPO` | Lista rapida por oficial con estado, bateria y GPS |

### 4.3 Tarjeta `ALERTAS CRITICAS`

| Componente | Que muestra | Lectura simple |
|---|---|---|
| Medidor `RIESGO` | Nivel global de riesgo | Valor alto = atencion inmediata |
| Dona `PROBLEMAS` | Total visible de problemas | Resumen rapido de criticidad |
| Indicador circular `ALERTAS` | Total de alertas | Vista compacta del volumen actual |
| Barras `CRIT / GPS / BAT` | Cantidad por tipo | Permite ver que categoria pesa mas |
| Toque sobre tarjeta | Abre `ALERTAS AGRUPADAS DEL TURNO` | Ordena primero alertas nuevas/no leidas |

### 4.4 Dialogo `ALERTAS AGRUPADAS DEL TURNO`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Chips de resumen | `ACTIVAS`, `NUEVAS`, `RESUELTAS`, `CRITICAS`, `GPS`, `BATERIA` | Lectura ejecutiva instantanea |
| Lista de alertas | Oficial, motivo, distancia, duracion, reportes en alerta, bateria | Revisar caso por caso |
| Marca `NUEVO` (punto rojo) | Alerta sin revisar | Ayuda a priorizar |
| Flecha lateral en item | Acceso al detalle del oficial | Abrir perfil detallado del oficial |
| Boton `X` | Cerrar dialogo | Volver al panel principal |

### 4.5 Tarjeta `TELEMETRIA`

| Componente | Que muestra | Lectura simple |
|---|---|---|
| Panel baterias | Niveles de bateria por dispositivos | Ver salud energetica |
| Panel senal | Intensidad general de senal | Ver estabilidad de comunicacion |
| Caja `CONECTADOS` | `online/total`, resumen `GPS` y `BAT` | Estado rapido de conectividad |
| Indicador de estado | Online/Offline | Confirmar estado general |
| Toque sobre tarjeta | Abre vista detallada de telemetria | Analisis ampliado del hardware |

### 4.6 Dialogo de telemetria detallada

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Bloque de estado superior | `DISPOSITIVOS`, `GPS OFFLINE`, `BATERIA BAJA`, `CRITICOS` | Resumen tecnico visual |
| Panel `ENERGY CELL` | Nivel de bateria del ultimo dispositivo | Lectura visual de energia |
| Panel `SPECTRUM RADAR` | Actividad de senal | Referencia visual de movimiento de senal |
| Panel `CORE DIAGNOSTICS` | Modelo, dispositivo, ultimo ping, bateria, GPS, estado | Ficha de estado actual |
| Panel `MULTI-LINE SIGNALS` | Tendencia multisenal | Comparacion visual de lineas |
| Boton `REINICIAR ENLACE` | Accion visual de reconexion | Reintento de enlace |
| Boton `PING` | Prueba de respuesta | Confirmacion de respuesta del dispositivo |
| Boton `X` | Cerrar dialogo | Volver al dashboard |

### 4.7 Centro `MAPA` (hub central)

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Mapa tactico | Posicion de oficiales, punto de control, lineas de distancia | Monitoreo visual en tiempo real |
| Marcador oficial | Estado normal o alerta (pulso/color) | Identificar quien requiere atencion |
| Marcador punto de control | Ubicacion de referencia del control | Ver separacion oficial-punto |
| Panel `ALERTAS RECIENTES` | Ultimos eventos con motivo y distancia | Priorizar respuesta inmediata |
| Leyenda `JURISDICCION` | Zonas y colores | Contexto geografico por area |
| Boton `fullscreen` | Pantalla completa | Mejor lectura del mapa |
| Boton `centrar` | Reenfoque del mapa | Volver al area operativa |
| Boton `capas` | Mostrar/ocultar jurisdicciones | Limpieza visual del mapa |
| Boton `POI` | Mostrar/ocultar puntos de referencia | Ver locales y referencias utiles |

### 4.8 Tarjeta `INCONSISTENCIAS`

| Componente | Que muestra | Lectura simple |
|---|---|---|
| Mini grafico `DIARIAS (TOTAL/CRIT)` | Evolucion diaria total y critica | Ver si la tendencia sube o baja |
| Mini grafico `MENSUALES` | Acumulado mensual | Ver carga historica reciente |
| Lista de inconsistencias | Prioridad, tipo, oficial, estado, hora | Bandeja de revision |
| Toque sobre item | Abre `RESOLVER INCONSISTENCIA` | Revisar detalle y autorizar cierre |

### 4.9 Dialogo `RESOLVER INCONSISTENCIA`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Titulo y descripcion | Tipo y detalle del caso | Entender el incidente |
| Panel PIN `AUTORIZAR RESOLUCION` | Teclado PIN | Cierre seguro de inconsistencia |
| Boton `X` | Cerrar | Salir del detalle |

### 4.10 Tarjeta `ESTADISTICAS`

| Componente | Que muestra | Lectura simple |
|---|---|---|
| Medidor `COV` | Cobertura de personal | Nivel de cobertura del turno |
| Medidor `GEO<=50m` | Cumplimiento de geocerca | Que tanto se mantiene el control de distancia |
| Medidor `RISK_IDX` | Riesgo acumulado | Estado global de amenaza |
| Barras ALFA/BRAVO | Activos sobre nominal por grupo | Balance operativo por grupo |
| Mini lineas `RPT_7D` y `ACT_7D` | Tendencia semanal de reportes/actividad | Evolucion de la semana |
| Barras `DIST[m]` | Distancias por rango | Distribucion de desplazamientos |
| Barras `BAT[%]` | Bateria por rango | Estado energetico agrupado |
| Barras `ALT[TIPO]` | Alertas por tipo | Donde se concentra el problema |

### 4.11 Dialogo `ESTADISTICAS` (vista ampliada)

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Resumen superior (6 KPI) | `RPT`, `ACT`, `NOM`, `COV`, `GEO50`, `RISK` | Lectura ejecutiva inmediata |
| `GROUP_LOAD` | Carga por grupo ALFA/BRAVO | Comparacion de esfuerzo operativo |
| Graficos grandes | `RPT_7D`, `ACT_7D`, `DIST[m]`, `BAT[%]`, `ALT[TIPO]` | Analisis visual ampliado |
| Boton `X` | Cerrar dialogo | Regresar al panel |

## 5) Modulos emergentes del Supervisor

### 5.1 Modulo `PARTES SORPRESA - SUPERVISION`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Dropdown `Oficial` | Oficial activo del turno | Elegir destinatario |
| Campo `Razon tactica` | Motivo del pedido | Contexto del requerimiento |
| Boton `Activar` | Envio directo de solicitud | Disparar parte sorpresa al instante |
| Lista inferior de partes | Estado, oficial, supervisor, razon, tiempo, respuesta | Seguimiento de solicitudes |
| Boton `X` | Cerrar | Volver al panel |

### 5.2 Modulo `RADIO OPERATIVA - SUPERVISOR`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Dropdown `Canal oficial` | Lista de oficiales (ordenada por no leidos) | Entrar al canal correcto mas rapido |
| Badge numerico por oficial | Mensajes sin leer por canal | Priorizacion visual |
| Boton `Parte Sorpresa` | Solicitud inmediata de parte | Atajo de control sorpresa |
| Estado `RADIO VOZ` | Si hay llamada activa y hora de inicio | Control de llamada en curso |
| Boton `Iniciar` | Iniciar llamada de voz | Abrir comunicacion de voz |
| Boton `Finalizar` | Cerrar llamada de voz | Terminar comunicacion |
| Burbujas de chat | Mensajes con encabezado simple (`SUPERVISOR` / nombre oficial) | Lectura clara de conversaciones |
| Etiqueta `NUEVO` | Mensaje entrante no leido | Prioridad de atencion |
| Etiqueta `PARTE CON NOVEDAD` | Mensaje formal de parte con novedad | Distinguirlo de chat comun |
| Campo `Resumen de llamada (opcional)` | Nota breve de cierre | Registrar resumen |
| Campo `Mensaje por radio` | Texto libre | Mensajeria directa |
| Boton `Enviar` | Enviar mensaje | Comunicacion textual |
| Boton `X` | Cerrar | Salir del modulo |

### 5.3 Modulo `GESTION DE OFICIALES`

| Seccion | Elementos | Para que sirve |
|---|---|---|
| Lista oficiales | Busqueda visual, checks de seleccion, estado activo/inactivo | Seleccion individual o masiva |
| Flujo guiado paso 1 | Botones `REGISTRAR`, `MODIFICAR`, `ELIMINAR` | Elegir tipo de accion |
| Flujo guiado paso 2 | Dropdown `GRUPO` | Definir grupo del oficial |
| Flujo guiado paso 3 | Campos de oficial y opcion de registrar reo nuevo | Completar/editar datos |
| Flujo guiado paso 4 | Botones `NUEVO`, `GUARDAR REGISTRO`, `GUARDAR CAMBIOS`, `ELIMINAR OFICIAL`, `REACTIVAR` | Confirmar accion |
| Acciones masivas | `APLICAR GRUPO`, `DESACTIVAR SELECCION`, `ACTIVAR SELECCION` | Cambios en lote |
| Reemplazo rapido | `OFICIAL SALIENTE`, `OFICIAL ENTRANTE`, `APLICAR REEMPLAZO` | Cambio operativo rapido |
| Seguridad | Confirmacion con PIN (`CONFIRMAR CAMBIO`) | Control de autorizacion |
| Boton `X` | Cerrar modulo | Salir |

### 5.4 Dialogo de perfil detallado del oficial

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Bloque `PERFIL OPERATIVO` | Indicadores circulares de actividad, partes y alertas | Estado resumido del oficial |
| Bloque `ACTIVIDAD RECIENTE` | Ultimos reportes y partes | Ver secuencia reciente |
| Bloques de cumplimiento y calificacion | Cumplimiento y calificacion visual | Lectura rapida de desempeno |
| Bloque `HIST2D ACTIVIDAD` | Grafico visual de actividad | Ver patron de movimiento operativo |
| Bloques de estado | Ultimo reporte y estado actual | Situacion puntual del oficial |
| Boton `X` | Cerrar | Volver a la vista anterior |

## 6) Interfaz Comandante (Dashboard Comandante)

### 6.1 Encabezado comandante

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Titulo `SCCP COMMANDANTE` | Panel de mando | Identidad del entorno de comandante |
| Tabs principales | `OPERATIVO`, `MAPA HIST`, `ESTADISTICAS`, `MODO ESPIA` | Navegacion por modulo |
| Bloque de usuario | Nombre y nivel del director | Confirmar sesion |
| Boton `logout` | Cerrar sesion | Salir del sistema |

### 6.2 Tab `OPERATIVO`

| Contenido | Lectura |
|---|---|
| Es la misma vista operativa de tarjetas (estado, alertas, telemetria, mapa, inconsistencias, estadisticas) | Permite al comandante mirar la operacion en tiempo real |

Nota: en esta vista se muestra el panel operativo, pero no aparecen los 3 botones rapidos del encabezado de Supervisor.

### 6.3 Tab `MAPA HIST`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Panel izquierdo `OFICIALES` | Lista de oficiales | Elegir objetivo de revision |
| Boton `DIA dd/mm/yyyy` | Fecha de consulta | Cambiar dia del recorrido |
| Mapa de recorrido | Ruta del oficial seleccionado | Revisar desplazamiento historico |
| Marcador inicio/fin | Punto de arranque y ultimo punto | Entender trayectoria |
| Contador `N UBICACIONES` | Total de puntos del dia | Medir densidad de recorrido |

### 6.4 Tab `ESTADISTICAS`

| Bloque | Elementos | Para que sirve |
|---|---|---|
| Selector de alcance | Subtabs `GLOBAL`, `POR GRUPO`, `INDIVIDUAL` | Cambiar nivel de analisis |
| Botones de informe | `INFORME GLOBAL`, `INFORME GRUPO`, `INFORME OFICIAL` | Generar reporte segun alcance |
| Periodo | Chips `DIA` y `MES` | Cambiar ventana de lectura |
| Filtros | Dropdown de grupo u oficial (segun subtab) | Enfocar resultados |
| KPI fila 1 | `REPORTES`, `ACTIVOS`, `COBERTURA`, `DISTANCIA PROM` | Estado operativo base |
| KPI fila 2 | `GEOCERCA`, `PARTES`, `INCONS. ABIERTAS`, `INCONS. CERRADAS` | Cumplimiento y control |
| Graficos | `VARIEDAD DE DISTANCIAS`, `CUMPLIMIENTO GEOCERCA`, `ACTIVIDAD HORARIA/DIARIA`, `ESTADO BATERIA`, `TENDENCIA 7 DIAS`, `ALERTAS POR TIPO` | Analisis visual completo |

### 6.5 Tab `MODO ESPIA`

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Dropdown `SELECCIONA OBJETIVO` | Oficial objetivo | Elegir a quien aplicar control estricto |
| Campo `MOTIVO OPERATIVO` | Texto libre | Registrar motivo de intervencion |
| Boton `EJECUTAR MODO ESPIA` | Disparo de accion | Ejecutar intervencion |
| Panel `RESULTADO DE INTERVENCION` | Resultado detallado | Ver salida del proceso |

### 6.6 Pantalla de seguridad comandante

| Elemento | Que muestra | Para que sirve |
|---|---|---|
| Titulo `ACCESO COMANDANTE` | Bloqueo de seguridad | Controlar acceso al panel |
| Teclado PIN `INGRESE PIN DE DIRECTOR` | Validacion obligatoria | Habilitar panel comandante |
| Boton `CERRAR SESION` | Salida segura | Cancelar acceso |

## 7) Diferencias directas: Supervisor vs Comandante

| Tema | Supervisor | Comandante |
|---|---|---|
| Enfoque | Operacion minuto a minuto | Mando, historico y analitica profunda |
| Botones rapidos arriba | Si: `Partes Sorpresa`, `Radio Operativa`, `Gestionar Oficiales` | No en encabezado comandante |
| Radio y partes sorpresa | Uso operativo directo | Consulta global; no modulo de radio rapido en header |
| Gestion de oficiales | Disponible en modulo dedicado | No como accion principal de cabecera |
| Mapa historico | No como modulo principal propio | Si, tab dedicado |
| Estadistica avanzada por alcance | Basica y ampliada desde tarjeta | Completa con GLOBAL/POR GRUPO/INDIVIDUAL |
| Modo espia | No | Si, tab exclusivo |

## 8) Glosario visual rapido (para lectura de graficos)

| Etiqueta | Significado simple |
|---|---|
| `RPT_7D` | Reportes de los ultimos 7 dias |
| `ACT_7D` | Actividad de oficiales en 7 dias |
| `DIST[m]` | Distancias por rangos en metros |
| `BAT[%]` | Estado de bateria por rangos |
| `ALT[TIPO]` | Alertas agrupadas por tipo |
| `COV` | Cobertura del personal esperado |
| `GEO50` o `GEO<=50m` | Cumplimiento de geocerca |
| `RISK` o `RISK_IDX` | Nivel global de riesgo |

---

Manual listo para presentacion ejecutiva. Lenguaje simple, orientado a uso operativo.
