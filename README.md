```
███████╗ ██████╗ ██████╗██████╗ 
██╔════╝██╔════╝██╔════╝██╔══██╗
███████╗██║     ██║       ██████╔╝
╚════██║██║     ██║       ██╔═══╝ 
███████║╚██████╗╚██████╗██║     
╚══════╝ ╚═════╝ ╚═════╝╚═╝     
```

```bash
$ cat /etc/mission
> Sistema de Control y Custodia Policial
> Estado: [OPERACIONAL] ██████████ 100%
> Latencia: <1s · Tiempo real · Nivel: TÁCTICO
```

---

## `> ./overview.sh`

**SCCP Command Center** es una plataforma táctica de monitoreo policial en tiempo real.  
Construida por alguien que viene del lado del desarrollo — pensando siempre en el otro lado.

> No es solo una app. Es un sistema diseñado desde adentro para resistir desde afuera.

**WebApp** · Flutter + Supabase · Clean Architecture · Realtime < 1s

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
Trazabilidad    →  Audit trail completo con timestamps
```

> *Built with offensive thinking. Every feature is a countermeasure.*

---

## `> ls -la modules/`

```
MÓDULO                STATUS     DESCRIPCIÓN
────────────────      ────────   ────────────────────────────────────
dashboard/         ✅ LIVE      4 métricas · alertas · navegación
inconsistencias/   ✅ LIVE      Filtros · resolución con PIN · audit
partes_sorpresa/   ✅ LIVE      Estados · vencimiento · respuestas
oficiales/         ✅ LIVE      Grid ALFA/BRAVO · telemetría · glow
auth/              ✅ LIVE      PinPad shuffled · login logs · roles
realtime/          ✅ LIVE      Supabase subscriptions · <1s latency
```

---

## `> cat stack.txt`

```
FRONTEND
  Flutter Web (Dart)
  GetX — reactive state management
  flutter_animate — animaciones fluidas
  flutter_map — CartoDB Dark Matter tiles

BACKEND  
  Supabase — PostgreSQL + Realtime
  Custom auth con tabla allowed_admins
  RLS policies · audit logs

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
Líneas de código:       ~2,500
Modelos con getters:    5
Vistas principales:     5
Widgets reutilizables:  15+
Actualización RT:       <1 segundo
Usuarios concurrentes:  100+
Oficiales monitoreados: 500+
```

---

## `> ./run.sh`

```bash
# Clonar
git clone https://github.com/t474-r0b07/sccp.git
cd sccp

# Instalar dependencias
flutter pub get

# Configurar credenciales
# lib/core/constants/app_constants.dart
#   supabaseUrl = 'YOUR_URL'
#   supabaseAnonKey = 'YOUR_KEY'

# Ejecutar
flutter run -d chrome

# Build producción
flutter build web --release
```

---

## `> cat roadmap.txt`

```
[ FASE 2 ]  Módulo de reos · Mapas Mapbox · Exportación PDF
[ FASE 3 ]  Dashboard KPIs · App móvil nativa · Chat supervisores
[ FASE 4 ]  Analytics ML · Multi-tenant · API pública
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

<details>
<summary><code>// signal detected — decode if you can</code></summary>

```
                                  @@@@@@@@@@@@@@@@@@@@@@@@@@*@@@@@@@@@@@@@@@@@@@@@@ +@@@@@@@@@.@@@*@@@@@@@@@@%@@@@@@
                                 @@                                                                               @@
                                 @@                                                                               @@
                                 @@                        +@@@@@                     @@@@@                       @@
                                 @@                       @..@@ @@                  @ @@@ @@                      @@
                                 @@                      *@ @  @ @                 @@ @  @*@                      @@
                                 @@         ..            @@@  @@@                  @@   @@=                      @@
                                 @@      @@@  @@@            @@@@@                  @ #@@            @@@ @@@      @@
                                 @@      @ @  @ @            @@@ @                 @  @@@           @@ @ # @@     @@
                                 @@      @:#@@@*@             @@  @                @ -@@            @@ @ @ @@     @@
                                 @@       @@@@@@@@            @@@ @               @  @@@            :@@@@@@@      @@
                                 @@          @@@  @           %@@  @              @ -@@               @@@         @@
                                 @@           @@@              @@ @@             @@  @@          @   @@           @@
                                 @@            :@@   @           @@@@+.        @@@@@@@          @   @@            @@
                                 @@              @@@  @        :@@  @::       @@ @ @ @@        @   @@             @@
                                 @@               @@@@@@@      @@ @@@@@       @@ @.@ @@     +@@@+@@@              @@
                                 @@                @@@@  @      @@@@@@@        @@@@@@@    @@@  @@@@               @@
                                 @@     @          @@ @  @@@     +@@@@@          @@@      @ @  @:@           *    @@
                                 @@    @:.          @+%@@ @@      @@@@@@      @  @@@      @@ @@ @@          @@    @@
                                 @@    @  @          @@@@@@+@     @@@@@@     @ @@@@       @@@@@@@          @  @   @@
                                 @@   @ @  @            @@@@@@  @ @@@@=   @@-   @@@@ @ @@@@@@@           @  @ @   @@
                                 @@   @ @@@    #@@@      @                                 @@      @@*:   @@@ @   @@
                                 @@   @ @@ @@@@@@   @ @@@@:                                @@@@@ @  .@@@@@@@@ @   @@
                                 @@   @ *@   @@@@@@  @@                                        @@  @@@@@@  @@ @   @@
                                 @@    * @@    .@@@@                      @@                      @@@@     @@ @   @@
                                 @@    @ @@       @@     @      @@@@@@@* @ @   -@@@@@@     @     @@@      @@ @    @@
                                 @@     @ @@     %@@@     @@@@@   #@@    @ @@   %@@   @@@@@@ @  @@@@     @@ @@    @@
                                 @@      @ @@    @:    @@@@@@@@@@@ @@@@@@  =@@@@@  @@@@@@@@@@@@    @.:  @@ @@     @@
                                 @@       @ @@@@@@@  @@@         @@@ @@@@   @@@@  @@*        @@#@  @@@@@@ @@      @@
                                 @@         @@:@@@@  @@ @@@@@@@@@  @@ @@@   @@  @@@ @@@@@@@@@=@@@ @@@@@@@@        @@
                                 @@            @@     @@  @@@@ @ @@  @@@@   @@@@@ @@ +@@@@@@ @@:@   @@:           @@
                                 @@            @     @@ @@     @  . @@ @     @@-@@ @ @@     @@ @     @            @@
                                 @@             @@@  @ @@ @=@   @  @ @@@  @  @@@@:   @  @=@  @ @  @@@@            @@
                                 @@             @@   @ @@  @@- @@ @@@ @@  @  %@  @   @  @@@  @ @@  @@#            @@
                                 @@            @@    @@.@@+   @@@@  @@@   @   @@@@ @  @@   @@*@@@    @.           :@
                                 @@             @@.  @@@@#@     @@@@@@    @    @@@@@@       @@@@@  @@             @@
                                 @@              @   @-@@@@@@@@@@@@@@     @     @@@@@@@@@@@@@@ @@  %              @@
                                 @@              @@@ @@ @@    @@@@*       @    +  @@@@@     @  @@@-@              @@
                                 @@                 @@@:  @   @@ .@@@:    @@@@@@@@@@  @@@  @ @@@@                 @@
                                .@@                  *@   @@@       @:    @@@@@@@@   @    @@ @@@                  @@
                                .@@                   @@@ @@@@       @@@  @@@@@@  @    @@@@ @@@                   @@
                                 @@                    @@@ @@@@@@@      :@@@@ @   @ @@@@@@ -@ @                   @@
                                 @@                     -:@  @@@@@@@@@@@@%@=*@@@@@@@@@@@@ @@ @                    @@
                                =@@                      @ @@  @@@@@@@@@@@@@@@@@@@@@@@@  @+ @                     @@
                                 @@                       @  @@  @@@@@@@@@@@@@@@@@@@   @@ @                       @@
                                :@@                        @   @@@    @@@@@@@@@@    @@@  @                        @@
                                %@@                          @    @@@@@        @@@@@   @@                         @@
                                .@@                           +@      @-     @@@     @@                           @@
                                -@@                             @*        @        @@                             @@
                                 -@                               @@      @      @@                               @@
                                 @@                                 *     @     @@                                @@
                                -@@                                 @     @     @@                                @@
                                +@@                                 @@    @   @@@                                 @@
                                +%@                             @  #@@.@@@@@:+@*@@  @                             @@
                                *@@                                @@          #@@@ @@                            @@
                                =@@                             @+    @:     @@    @@                             @@
                                @@@                                    @@   @@   .                                @@
                                +@@                                      @@@.                                     @@
                                :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

                                  @@        @@@@  @@@@@@@    :@@@                    @@@@@  @@@       @@@@@  @@@@@@@
                                 @@@@@@   @@@@@@      @@=  @@@@@@           @@ @@@  @@   @@ @@@@@@   @@   @@     @@.
                                  @@     @@  @@@     :@   @@. :@@           @@@ @@@ @@ @@@@ @@@  @@  @@ @@@@    -@
                                  @@     @@@@@@@@   =@@   @@@@@@@@          @@      @@@  @@ %@@  @@  @@@  @@    @@
                                   @@@@      @@@   @@@        :@@           @=       @@@@@  @@@@@@    @@@@@   +@@
```

</details>

```
█████████████████████████████████████████████████
█                                                       █
█    S C C P  ·  C O M M A N D  C E N T E R             █
█         C O N T R O L .  C U S T O D Y .              █
█                   C O D E .                           █
█                                                       █
█████████████████████████████████████████████████
```

---

<!-- 
  Built by t474-r0b07
  "The best security is the one the attacker doesn't expect."
-->
