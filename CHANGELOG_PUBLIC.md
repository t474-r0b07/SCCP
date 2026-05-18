# SCCP Command Center - Changelog Público

**Versión:** 2.0.0+1  
**Estado:** Producción  
**Última actualización:** 2026-05-15

---

## 📋 Estructura de Versiones

El proyecto adopta versionamiento semántico (MAJOR.MINOR.PATCH+BUILD).

- **2.x.x** - Arquitectura DTEX bifurcada (Custodio + Supervisor)
- **1.x.x** - Monolito Web (SCCP Command Center Dashboard)

---

## 🆕 Added

### v2.0.0 (2026-05-15) - DTEX Mobile Framework
- ✅ Aplicaciones Android nativas independientes:
  - **DTEX Custodio**: Interface optimizada para operarios en campo
  - **DTEX Supervisor**: Panel de comando para coordinadores
- ✅ Sistema de misiones con ciclo de vida completo
- ✅ Geolocalización en tiempo real con seguimiento periódico
- ✅ Radio operativa bidireccional con chat en vivo
- ✅ Alarmas inteligentes de iniciación de diligencias
- ✅ Captura de partes de novedad con foto integrada
- ✅ Validación de custodios con fuzzy matching (±2 tokens)
- ✅ Sistema de emergencia con alertas inmediatas
- ✅ Storage distribuido para reportes y fotos (Supabase)
- ✅ Notificaciones locales multisistema

### v1.5.0 (2026-02-26) - Refinamientos Operativos Web
- ✅ Responsive adaptativo para dispositivos móviles
- ✅ Notificaciones grandes de radio in-app
- ✅ Cierre de sesión mejorado
- ✅ Estados de partes con explicación operativa
- ✅ Sincronización UTC ↔ hora local automática
- ✅ Actions compactas por icono en header

### v1.0.0 (2024) - SCCP Command Center MVP
- ✅ Dashboard táctico con interfaz HUD militar
- ✅ Autenticación dual (Email + PIN aleatorio)
- ✅ Módulo de inconsistencias en tiempo real
- ✅ Módulo de partes sorpresa
- ✅ Gestión de oficiales por grupo
- ✅ Glassmorphism con paleta neón (Cyan + Rosa)
- ✅ Clean Architecture (Data, Domain, Presentation)
- ✅ Integración Supabase completa

---

## 🔄 Changed

### Arquitectura (v2.0.0)
- Migración de monolito web a arquitectura bifurcada móvil/web
- Separación de entrypoints: `main.dart` (web), `main_custodio.dart` (Android), `main_dtex_supervisor.dart` (Android)
- Gestión de estado: GetX centralizado con controladores especializados
- Modelos de datos refactorizados para DTEX workflows

### Servicios de Geolocalización (v2.0.0)
- Implementación de `dtex_android_tracking_service.dart` para polling GPS
- Sincronización web/Android en `dtex_geo_location_web.dart`
- Optimización de batería y manejo de estado de red

### Autenticación
- **v1.x**: PIN de 4 dígitos solo para web
- **v2.0**: OTP bifurcado (PIN web + OTP SMS para Android)
- Validación por nombre parcial en custodios (tolerancia 2 tokens)

### UI/UX
- Tablas responsivas → Cards apilables en móvil
- Mapa fullscreen bloqueado de rotación en móvil
- Header compacto con acciones por icono
- Dialogs contextuales para estados complejos

### Base de Datos
- Migración de `oficiales` → `custodios` (DTEX)
- Nuevas tablas: `misiones`, `radio_mensajes`, `alertas_custodio`
- RPCs públicas para validación de acceso por roles
- Políticas RLS (Row Level Security) por usuario y grupo

---

## 🐛 Fixed

### v2.0.0 - Critical Patches
- ✅ Login de custodio rechazando nombres válidos (fuzzy matching implementado)
- ✅ OTP no recibido en algunos carriers (fallback a validación local)
- ✅ Mapa oscilante en DTEX Supervisor (centro fijo en Tarija)
- ✅ Radio operativa sin sincronización entre supervisor/custodio (canal por `custodioCodigo`)
- ✅ Fotos no subiendo en mala red (parte se envía igual con observación)
- ✅ Alarmas repetitivas de inicio de misión (cooldown implementado)
- ✅ Permiso de cámara no solicitado antes de captura

### v1.5.0 - Web Refinements
- ✅ Horas del "futuro" en reportes (conversión UTC → local)
- ✅ Alertas de radio sin notificación visual en web
- ✅ Estado de partes ambiguo (explicación operativa añadida)

### v1.0.0 - Initial QA
- ✅ Arquitectura limpia sin dependencies cruzadas
- ✅ Autenticación con seguridad PinPad
- ✅ Realtime Supabase sin lag notable

---

## 🔐 Security

### v2.0.0 Hardening
- ✅ RLS (Row Level Security) en `misiones`, `custodios`, `radio_mensajes`
- ✅ OTP con TTL (Time To Live) de 10 minutos
- ✅ Validación de `custodioCodigo` en cada operación
- ✅ Bloqueo de acceso para roles no autorizados
- ✅ Audit trail en `login_logs` y `alertas_custodio`
- ✅ Encriptación de fotos en Storage (Supabase TLS)

### v1.x Authentication
- ✅ PIN con shuffle aleatorio por sesión
- ✅ Logs de login con timestamp y IP
- ✅ Cierre de sesión al cerrar navegador
- ✅ JWT token expiration

---

## ⚡ Performance

### v2.0.0 Optimizations
- ✅ Polling GPS con intervalo inteligente (30s conectado, 60s degradado)
- ✅ Caché local de misiones (sync on demand)
- ✅ Compresión de fotos antes de upload (80% reducción)
- ✅ Paginación de radio mensajes (últimos 100)
- ✅ Índices en `misiones(custodioCodigo)`, `radio_mensajes(created_at)`

### v1.x Optimizations
- ✅ Realtime Supabase con throttling en actualizaciones
- ✅ Lazy loading de widgets con Shimmer
- ✅ Imágenes optimizadas en assets (WebP)
- ✅ Build web con tree-shaking y minificación

---

## 🗺️ Roadmap

### Próximos Hitos
- [ ] Sincronización P2P de misiones (sin conexión)
- [ ] Análisis de rutas con algoritmo A*
- [ ] Predicción de anomalías con ML
- [ ] Dashboard en tiempo real en web desde Android
- [ ] Soporte para iOS (framework listo, solo ajustes nativos)

---

## 📞 Soporte

**Para reportar bugs:** Contactar equipo técnico  
**Para solicitar features:** Crear issue en backlog  
**Para configuración:** Ver [MANUAL_USUARIO.md](MANUAL_USUARIO.md)

---

## 📄 Notas de Compatibilidad

| Plataforma | Versión | Estado |
|-----------|---------|--------|
| Web | v1.5.0+ | ✅ Producción |
| Android (Custodio) | v2.0.0 | ✅ Testing |
| Android (Supervisor) | v2.0.0 | ✅ Testing |
| iOS | TBD | ⏳ Roadmap |

**Requisitos mínimos:**
- Android 8.0+ (API 26)
- Chrome 90+ (web)
- Flutter 3.0.0+
- Dart 3.0.0+
