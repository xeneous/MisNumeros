# 🔧 Pasos Exactos para Configurar Google en Supabase Dashboard

## ⚠️ El error persiste después de configurar skip_nonce_check

Si configuraste `skip_nonce_check: true` pero el error persiste, significa que Supabase no está reconociendo esta configuración o no está en el lugar correcto.

## 📍 Ubicación EXACTA de la configuración

### Opción 1: En el Dashboard (Interfaz Gráfica)

1. Ve a: https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/auth/providers

2. En la lista de providers, encuentra **Google** y haz clic en el ícono de lápiz ✏️ para editar

3. Deberías ver estos campos:
   ```
   ✅ Google enabled

   Client ID (for OAuth):
   977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com

   Client Secret (for OAuth):
   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

   Redirect URL:
   https://pqypiajsgunsurxpomol.supabase.co/auth/v1/callback
   ```

4. **CRÍTICO:** Busca una sección que diga **"Additional Configuration"**, **"Advanced"**, o **"Extra Options"**

5. Dentro de esa sección, debería haber:
   - Un campo de texto JSON
   - O un toggle/checkbox

6. Si es un campo JSON, debe contener:
   ```json
   {
     "skip_nonce_check": true
   }
   ```

7. Si es un checkbox, debe estar marcado: ☑️ **Skip nonce verification**

### Opción 2: Si NO encuentras esa opción en el Dashboard

Es probable que Supabase no exponga `skip_nonce_check` en la UI del Dashboard para tu versión del proyecto.

**En ese caso, necesitas actualizar la configuración vía SQL directamente.**

## 🛠️ Solución Alternativa: Actualizar vía SQL

Si `skip_nonce_check` no está disponible en la UI, puedes intentar actualizar la configuración directamente en la base de datos:

### Paso 1: Ve al SQL Editor

https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/sql/new

### Paso 2: Ejecuta este SQL

```sql
-- Ver la configuración actual de Google
SELECT * FROM auth.config;
```

### Paso 3: Busca en los resultados

Busca una fila que tenga la configuración de Google. Si no la encuentras, significa que la configuración no se puede modificar directamente vía SQL.

## 🔄 Solución DEFINITIVA: Usar método alternativo en el código

Si Supabase no permite configurar `skip_nonce_check`, entonces necesitamos cambiar el enfoque en el código.

**La solución es NO usar `signInWithIdToken`, sino usar el flujo OAuth estándar de Supabase.**

### ¿Cuál es la diferencia?

- **signInWithIdToken** (actual): Toma el token de Google y lo envía a Supabase → Requiere skip_nonce_check
- **signInWithOAuth** (alternativa): Abre el navegador de Google → No requiere configuración especial

### Ventajas del flujo OAuth estándar:

✅ No requiere configuración especial en Supabase
✅ Funciona de inmediato
✅ Es el método recomendado por Supabase
❌ Abre navegador externo (peor UX, pero funcional)

## 🎯 Decisión

¿Quieres que implemente el flujo OAuth estándar (abre navegador) que funciona sin configuración adicional?

Es la solución más rápida y confiable si Supabase no permite configurar `skip_nonce_check`.

## 📝 Nota Importante

El error "Unacceptable audience" es un problema conocido de Supabase con `signInWithIdToken` en móvil.

La documentación oficial de Supabase recomienda usar `signInWithOAuth` para aplicaciones móviles nativas, precisamente para evitar este tipo de problemas.

Fuente: https://supabase.com/docs/guides/auth/social-login/auth-google#native-mobile-login
