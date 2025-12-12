# Configuración de Google Sign-In con Supabase

## 🎯 Objetivo

Configurar Google Sign-In para que funcione con Supabase usando el flujo de ID Token (método recomendado para aplicaciones móviles).

## 📋 Requisitos Previos

1. Proyecto de Supabase creado
2. Cuenta de Google Cloud Platform
3. App Android configurada

## 🔧 Pasos de Configuración

### 1. Configurar Google Cloud Console

#### A. Crear/Configurar Proyecto

1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto nuevo o selecciona uno existente
3. Habilita la **Google Sign-In API**

#### B. Crear Credenciales OAuth 2.0

Necesitas **DOS** tipos de credenciales:

##### Credencial 1: Android (Ya tienes)
```
Tipo: Android
Client ID: 977281610510-na64f1un83v3mojjq08te8bei96sb9rd.apps.googleusercontent.com
Package name: com.xeneous.misnumeros
SHA-1: [Tu SHA-1 de debug/release]
```

##### Credencial 2: Web (NUEVA - para Supabase)
```
Tipo: Aplicación web
Nombre: Posicion Web Client (for Supabase)
JavaScript origins: https://[TU_PROYECTO].supabase.co
Redirect URIs: https://[TU_PROYECTO].supabase.co/auth/v1/callback
```

**⚠️ IMPORTANTE:** Necesitas el **Web Client ID** para el parámetro `serverClientId` en Flutter.

### 2. Configurar Supabase

#### A. Habilitar Google Provider

1. Ve a tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard)
2. Ve a **Authentication** → **Providers**
3. Habilita **Google**
4. Ingresa las credenciales:
   - **Client ID (for OAuth)**: El Client ID de la credencial Web
   - **Client Secret (for OAuth)**: El Client Secret de la credencial Web
5. Guarda los cambios

#### B. Configurar Row Level Security (RLS)

Ejecuta estos comandos en el SQL Editor de Supabase:

```sql
-- Habilitar RLS en la tabla users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Política: Usuarios pueden ver solo sus propios datos
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

-- Crear tabla users si no existe
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### 3. Actualizar Código Flutter

#### A. Actualizar `supabase_auth_service.dart`

En la línea 93, reemplaza `YOUR_WEB_CLIENT_ID` con tu Web Client ID real:

```dart
final GoogleSignIn googleSignIn = GoogleSignIn(
  // Reemplaza con tu Web Client ID real
  serverClientId: '977281610510-XXXXXXXXXX.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);
```

#### B. Verificar configuración Android

Asegúrate de que `android/app/build.gradle.kts` tenga:

```kotlin
android {
    defaultConfig {
        // ... otras configuraciones
        manifestPlaceholders["appAuthRedirectScheme"] = "com.xeneous.misnumeros"
    }
}
```

### 4. Obtener el Web Client ID

#### Opción A: Desde Google Cloud Console

1. Ve a [API & Services → Credentials](https://console.cloud.google.com/apis/credentials)
2. Encuentra la credencial de tipo "Web application"
3. Copia el **Client ID**
4. Debería verse así: `977281610510-xxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com`

#### Opción B: Crear nuevo Web Client ID

Si no tienes uno, créalo:

1. Click en "Create Credentials" → "OAuth 2.0 Client ID"
2. Application type: **Web application**
3. Name: `Posicion Web Client`
4. Authorized JavaScript origins:
   - `https://[TU_PROYECTO].supabase.co`
5. Authorized redirect URIs:
   - `https://[TU_PROYECTO].supabase.co/auth/v1/callback`
6. Click "Create"
7. **Copia el Client ID y Client Secret**

### 5. Configurar Variables de Entorno (Opcional pero Recomendado)

Crea un archivo `.env` en la raíz del proyecto:

```env
SUPABASE_URL=https://[TU_PROYECTO].supabase.co
SUPABASE_ANON_KEY=tu_anon_key_aqui
GOOGLE_WEB_CLIENT_ID=977281610510-xxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
```

Luego usa `flutter_dotenv` para cargar estas variables.

## 🧪 Probar el Flujo

### Flujo Esperado

1. Usuario toca "Iniciar sesión con Google"
2. Se abre el selector de cuenta de Google
3. Usuario selecciona su cuenta
4. Google devuelve el ID Token
5. Flutter envía el ID Token a Supabase
6. Supabase valida el token con Google
7. Supabase crea la sesión
8. Se crea/obtiene el perfil del usuario en `public.users`
9. Usuario autenticado exitosamente

### Logs Esperados

```
Supabase: Starting Google Sign-In...
Supabase: Google Sign-In successful, getting authentication...
Supabase: ID Token obtained, signing in to Supabase...
Supabase: Sign-in response received
Supabase: User authenticated: [USER_ID]
Supabase: Creating new user profile...
```

## 🐛 Troubleshooting

### Error: "PERMISSION_DENIED" o "42501"

**Causa:** Row Level Security no configurado correctamente

**Solución:**
1. Verifica que RLS esté habilitado
2. Verifica que las políticas existan
3. Ejecuta los comandos SQL de la sección 2.B

### Error: "No ID Token from Google"

**Causa:** `serverClientId` no configurado o incorrecto

**Solución:**
1. Verifica que usas el **Web Client ID**, no el Android Client ID
2. Asegúrate de que el Web Client ID esté correctamente copiado
3. No uses el Android Client ID (termina en `.apps.googleusercontent.com` pero es diferente)

### Error: "Invalid login credentials"

**Causa:** Google provider no habilitado en Supabase

**Solución:**
1. Ve a Supabase Dashboard → Authentication → Providers
2. Habilita Google
3. Ingresa Client ID y Client Secret del Web Client

### Error: "redirect_uri_mismatch"

**Causa:** Redirect URI no configurado en Google Cloud

**Solución:**
1. Ve a Google Cloud Console → Credentials
2. Edita el Web Client
3. Agrega: `https://[TU_PROYECTO].supabase.co/auth/v1/callback`

### El usuario se autentica pero no se crea en `public.users`

**Causa:** Política RLS impide la inserción

**Solución:**
```sql
-- Verifica que exista esta política
CREATE POLICY "Users can insert own data"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);
```

## 📱 Configuración Específica de Android

### SHA-1 para Google Sign-In

Para desarrollo (debug):
```bash
cd android
./gradlew signingReport
```

Copia el SHA-1 de la variante `debug` y agrégalo en Google Cloud Console.

Para producción (release):
1. Genera tu keystore si no lo tienes
2. Obtén el SHA-1 del keystore de release
3. Agrégalo también en Google Cloud Console

## 🔐 Seguridad

### Mejores Prácticas

1. **NUNCA** commitees Client Secrets al repositorio
2. Usa variables de entorno para credenciales
3. Diferentes Client IDs para debug/release
4. Configura RLS en todas las tablas sensibles
5. Valida siempre el `auth.uid()` en las políticas

### Ejemplo de `.gitignore`

```gitignore
# Secrets
.env
.env.local
google-services.json
```

## 🚀 Deployment

### Antes de publicar en Play Store

1. Genera keystore de producción
2. Obtén SHA-1 de producción
3. Crea OAuth Client ID para producción en Google Cloud
4. Actualiza Supabase con credenciales de producción
5. Prueba el flujo completo con build de release

## 📚 Referencias

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Supabase Google OAuth](https://supabase.com/docs/guides/auth/social-login/auth-google)

## ✅ Checklist de Configuración

- [ ] Proyecto en Google Cloud Console creado
- [ ] Google Sign-In API habilitada
- [ ] Android OAuth Client ID creado con SHA-1
- [ ] Web OAuth Client ID creado
- [ ] Google provider habilitado en Supabase
- [ ] Client ID y Secret configurados en Supabase
- [ ] Redirect URI configurado (`https://[proyecto].supabase.co/auth/v1/callback`)
- [ ] RLS habilitado en tabla `users`
- [ ] Políticas RLS creadas
- [ ] `serverClientId` actualizado en el código
- [ ] Flujo de autenticación probado

## 🎉 Resultado Final

Después de completar todos los pasos, tendrás:

✅ Autenticación con Google funcionando
✅ Usuarios almacenados en Supabase
✅ Sesiones persistentes
✅ Seguridad con RLS
✅ No más errores de permisos
