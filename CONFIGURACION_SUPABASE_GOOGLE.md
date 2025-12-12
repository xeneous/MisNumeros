# 🔧 Configuración de Google Sign-In en Supabase Dashboard

## ⚠️ Error Actual

```
AuthApiException(message: Unacceptable audience in id_token:
[977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com],
statusCode: 400, code: null)
```

Este error ocurre porque Supabase está rechazando el ID Token de Google debido a una validación estricta de la audiencia.

## ✅ Solución: Configurar Google Provider en Supabase

### Paso 1: Acceder a la configuración

Ve a: https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/auth/providers

### Paso 2: Configurar Google Provider

1. **Habilita Google** si aún no está habilitado
2. Ingresa las credenciales:
   ```
   Client ID (for OAuth): 977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com
   Client Secret (for OAuth): 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
   ```

### Paso 3: ⚠️ CRÍTICO - Agregar configuración adicional

En la misma página del Google Provider, busca una sección que diga:

- **"Additional Configuration"** o
- **"Advanced Settings"** o
- **"Extra Configuration"**

Dentro de esa sección, necesitas agregar un campo JSON con esta configuración:

```json
{
  "skip_nonce_check": true
}
```

O alternativamente, puede haber un checkbox o toggle que diga:

- ☑️ **"Skip nonce verification"**
- ☑️ **"Allow mobile ID tokens"**
- ☑️ **"Skip audience validation"**

**Si no encuentras ninguna de estas opciones**, entonces Supabase no expone esta configuración en el Dashboard y necesitarás usar la **Solución Alternativa** (ver abajo).

### Paso 4: Guardar cambios

Click en **"Save"** o **"Update"**

## 🔄 Solución Alternativa: Usar Supabase CLI

Si no puedes configurar "skip_nonce_check" desde el Dashboard, puedes hacerlo con Supabase CLI:

### 1. Instalar Supabase CLI

```bash
npm install -g supabase
```

### 2. Login a Supabase

```bash
supabase login
```

### 3. Link al proyecto

```bash
supabase link --project-ref pqypiajsgunsurxpomol
```

### 4. Actualizar configuración de Google

Crea un archivo `supabase/config.toml` (si no existe):

```toml
[auth.external.google]
enabled = true
client_id = "977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com"
secret = "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"
redirect_uri = "https://pqypiajsgunsurxpomol.supabase.co/auth/v1/callback"
skip_nonce_check = true
```

### 5. Aplicar configuración

```bash
supabase db push
```

## 🧪 Otra Alternativa: Contactar Soporte de Supabase

Si ninguna de las opciones anteriores funciona, contacta a Supabase Support:

1. Ve a: https://supabase.com/dashboard/support/new
2. Selecciona tu proyecto: `pqypiajsgunsurxpomol`
3. Asunto: "Enable skip_nonce_check for Google Sign-In"
4. Mensaje:
   ```
   Hi, I'm getting an "Unacceptable audience in id_token" error when trying to use
   Google Sign-In with native mobile app.

   I'm using signInWithIdToken with Google OAuth and the ID token has the correct
   Web Client ID as audience: 977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com

   Can you please enable "skip_nonce_check" or "skip audience validation" for
   Google provider in my project?

   Project: pqypiajsgunsurxpomol

   Thank you!
   ```

## 📝 Verificar la configuración actual

Puedes verificar la configuración actual ejecutando este SQL en el SQL Editor:

```sql
-- Ver configuración de Google Provider
SELECT * FROM auth.config WHERE key LIKE '%google%';
```

## 🎯 Resultado esperado

Una vez configurado correctamente, deberías ver en los logs:

```
Supabase: Starting native Google Sign-In...
Supabase: Google user selected: [tu-email]
Supabase: Got tokens, authenticating with Supabase...
Supabase: Authentication response received
Supabase: User authenticated: [uuid]
Supabase: User found/created: [uuid]
```

## 📞 Necesitas ayuda?

Si después de intentar todas estas opciones sigue sin funcionar, puede ser que Supabase
haya cambiado cómo funciona esta configuración en versiones recientes.

En ese caso, la mejor opción es:
1. Verificar la documentación oficial más reciente: https://supabase.com/docs/guides/auth/social-login/auth-google
2. Contactar al soporte de Supabase
3. O considerar usar el flujo OAuth estándar (abre navegador) que está implementado como fallback
