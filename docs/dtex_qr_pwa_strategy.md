# DTEX - Estrategia QR/PWA temporal para custodio

Objetivo: habilitar diligencias externas sin obligar a custodios eventuales a instalar una app Android permanente.

## Principio operativo

- SCCP queda intacto y DTEX funciona como modulo separado.
- El supervisor DTEX crea la mision y entrega un QR/OTP temporal al custodio.
- El custodio abre una PWA liviana desde el QR, valida OTP y solo ve la mision asignada.
- El acceso expira al cerrar/completar/cancelar la mision o al vencer el tiempo autorizado.

## Flujo propuesto

1. Supervisor DTEX crea mision con interno, custodio eventual, destino, hora y tiempo maximo.
2. Sistema genera `codigo_otp` de 6 digitos y un enlace temporal:
   - `/dtex/custodio?otp=123456`
3. Custodio escanea QR, valida OTP mediante RPC `dtex_validar_otp`.
4. PWA muestra acciones simples:
   - `REGISTRO REALIZADO`
   - `EN RUTA`
   - `EN DESTINO`
   - `RETORNO`
   - `EMERGENCIA`
5. PWA reporta GPS periodico a `dtex_tracking_gps` solo durante mision activa.
6. Supervisor cierra mision desde WebApp con conducta final:
   - `SIN_INCIDENCIAS`
   - `CON_OBSERVACIONES`
   - `CON_INCIDENCIAS_GRAVES`

## Ventajas

- No mezcla custodios eventuales con `oficiales`.
- No mezcla internos eventuales con `reos` fijos del SCCP.
- Reduce instalacion y soporte en campo.
- Permite auditar cada diligencia por mision, OTP, tracking y alertas.

## Siguiente implementacion recomendada

- Crear ruta web aislada para custodio DTEX.
- No montar dashboard SCCP en esa ruta.
- Reutilizar solo `DtexRepository` y modelos DTEX.
- Agregar generacion visual de QR en el dialogo DTEX despues de crear mision.

