# MANUAL DE USUARIO
## SCCP Command Center v1.0

---

## 📋 ÍNDICE

1. [Introducción](#introducción)
2. [Acceso al Sistema](#acceso-al-sistema)
3. [Dashboard Principal](#dashboard-principal)
4. [Módulo de Inconsistencias](#módulo-de-inconsistencias)
5. [Módulo de Partes Sorpresa](#módulo-de-partes-sorpresa)
6. [Módulo de Oficiales](#módulo-de-oficiales)
7. [Funciones Avanzadas](#funciones-avanzadas)
8. [Resolución de Problemas](#resolución-de-problemas)

---

## 1. INTRODUCCIÓN

### 1.1 Descripción General
SCCP Command Center es un sistema táctico de control y custodia policial diseñado con interfaz HUD militar para supervisión en tiempo real de oficiales, detección de inconsistencias y gestión de partes sorpresa.

### 1.2 Características Principales
- ✅ Autenticación segura con PIN aleatorio
- 🔄 Actualización en tiempo real
- 📊 Dashboard táctico con estadísticas visuales
- ⚠️ Sistema de alertas por prioridad
- 🔐 Resolución autorizada de inconsistencias
- 👥 Gestión de oficiales por grupos

---

## 2. ACCESO AL SISTEMA

### 2.1 Pantalla de Login

1. **Ingresar Email**
   - Introducir email de administrador autorizado
   - Presionar `CONTINUAR` o `Enter`

2. **Ingresar PIN de Seguridad**
   - Aparecerá un teclado numérico con números aleatorios (shuffled)
   - Los números cambian de posición en cada sesión por seguridad
   - Ingresar PIN de 4 dígitos
   - El sistema valida automáticamente

3. **Acceso Exitoso**
   - Redirige al Dashboard principal
   - Registra el login en `login_logs`

### 2.2 Niveles de Acceso
- **SUPERVISOR**: Acceso completo a monitoreo y resolución
- **DIRECTOR**: Acceso total incluyendo configuración

---

## 3. DASHBOARD PRINCIPAL

### 3.1 Barra Superior (Header)

**Elementos:**
- Logo SCCP con ícono de seguridad
- Nombre del administrador activo
- Fecha y hora actual
- Botón de actualización (⟳)
- Botón de cierre de sesión (⎋)

### 3.2 Navegación

**Pestañas disponibles:**
1. **DASHBOARD** - Vista general
2. **INCONSISTENCIAS** - Gestión de alertas
3. **PARTES** - Partes sorpresa
4. **OFICIALES** - Personal activo

### 3.3 Tarjetas de Estadísticas

**Métrica 1: OFICIALES ACTIVOS**
- Contador total de oficiales activos
- Desglose por grupo (Alfa/Bravo)
- Color: Cyan (#00FFD1)

**Métrica 2: ALERTAS CRÍTICAS**
- Reportes en estado CRÍTICO
- Cantidad de alertas intermedias
- Color: Rojo (#FF3B3B)

**Métrica 3: INCONSISTENCIAS**
- Inconsistencias abiertas
- En revisión
- Color: Naranja (#FFAA00)

**Métrica 4: PARTES PENDIENTES**
- Partes sin completar
- Partes vencidos (>2 horas)
- Color: Rosa (#FF006E)

### 3.4 Alertas Recientes

Lista de las 5 inconsistencias más críticas:
- Ícono según tipo
- Descripción breve
- Badge de prioridad con efecto pulse
- Al hacer clic: Ver detalles completos

---

## 4. MÓDULO DE INCONSISTENCIAS

### 4.1 Filtros Disponibles

**Barra de filtros:**
- `TODOS` - Todas las inconsistencias
- `ABIERTA` - Pendientes de revisión
- `EN_REVISION` - Siendo evaluadas
- `JUSTIFICADA` - Con justificación del oficial
- `CERRADA` - Resueltas

Cada filtro muestra contador en tiempo real.

### 4.2 Tarjetas de Inconsistencia

**Información mostrada:**
1. **Cabecera**
   - Ícono del tipo (GPS, Batería, etc.)
   - Tipo de inconsistencia
   - Badge de prioridad (BAJA/MEDIA/ALTA/CRÍTICA)

2. **Detalles**
   - ID del oficial involucrado
   - Descripción completa del evento
   - Estado actual
   - Fecha y hora de detección

3. **Justificación** (si existe)
   - Comentario del oficial
   - Ícono de comentario

### 4.3 Tipos de Inconsistencias

| Tipo | Ícono | Descripción |
|------|-------|-------------|
| GPS_FALSO | 📍 | GPS simulado o falseado |
| BATERIA_BAJA | 🔋 | Nivel crítico de batería |
| FUERA_ZONA | 🚫 | Fuera del área asignada |
| SIN_MOVIMIENTO | ⏸ | Sin actividad prolongada |
| DISTANCIA_EXCEDIDA | 📏 | Distancia anormal del reo |
| FALTA_REPORTE | 📋 | Reporte no enviado |

### 4.4 Resolver Inconsistencia

**Proceso:**
1. Hacer clic en tarjeta de inconsistencia
2. Se abre diálogo modal
3. Revisar información completa
4. Ingresar PIN de autorización (shuffled)
5. Sistema valida PIN
6. Si es correcto: Marca como CERRADA
7. Registra supervisor que resolvió
8. Actualiza timestamp de resolución

**Estados finales:**
- `JUSTIFICADA` - Explicación válida del oficial
- `CERRADA` - Resuelta por supervisor

---

## 5. MÓDULO DE PARTES SORPRESA

### 5.1 Información de Parte

**Tarjeta muestra:**
- Número de parte (primeros 8 caracteres del ID)
- ID del oficial asignado
- Ícono de estado (🆕 NUEVO, 👁 LEÍDO, ✅ COMPLETADO, ⏰ VENCIDO)
- Nombre del supervisor que generó el parte
- Razón del parte sorpresa
- Tiempo transcurrido desde creación
- Respuesta del oficial (si existe)

### 5.2 Estados del Parte

**NUEVO** (Cyan)
- Recién creado
- No leído por el oficial
- Pulso animado

**LEÍDO** (Naranja)
- Oficial ha visto el parte
- Pendiente de completar

**COMPLETADO** (Verde)
- Oficial ha respondido
- Muestra respuesta y coordenadas

**VENCIDO** (Rojo)
- Más de 2 horas sin completar
- Requiere atención inmediata

### 5.3 Tiempo de Respuesta

El sistema muestra:
- Tiempo en formato `Xh Ym` o `Xm`
- Color rojo si está vencido
- Badge pulsante para pendientes

---

## 6. MÓDULO DE OFICIALES

### 6.1 Vista de Grid

**Disposición:**
- Grid de 3 columnas
- Tarjetas con efecto hover
- Glow según grupo (Cyan=Alfa, Rosa=Bravo)

### 6.2 Información de Oficial

**Cabecera:**
- Ícono circular con símbolo de grupo (⍺ o β)
- ID del oficial
- Grado (Oficial III a Capitán)

**Datos:**
- Nombre completo
- Grupo asignado (ALFA/BRAVO)
- Reo bajo custodia (si aplica)

**Último Reporte:**
- Ubicación actual
- Nivel de batería con color:
  - Verde: >50%
  - Naranja: 20-50%
  - Rojo: <20%
- Badge de estado (NORMAL/ALERTA/CRÍTICO)

### 6.3 Grados Disponibles

1. Oficial III
2. Oficial II
3. Oficial I
4. Suboficial
5. Sargento
6. Teniente
7. Capitán

---

## 7. FUNCIONES AVANZADAS

### 7.1 Actualización Automática

**Suscripción en Tiempo Real:**
- Cambios en `monitoreo_reportes`
- Nuevas inconsistencias
- Actualización automática de contadores

### 7.2 Sistema de Colores

**Códigos de Color:**
- 🟢 Verde (#00FF88): Normal/OK
- 🟡 Naranja (#FFAA00): Alerta/Atención
- 🔴 Rojo (#FF3B3B): Crítico/Urgente
- 🔵 Cyan (#00FFD1): Activo/Primario
- 🟣 Rosa (#FF006E): Secundario/Especial

### 7.3 Efectos Visuales

**Hover:**
- Glow aumentado en tarjetas
- Borde más brillante
- Transición suave (200ms)

**Pulse:**
- Shimmer en badges críticos
- Ícono de seguridad en login
- Duración: 1.5-2 segundos

### 7.4 Atajos de Teclado

- `Ctrl + R` - Actualizar datos
- `Esc` - Cerrar modales
- `Enter` - Confirmar en formularios

---

## 8. RESOLUCIÓN DE PROBLEMAS

### 8.1 No puedo iniciar sesión

**Verificar:**
- Email correcto (debe estar en tabla `allowed_admins`)
- PIN de 4 dígitos
- Campo `activo = true` en la base de datos
- Conexión a Supabase

### 8.2 Los datos no se actualizan

**Soluciones:**
1. Presionar botón de actualización (⟳)
2. Verificar conexión a internet
3. Revisar configuración de Supabase Realtime
4. Refrescar página (F5)

### 8.3 El PIN no funciona

**Causas comunes:**
- PIN incorrecto (verificar en base de datos)
- Campo `pin_seguridad` no coincide
- Debe ser exactamente 4 dígitos numéricos

### 8.4 Tarjetas no muestran información

**Revisar:**
- Datos en tablas de Supabase
- Políticas de seguridad (RLS)
- Console del navegador (F12) para errores

### 8.5 Rendimiento lento

**Optimizaciones:**
- Limpiar caché del navegador
- Cerrar pestañas innecesarias
- Reducir animaciones en configuración
- Actualizar navegador a última versión

---

## 📞 SOPORTE TÉCNICO

**En caso de problemas persistentes:**

1. Revisar logs del navegador (F12 → Console)
2. Verificar configuración de Supabase
3. Comprobar permisos de base de datos
4. Validar estructura de tablas

---

**Versión del Manual:** 1.0  
**Última Actualización:** 2024  
**Sistema:** SCCP Command Center WebApp
