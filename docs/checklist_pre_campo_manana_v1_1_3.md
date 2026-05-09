# Checklist Pre-Campo (Mañana) v1.1.3

## Esta noche

1. Ejecutar reset:
   - `docs/supabase_reset_field_test_2days.sql`
2. Limitar oficiales de prueba:
   - `docs/supabase_scope_field_test_oficiales.sql`
3. Build web:
   - `flutter build web --release`
4. Deploy express:
   - `docs/deploy_express_mobile_test_v1_1_3.md`
5. Configurar `Site URL` y `Redirect URLs` en Supabase.

## Mañana (antes de turno)

1. Reactivar cron SLA:
```sql
update cron.job
set active = true
where jobname = 'sccp_sla_reportes_tick';
```

2. Iniciar sesión en app móvil con oficiales de prueba.
3. Verificar reportes automáticos (cada 6 min).
4. Correr smoke:
   - `docs/supabase_field_test_smoke_2days.sql`
5. Confirmar:
   - sesiones activas > 0
   - reportes recientes con hora actual
   - login_logs recientes
   - SLA sin ruido masivo fuera del scope de prueba
