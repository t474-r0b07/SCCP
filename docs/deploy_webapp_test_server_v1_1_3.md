# Deploy Webapp Test Server (v1.1.3)

## 1) Build local limpio

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

Salida esperada: carpeta `build/web`.

## 2) Servidor de prueba (Ubuntu + Nginx)

```bash
sudo apt update
sudo apt install -y nginx
sudo mkdir -p /var/www/sccp_test
```

Sube contenido de `build/web/` a `/var/www/sccp_test/` (scp/sftp/rsync).

## 3) Config Nginx para Flutter Web (SPA)

Crear archivo `/etc/nginx/sites-available/sccp_test`:

```nginx
server {
  listen 80;
  server_name test.tudominio.com;

  root /var/www/sccp_test;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)$ {
    expires 7d;
    add_header Cache-Control "public";
  }
}
```

Activar sitio:

```bash
sudo ln -s /etc/nginx/sites-available/sccp_test /etc/nginx/sites-enabled/sccp_test
sudo nginx -t
sudo systemctl reload nginx
```

## 4) HTTPS (recomendado)

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d test.tudominio.com
```

## 5) Config obligatoria en Supabase Auth

En `Authentication > URL Configuration`:

- `Site URL`: `https://test.tudominio.com`
- `Redirect URLs`: `https://test.tudominio.com/*`

## 6) Smoke test post-deploy

1. Login supervisor/director.
2. Dashboard carga sin errores.
3. Boton imprimir abre vista previa.
4. PDF incluye logos y QR en informe individual.
5. Realtime recibe reportes y cambios de estado.

## 7) Sobre Supabase Storage como hosting

Se puede usar `Storage` para publicar archivos estaticos de prueba (URLs publicas),
pero no es la opcion mas robusta para una SPA Flutter con rutas y ciclo de despliegue.
Para pruebas operativas, mejor Nginx/Vercel/Netlify con fallback a `index.html`.
