# 🎯 SCCP COMMAND CENTER - GUÍA DE COMPILACIÓN

## 📋 PREREQUISITOS

1. **Flutter SDK** instalado (versión >= 3.0.0)
   - Descarga desde: https://flutter.dev/docs/get-started/install
   - Verifica con: `flutter --version`

2. **Cuenta de Supabase**
   - Crea una cuenta en: https://supabase.com
   - Crea un nuevo proyecto

## 🔧 CONFIGURACIÓN INICIAL

### 1. Configurar Supabase

Edita el archivo `lib/core/constants/app_constants.dart`:

```dart
// Líneas 42-43
static const String supabaseUrl = 'https://TU-PROYECTO.supabase.co';
static const String supabaseAnonKey = 'TU-ANON-KEY-AQUI';
```

Para obtener estas credenciales:
1. Ve a tu proyecto en Supabase
2. Settings > API
3. Copia "Project URL" y "anon/public key"

### 2. Instalar Dependencias

```bash
cd sccp_tactical
flutter pub get
```

## 🚀 COMPILACIÓN Y EJECUCIÓN

### Para Web (Recomendado)

```bash
# Modo desarrollo
flutter run -d chrome

# Modo producción
flutter build web --release
```

Los archivos compilados estarán en `build/web/`

### Para Windows

```bash
flutter build windows --release
```

### Para macOS

```bash
flutter build macos --release
```

### Para Linux

```bash
flutter build linux --release
```

## 📊 ESTRUCTURA DE BASE DE DATOS REQUERIDA

### Tabla: oficiales_maestro

```sql
CREATE TABLE oficiales_maestro (
  id_oficial TEXT PRIMARY KEY,
  nombre_oficial TEXT NOT NULL,
  grupo TEXT NOT NULL,
  grado TEXT DEFAULT '1',
  turno TEXT,
  reo_asignado TEXT,
  imei TEXT,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Tabla: monitoreoreportes

```sql
CREATE TABLE monitoreoreportes (
  id_reporte TEXT PRIMARY KEY,
  id_oficial_ref TEXT REFERENCES oficiales_maestro(id_oficial),
  nombre_oficial TEXT,
  reo_asignado TEXT,
  ubicacion_actual TEXT,
  latitud DOUBLE PRECISION,
  longitud DOUBLE PRECISION,
  distancia_metros DOUBLE PRECISION,
  estado_alerta TEXT DEFAULT 'NORMAL',
  nivel_bateria INTEGER,
  gps_real BOOLEAN DEFAULT true,
  movimiento BOOLEAN,
  parte_novedad TEXT,
  fecha_hora TIMESTAMP DEFAULT NOW(),
  imei TEXT,
  grupo TEXT
);
```

### Tabla: inconsistencias

```sql
CREATE TABLE inconsistencias (
  id TEXT PRIMARY KEY,
  id_oficial_ref TEXT REFERENCES oficiales_maestro(id_oficial),
  nombre_oficial TEXT,
  tipo_alerta TEXT NOT NULL,
  detalle TEXT,
  resuelta BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  resuelta_por TEXT,
  fecha_resolucion TIMESTAMP
);
```

### Tabla: partes_sorpresa

```sql
CREATE TABLE partes_sorpresa (
  id_parte TEXT PRIMARY KEY,
  id_oficial_ref TEXT REFERENCES oficiales_maestro(id_oficial),
  nombre_oficial TEXT,
  texto_origen TEXT,
  texto_generado TEXT,
  audio_url TEXT,
  audio_waveform TEXT,
  similitud DOUBLE PRECISION,
  validado BOOLEAN DEFAULT false,
  validado_por TEXT,
  fecha_hora TIMESTAMP DEFAULT NOW(),
  fecha_validacion TIMESTAMP
);
```

### Tabla: allowed_admins

```sql
CREATE TABLE allowed_admins (
  id_admin TEXT PRIMARY KEY,
  nombre_admin TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  perfil TEXT DEFAULT 'SUPERVISOR',
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## 🔒 POLÍTICAS DE SEGURIDAD (RLS)

Habilita Row Level Security en todas las tablas:

```sql
ALTER TABLE oficiales_maestro ENABLE ROW LEVEL SECURITY;
ALTER TABLE monitoreoreportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE inconsistencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE partes_sorpresa ENABLE ROW LEVEL SECURITY;
ALTER TABLE allowed_admins ENABLE ROW LEVEL SECURITY;

-- Ejemplo de política de lectura (ajusta según tus necesidades)
CREATE POLICY "Enable read for authenticated users" 
ON oficiales_maestro FOR SELECT 
TO authenticated 
USING (true);
```

## 🎨 PERSONALIZACIÓN

### Cambiar Colores Neón

Edita `lib/core/constants/app_constants.dart`:

```dart
static const Color neonCyan = Color(0xFF00FFD1);  // Color principal
static const Color neonPink = Color(0xFFFF006B);  // Grupo Bravo
```

### Cambiar Posición Inicial del Mapa

Edita `lib/core/constants/app_constants.dart`:

```dart
static const double defaultLatitude = -16.5000;  // Tu latitud
static const double defaultLongitude = -68.1500; // Tu longitud
static const double defaultZoom = 12.0;          // Zoom inicial
```

## 🐛 SOLUCIÓN DE PROBLEMAS

### Error: "Failed to load network image"

El mapa requiere conexión a internet. Verifica tu conexión.

### Error: "Supabase exception"

1. Verifica que las credenciales de Supabase sean correctas
2. Asegúrate de que las tablas existan
3. Verifica que RLS esté configurado correctamente

### Error: "Font asset not found"

Ejecuta `flutter pub get` para asegurar que los assets se copien correctamente.

### Rendimiento lento

1. Usa modo release: `flutter run --release -d chrome`
2. Reduce el intervalo de refresco en `app_constants.dart`

## 📞 SOPORTE

Para reportar problemas o sugerencias, contacta con el equipo de desarrollo.

## ✅ CHECKLIST DE DESPLIEGUE

- [ ] Configurar credenciales de Supabase
- [ ] Crear todas las tablas en la base de datos
- [ ] Configurar políticas RLS
- [ ] Insertar datos de prueba
- [ ] Probar login
- [ ] Verificar que el mapa carga correctamente
- [ ] Confirmar que los marcadores aparecen
- [ ] Probar alertas y notificaciones
- [ ] Compilar en modo release
- [ ] Desplegar en servidor web (opcional)

---

**Versión:** 2.0.0
**Última actualización:** Febrero 2026
