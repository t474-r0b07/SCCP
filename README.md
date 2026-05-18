```
          · · · · · · · · · · ·
       ·    ╔═══════════════╗    ·
     ·   ╔══╬───────────────╬══╗   ·
    ·  ╔═╬──╬───────────────╬──╬═╗  ·
    · ─╬─╬──╬──── ✛ ────────╬──╬─╬─ ·
    ·  ╚═╬──╬───────────────╬──╬═╝  ·
     ·   ╚══╬───────────────╬══╝   ·
       ·    ╚═══════════════╝    ·
          · · · · · · · · · · ·

  SIGNAL ORIGIN: [REDACTED]
  LAST FIX:      44.9717° N, 37.7492° E
  STATUS:        ⚠ SPOOFED
```

---

```bash
$ cat /etc/mission
> Sistema de Control y Custodia Policial
> Módulo: DTEX — Diligencias Externas
> Estado: [OPERACIONAL] ██████████ 100%
> Superficies: WebApp · Android Custodio · Android Supervisor
> Latencia: <1s · Tiempo real · Nivel: TÁCTICO
```

---

## `> ./overview.sh`

**SCCP Command Center** es una plataforma táctica de monitoreo policial en tiempo real.  
Construida por alguien que viene del lado del desarrollo — pensando siempre en el otro lado.

> No es solo una app. Es un sistema diseñado desde adentro para resistir desde afuera.

**DTEX** es el módulo de diligencias externas — tres superficies, una sola verdad operativa:

```
SCCP ECOSYSTEM
├── SCCP COMMAND CENTER (DTEX)
│   ├── WebApp          → HUD táctico · dashboard · supervisión central
│   ├── DTEX Custodio   → Android · campo · GPS · partes · radio [diligencias temporales]
│   └── DTEX Supervisor → Android · comando móvil · coordinación · alertas
│
└── SCCP MOBILE (specialized armor)
    └── Custodia domiciliaria
        → Detección avanzada: voz · GPS spoofing · geocercas · telemetría
        → [Ver: github.com/t474-r0b07/SCCP-Mobile]
```

---

## `> quick_brief.txt`

- Proyecto completo: Web + Android Custodio + Android Supervisor + backend realtime.
- Demo reel técnico y tutorial operativo incluidos, listos para validar funcionalidad y alcance.
- Seguridad operativa: auth con PIN, RLS, audit trail, spoofing detection, network fingerprinting.
- Arquitectura basada en Clean Architecture + Flutter + Supabase + GetX.
- Desarrollo y ejecución propios, con foco en supervisión táctica y movilidad de campo.

> Esta página está pensada para que un reclutador vea el valor y luego siga con los videos.

---

## `> ls -la documentation/`

* 📂 [`PROJECT_MEMORY.md`](./PROJECT_MEMORY.md)  — La evolución del monolito a la bifurcación Android (13 semanas).
* 📝 [`DEVLOG.md`](./DEVLOG.md)          — Registro de neurosis técnica, deuda acumulada y lecciones de campo.
* 📋 [`CHANGELOG_PUBLIC.md`](./CHANGELOG_PUBLIC.md) — Historial de versiones y despliegue operativo.

> *Documentación pensada desde adentro: decisiones arquitectónicas, problemas reales, soluciones emergentes.*

---

## `> cat demo.log`

### 🎥 En acción

| Video | Descripción |
|-------|-------------|
| [▶ DEMO — Command Center](https://youtu.be/rMHYnaqIVr0?si=-GGM5YVxFRnkV53z) | Vista general del HUD táctico |
| [▶ DEMO — Módulos & Flujo](https://youtu.be/EmtY-lQay2o?si=sdV2ma88XMLw34dN) | Inconsistencias · Partes Sorpresa · Oficiales |

---

## `> cat threat_model.txt`

```
VECTOR             MITIGACIÓN IMPLEMENTADA
──────────────     ──────────────────────────────────────
GPS Spoofing    →  Detección de coordenadas inconsistentes
Shoulder Surf   →  PinPad con shuffle aleatorio en cada uso
Acceso no auth  →  Dual factor: Email + PIN · Tabla allowed_admins
Escalación      →  Niveles SUPERVISOR / DIRECTOR estrictos
VPN / Proxy     →  Network interface fingerprinting
Trazabilidad    →  Audit trail completo con timestamps
```

> *Built with offensive thinking. Every feature is a countermeasure.*

---

## `> cat universe_map.txt`

```
SCCP = Control operacional policial integral

┌─ DTEX (Este repo) ──────────────────────────────────────┐
│ PROPÓSITO:  Monitoreo general · diligencias externas   │
│ ALCANCE:    Misiones temporales (hospital, juzgado)    │
│ VIGILANCIA: Oficial (¿dónde está? ¿qué hace?)         │
│ ALERTAS:    Paradas anormales · desvíos · apagón GPS   │
│ VIDAS:      Multiple officers · rotating tasks         │
└─────────────────────────────────────────────────────────┘

┌─ SCCP-MOBILE (Repo especializado) ──────────────────────┐
│ PROPÓSITO:  Custodia domiciliaria · Evasion detection  │
│ ALCANCE:    Monitoreo permanente 24/7                  │
│ VIGILANCIA: Reo bajo custodia (armado cognitivo)       │
│ DETECCIÓN:  Voz · GPS spoofing · geocercas · telemetría│
│ ALERTAS:    Cualquier anomalía = CRÍTICA               │
│ VIDAS:      One subject · permanent watch              │
└─────────────────────────────────────────────────────────┘

ARQUITECTURA RELACIONAL
  [DTEX Custodio]    ← app liviana, temporal, alertas operacionales
       ↓ (mismo backend)
  [Supabase]         ← source of truth
       ↑ (mismo backend)
  [SCCP-Mobile]      ← app pesada, permanente, alertas críticas
  
Mismo backend. Mismo universo. Diferentes misiones.
```

---

## `> ls -la modules/`

```
MÓDULO                   SUPERFICIE    STATUS     DESCRIPCIÓN
──────────────────────   ──────────    ────────   ────────────────────────────────────
dashboard/               WebApp        ✅ LIVE    4 métricas · alertas · navegación
inconsistencias/         WebApp        ✅ LIVE    Filtros · resolución con PIN · audit
partes_sorpresa/         WebApp        ✅ LIVE    Estados · vencimiento · respuestas
oficiales/               WebApp        ✅ LIVE    Grid ALFA/BRAVO · telemetría · glow
auth/                    WebApp        ✅ LIVE    PinPad shuffled · login logs · roles
realtime/                WebApp        ✅ LIVE    Supabase subscriptions · <1s latency
dtex_custodio/           Android       ✅ LIVE    GPS · partes · radio · offline mode
dtex_supervisor/         Android       ✅ LIVE    Comando móvil · alertas · mapa RT
```

---

## `> cat stack.txt`

```
FRONTEND
  Flutter Web (Dart)          → WebApp Command Center
  Flutter Android (Dart)      → DTEX Custodio + Supervisor
  GetX                        → reactive state management
  flutter_animate             → animaciones fluidas
  flutter_map                 → CartoDB Dark Matter tiles

BACKEND
  Supabase — PostgreSQL + Realtime
  Custom auth con tabla allowed_admins
  RLS policies · audit logs
  Supabase Storage            → fotos · reportes

ARQUITECTURA
  Clean Architecture
  ├─ Presentation  →  Views + GetX Controllers
  ├─ Domain        →  Entities + Use Cases
  └─ Data          →  Models + Supabase Repository

UI / UX
  Glassmorphism · BackdropFilter sigma: 15
  Orbitron (títulos) · Rajdhani (datos)
  Palette: #00FFD1 cyan · #FF006E rosa · #0A0E27 base
  Efectos: pulse · hover glow · scanner overlay
```

---

## `> cat metrics.txt`

```
Líneas de código:          ~2,500
Modelos con getters:       5
Vistas principales:        5
Widgets reutilizables:     15+
Actualización RT:          <1 segundo
Usuarios concurrentes:     100+
Custodios monitoreados:    500+
APKs independientes:       2 (Custodio · Supervisor)
```

---

## `> ./run.sh`

```bash
# Clonar
git clone https://github.com/t474-r0b07/SCCP-DTEX.git
cd SCCP-DTEX

# Instalar dependencias
flutter pub get

# Configurar credenciales
# lib/core/constants/app_constants.dart
#   supabaseUrl = 'YOUR_URL'
#   supabaseAnonKey = 'YOUR_KEY'

# WebApp
flutter run -d chrome

# Android Custodio
flutter run --flavor dtex_custodio --target lib/main_custodio.dart

# Android Supervisor
flutter run --flavor dtex_supervisor --target lib/main_dtex_supervisor.dart

# Build producción
flutter build web --release
flutter build apk --flavor dtex_custodio --target lib/main_custodio.dart
flutter build apk --flavor dtex_supervisor --target lib/main_dtex_supervisor.dart
```

---

## `> cat roadmap.txt`

```
[ FASE 2 ]  Módulo de reos · Mapas Mapbox · Exportación PDF
[ FASE 3 ]  Dashboard KPIs · Chat supervisores · Multi-tenant
[ FASE 4 ]  Analytics ML · API pública · iOS support
```

---

## `> tail -n 1 /var/log/build.log`

```
[⚑] 54 68 65 20 73 79 73 74 65 6d 20 77 6f 72 6b 73 2e
    20 54 68 65 20 71 75 65 73 74 69 6f 6e 20 69 73 3a
    20 77 68 6f 20 63 6f 6e 74 72 6f 6c 73 20 74 68 65
    20 73 79 73 74 65 6d 2e
```

---

> `[!]` · [`anomaly in position data`](./CHALLENGE.md) · coordinates unverified

---

```
█████████████████████████████████████████████████████
█                                                   █
█    S C C P  ·  C O M M A N D  C E N T E R        █
█         C O N T R O L .  C U S T O D Y .         █
█                   C O D E .                       █
█                                                   █
█████████████████████████████████████████████████████
```

---

## `> cat /etc/license`

```
© t474-r0b07 · All Rights Reserved
This code is not open source.
Viewing ≠ permission to use, copy, or distribute.
```

---

<!--
  2017. Black Sea. 20+ vessels report impossible position.
  AIS systems place them inland — at an airport.
  No malfunction detected. Hardware nominal.
  The data was lying.

  The first documented large-scale GPS spoofing attack on civilian infrastructure.
  The system trusted the signal. The signal was wrong.

  This is why SCCP detects before it trusts.

  >> https://www.maritime.dot.gov/msci/2017-005-black-sea-anomalous-gps-signals

  Something in this README is also lying about its position.
  Find it.
-->
