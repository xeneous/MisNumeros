# 🔐 Credenciales de Google OAuth

## ⚠️ IMPORTANTE - SEGURIDAD

El **Client Secret** (`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`) **NUNCA** debe estar en el código de la aplicación móvil.

### ✅ Dónde va cada credencial:

#### En la App Flutter (supabase_auth_service.dart):
```dart
serverClientId: '977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com'
```
- ✅ **SÍ** incluir el Web Client ID
- ❌ **NO** incluir el Client Secret

#### En Supabase Dashboard:
```
Client ID: 977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com
Client Secret: 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
```
- ✅ Configurar ambos en: Authentication → Providers → Google

## 📝 Configuración Actual

### Android Client ID (para Google Sign-In nativo)
```
977281610510-na64f1un83v3mojjq08te8bei96sb9rd.apps.googleusercontent.com
```
**Uso:** Configuración de google-services.json

### Web Client ID (para Supabase)
```
Client ID: 977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com
Client Secret: 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
```
**Uso:**
- Client ID → En el código Flutter (`serverClientId`)
- Ambos → En Supabase Dashboard

## 🔒 Buenas Prácticas de Seguridad

### ✅ Hacer:
1. Guardar el Client Secret en un gestor de contraseñas
2. Configurar el Client Secret solo en Supabase Dashboard
3. Usar el Client ID en el código de la app
4. Agregar `*.env` a `.gitignore`
5. Rotar credenciales si se exponen

### ❌ NO Hacer:
1. ❌ Commitear el Client Secret al repositorio
2. ❌ Incluir el Client Secret en el código de la app
3. ❌ Compartir el Client Secret públicamente
4. ❌ Usar el mismo Client para desarrollo y producción

## 📋 Checklist de Configuración

- [x] Web Client ID creado en Google Cloud Console
- [x] Client ID actualizado en `supabase_auth_service.dart`
- [ ] Client ID y Secret configurados en Supabase Dashboard
- [ ] Redirect URI configurado: `https://[proyecto].supabase.co/auth/v1/callback`
- [ ] Google Provider habilitado en Supabase
- [ ] RLS configurado en tabla `users`
- [ ] Probado el flujo de autenticación

## 🚀 Próximos Pasos

### 1. Configurar en Supabase Dashboard

1. Ve a: https://supabase.com/dashboard/project/[TU_PROYECTO]
2. Navega a: **Authentication** → **Providers** → **Google**
3. Habilita Google
4. Ingresa:
   - **Client ID**: `977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com`
   - **Client Secret**: `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`
5. **Authorized redirect URLs**: Debería auto-completarse con:
   ```
   https://[tu-proyecto].supabase.co/auth/v1/callback
   ```
6. Guardar cambios

### 2. Configurar RLS en Supabase

Ve al SQL Editor y ejecuta:

```sql
-- Crear tabla users si no existe
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Política: Usuarios pueden ver sus propios datos
CREATE POLICY "Users can view own data"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Política: Usuarios pueden insertar sus propios datos
CREATE POLICY "Users can insert own data"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Política: Usuarios pueden actualizar sus propios datos
CREATE POLICY "Users can update own data"
ON public.users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
```

### 3. Verificar Redirect URI en Google Cloud

1. Ve a: https://console.cloud.google.com/apis/credentials
2. Click en tu Web Client ID
3. En **Authorized redirect URIs**, agrega **AMBOS**:
   ```
   https://[tu-proyecto].supabase.co/auth/v1/callback
   io.supabase.posicion://login-callback
   ```
   ⚠️ **IMPORTANTE**: Necesitas agregar ambos URIs:
   - El primero es para el flujo web de Supabase
   - El segundo es para el deep linking en la app móvil
4. Guardar

### 4. Probar el Flujo

1. Ejecuta la app
2. Toca "Iniciar sesión con Google"
3. Selecciona tu cuenta de Google
4. Verifica los logs en la consola
5. Verifica que el usuario se cree en Supabase

## 🐛 Troubleshooting

### Error: "Invalid client"
- Verifica que el Client ID sea el correcto (Web, no Android)
- Verifica que esté configurado en Supabase Dashboard

### Error: "redirect_uri_mismatch"
- Agrega `https://[proyecto].supabase.co/auth/v1/callback` en Google Cloud Console
- Verifica que no haya espacios o caracteres extra

### Error: "PERMISSION_DENIED" (42501)
- Ejecuta los scripts SQL para crear las políticas RLS
- Verifica que RLS esté habilitado en la tabla `users`

### Error: "No ID Token from Google"
- Verifica que estés usando `serverClientId` (Web Client ID)
- No uses el Android Client ID para este parámetro

## 📞 Soporte

Si tienes problemas:
1. Revisa los logs de la consola
2. Verifica cada paso del checklist
3. Consulta la guía completa en `GOOGLE_SIGNIN_SETUP.md`

## 🔄 Rotación de Credenciales

Si necesitas rotar las credenciales:
1. Genera nuevas credenciales en Google Cloud Console
2. Actualiza en Supabase Dashboard
3. Actualiza `serverClientId` en el código
4. Re-deploya la app

---

**Última actualización:** 2025-12-09
**Estado:** Configuración inicial completa, pendiente configuración en Supabase Dashboard
