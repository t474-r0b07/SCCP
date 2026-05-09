# Deploy Express Webapp v1.1.3 (Prueba en móviles)

Objetivo: publicar hoy la webapp en internet para que supervisores prueben instalación en sus teléfonos.

## Paso 1 - Build limpio

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

Carpeta resultante: `build/web`

## Paso 2 - Publicar rápido (opción recomendada para hoy)

### Opción A: Netlify Drop (más rápida)

1. Entra a https://app.netlify.com/drop
2. Arrastra la carpeta `build/web`
3. Netlify te entrega URL HTTPS pública al instante.
4. Comparte esa URL a supervisores.

Nota: ya está agregado `web/_redirects` para rutas Flutter SPA.

### Opción B: Vercel

1. Crea proyecto en Vercel apuntando al repo.
2. Build command: `flutter build web --release`
3. Output directory: `build/web`
4. Deploy.

Nota: ya está agregado `vercel.json` con rewrite a `index.html`.

### Opción C: VPS + Nginx

Si prefieres control total, usa `docs/deploy_webapp_test_server_v1_1_3.md`.

## Paso 3 - Configurar Supabase Auth (obligatorio)

En Supabase:
- `Authentication > URL Configuration`

Configura:
- `Site URL`: `https://TU_URL_PUBLICA`
- `Redirect URLs`:
  - `https://TU_URL_PUBLICA/*`
  - (si usas dominio propio, también ese dominio)

## Paso 4 - Instalar en móviles (supervisores)

Android (Chrome):
1. Abrir URL
2. Menú `⋮`
3. `Agregar a pantalla de inicio` o `Instalar app`

iPhone (Safari):
1. Abrir URL
2. Botón compartir
3. `Agregar a pantalla de inicio`

## Paso 5 - Validación mínima de aceptación

1. Login supervisor/director.
2. Dashboard carga sin errores.
3. Diálogos on-click sin overflow.
4. Botón imprimir abre vista previa.
5. Informe individual incluye logos + QR.

## Advertencia práctica sobre Supabase Storage

Supabase Storage sirve para alojar archivos estáticos, pero no es la opción más estable para una SPA Flutter con rutas/fallback y pruebas operativas multiusuario.
Para mañana: Netlify/Vercel/Nginx.
