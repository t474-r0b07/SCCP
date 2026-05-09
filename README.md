# SCCP COMMAND CENTER - TACTICAL HUD

## 🎯 CARACTERÍSTICAS TÁCTICAS IMPLEMENTADAS

### MAPA FULLSCREEN
- ✅ Mapa de pantalla completa usando `flutter_map`
- ✅ Tiles de CartoDB Dark Matter para estética oscura
- ✅ Sin AppBar ni Drawer - visión total del campo de batalla

### MARCADORES RADAR PULSANTES
- ✅ CustomPainter con ondas concéntricas animadas
- ✅ 3 ondas que se expanden y desvanecen
- ✅ Colores diferenciados por grupo (Cian para ALFA, Rosa para BRAVO)
- ✅ Núcleo del marcador con símbolo de grupo (⍺/β)

### GLASSMORPHISM (CRISTAL ESMERILADO)
- ✅ BackdropFilter con sigma: 15.0
- ✅ Bordes con glow neón en color cian
- ✅ Transparencias graduales
- ✅ Sombras neón personalizadas

### TIPOGRAFÍAS
- ✅ Orbitron para títulos (espaciado amplio)
- ✅ Rajdhani para datos numéricos
- ✅ Fuentes configuradas en pubspec.yaml

### COMPONENTES HUD
- ✅ Esquina Superior Izquierda: Estadísticas de fuerza
- ✅ Esquina Superior Derecha: Indicador de sistema (pulso cian)
- ✅ Panel Lateral Derecho: Stack de alertas con shimmer
- ✅ Dock Inferior: Barra flotante con 3 iconos
- ✅ Panel Detalle Oficial: Lateral izquierdo con telemetría

### EFECTOS VISUALES
- ✅ Scanner Effect: Línea horizontal que recorre la pantalla
- ✅ Alertas con borde rojo parpadeante
- ✅ Hover effects con escala y glow
- ✅ Animaciones con flutter_animate

### SEGURIDAD
- ✅ Autenticación con Supabase
- ✅ Repositorio centralizado
- ✅ Control de acceso por perfil
- ✅ Gestión de estado con GetX

## 📦 INSTALACIÓN

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en web
flutter run -d chrome

# Compilar para producción
flutter build web --release
```

## ⚙️ CONFIGURACIÓN

Editar `lib/core/constants/app_constants.dart`:

```dart
static const String supabaseUrl = 'TU_URL_SUPABASE';
static const String supabaseAnonKey = 'TU_ANON_KEY';
```

## 🎨 PALETA DE COLORES NEÓN

- Cian: #00FFD1 (Grupo Alfa, Glow principal)
- Rosa: #FF006B (Grupo Bravo)
- Verde: #00FF88 (Estado normal)
- Rojo: #FF0055 (Alertas críticas)
- Naranja: #FF6B00 (Advertencias)

## 🗺️ ESTRUCTURA

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   └── theme/
│       └── app_theme.dart
├── data/
│   ├── models/
│   │   ├── oficial_model.dart
│   │   ├── monitoreo_reporte_model.dart
│   │   ├── inconsistencia_model.dart
│   │   ├── parte_sorpresa_model.dart
│   │   └── allowed_admin_model.dart
│   └── repositories/
│       └── supabase_repository.dart
├── presentation/
│   ├── controllers/
│   │   └── dashboard_controller.dart
│   ├── views/
│   │   ├── login_view.dart
│   │   └── dashboard_view.dart
│   └── widgets/
│       ├── hud_card.dart
│       ├── tactical_marker.dart
│       ├── scanner_overlay.dart
│       ├── alert_stack.dart
│       ├── tactical_dock.dart
│       └── officer_detail_panel.dart
└── main.dart
```

## 🚀 CARACTERÍSTICAS DESTACADAS

1. **Mapa Táctico**: Visualización en tiempo real de posiciones de oficiales
2. **Radar Pulsante**: Animaciones Custom Paint de alta fidelidad
3. **HUD Flotante**: Interfaz no intrusiva tipo videojuego
4. **Glassmorphism**: Efectos de cristal esmerilado profesionales
5. **Alertas Inteligentes**: Stack de inconsistencias con temporizadores
6. **Panel de Detalle**: Información completa de telemetría por oficial
7. **Responsive**: Adaptable a diferentes tamaños de pantalla
8. **Performance**: Optimizado para web con 60 FPS constantes

## 📱 REQUISITOS

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Cuenta de Supabase configurada

## 🎯 PRÓXIMAS CARACTERÍSTICAS

- [ ] Drag & Drop para archivos
- [ ] Pin Pad aleatorio para acciones críticas
- [ ] Gráficos de histórico con fl_chart
- [ ] Mapa de calor de actividad
- [ ] Exportación de reportes PDF
- [ ] Notificaciones push en tiempo real

## 📄 LICENCIA

Propiedad de SCCP - Sistema de Control y Custodia Policial
