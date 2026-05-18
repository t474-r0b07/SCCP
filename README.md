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
> Module: DTEX — External Operations
> Status: [OPERATIONAL] ██████████ 100%
> Surfaces: WebApp · Android Custodio · Android Supervisor
> Latency: <1s · Real-time · Level: TACTICAL
```

---

## `> ./overview.sh`

**SCCP Command Center** — tactical real-time law enforcement monitoring platform.  
Built from the dev side. Designed thinking about the other side.

Three surfaces. One operational truth:

```
SCCP ECOSYSTEM
├── SCCP COMMAND CENTER (DTEX)
│   ├── WebApp          → tactical HUD · dashboard · central command
│   ├── DTEX Custodio   → Android · field · GPS · reports · radio
│   └── DTEX Supervisor → Android · mobile command · coordination · alerts
│
└── SCCP MOBILE (specialized armor)
    └── Home arrest monitoring
        → Voice · GPS spoofing · geofencing · telemetry detection
        → github.com/t474-r0b07/SCCP-Mobile
```

---

## `> cat demo.log`

| Video | Description |
|-------|-------------|
| [▶ DEMO — Command Center](https://youtu.be/rMHYnaqIVr0?si=-GGM5YVxFRnkV53z) | Tactical HUD overview |
| [▶ DEMO — Modules & Flow](https://youtu.be/EmtY-lQay2o?si=sdV2ma88XMLw34dN) | Inconsistencies · Reports · Officers |

---

## `> ls -la modules/`

```
MODULE                   SURFACE       STATUS     DESCRIPTION
──────────────────────   ──────────    ────────   ──────────────────────────────────
dashboard/               WebApp        ✅ LIVE    4 metrics · alerts · navigation
inconsistencias/         WebApp        ✅ LIVE    Filters · PIN resolution · audit
partes_sorpresa/         WebApp        ✅ LIVE    States · expiration · responses
oficiales/               WebApp        ✅ LIVE    ALFA/BRAVO grid · telemetry · glow
auth/                    WebApp        ✅ LIVE    Shuffled PinPad · login logs · roles
realtime/                WebApp        ✅ LIVE    Supabase subscriptions · <1s latency
dtex_custodio/           Android       ✅ LIVE    GPS · reports · radio · offline mode
dtex_supervisor/         Android       ✅ LIVE    Mobile command · alerts · live map
```

---

## `> cat stack.txt`

```
FRONTEND
  Flutter Web (Dart)     → WebApp Command Center
  Flutter Android (Dart) → DTEX Custodio + Supervisor
  GetX                   → reactive state management
  flutter_animate        → fluid animations
  flutter_map            → CartoDB Dark Matter tiles

BACKEND
  Supabase — PostgreSQL + Realtime
  Custom auth · allowed_admins table
  RLS policies · audit logs
  Supabase Storage       → photos · reports

ARCHITECTURE
  Clean Architecture
  ├─ Presentation  →  Views + GetX Controllers
  ├─ Domain        →  Entities + Use Cases
  └─ Data          →  Models + Supabase Repository

UI / UX
  Glassmorphism · BackdropFilter sigma: 15
  Orbitron (headings) · Rajdhani (data)
  Palette: #00FFD1 cyan · #FF006E pink · #0A0E27 base
  Effects: pulse · hover glow · scanner overlay
```

---

## `> cat threat_model.txt`

```
ATTACK VECTOR      MITIGATION
──────────────     ───────────────────────────────────────
GPS Spoofing    →  Inconsistent coordinate detection
Shoulder Surf   →  Random shuffle PinPad on every use
Unauth access   →  Dual factor: Email + PIN · allowed_admins
Escalation      →  Strict SUPERVISOR / DIRECTOR roles
VPN / Proxy     →  Network interface fingerprinting
Traceability    →  Full audit trail with timestamps
```

> *Built with offensive thinking. Every feature is a countermeasure.*

---

## `> cat metrics.txt`

```
Lines of code:          ~2,500
Main views:             5
Reusable widgets:       15+
Real-time update:       <1 second
Concurrent users:       100+
Monitored officers:     500+
Independent APKs:       2 (Custodio · Supervisor)
```

---

## `> ls -la documentation/`

- [`PROJECT_MEMORY.md`](./PROJECT_MEMORY.md) — From monolith to Android fork. 13 weeks.
- [`DEVLOG.md`](./DEVLOG.md) — Technical debt, field lessons, real decisions.
- [`CHANGELOG_PUBLIC.md`](./CHANGELOG_PUBLIC.md) — Version history and operational deployment.

---

## `> ./run.sh`

```bash
git clone https://github.com/t474-r0b07/SCCP-DTEX.git
cd SCCP-DTEX
flutter pub get

# Set credentials → lib/core/constants/app_constants.dart

# WebApp
flutter run -d chrome

# Android Custodio
flutter run --flavor dtex_custodio --target lib/main_custodio.dart

# Android Supervisor
flutter run --flavor dtex_supervisor --target lib/main_dtex_supervisor.dart

# Production build
flutter build web --release
flutter build apk --flavor dtex_custodio --target lib/main_custodio.dart
flutter build apk --flavor dtex_supervisor --target lib/main_dtex_supervisor.dart
```

---

## `> cat roadmap.txt`

```
[ PHASE 2 ]  Inmates module · Mapbox · PDF export
[ PHASE 3 ]  KPI dashboard · Supervisor chat · Multi-tenant
[ PHASE 4 ]  ML analytics · Public API · iOS support
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
