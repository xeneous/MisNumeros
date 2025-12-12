# Solución al Error: "Unacceptable audience in id_token"

## ❌ El Problema

Cuando usas `signInWithIdToken` con Google Sign-In en Supabase, obtienes este error:

```
AuthApiException(message: Unacceptable audience in id_token:
[977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com],
statusCode: 400, code: null)
```

**Causa:** Supabase valida que la audiencia (aud) del ID Token de Google coincida exactamente con lo que espera, pero Google genera el token con el Web Client ID como audiencia.

## ✅ Solución: Configurar "Skip nonce check" en Supabase

### Paso 1: Ve a Supabase Dashboard

1. Abre: https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/auth/providers
2. Haz clic en **Google** en la lista de providers

### Paso 2: Configurar Google Provider

Asegúrate de tener:

```
Client ID (for OAuth): 977281610510-ts0oe13aj54973cdthnr9nr2kul7qv98.apps.googleusercontent.com
Client Secret (for OAuth): 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
```

### Paso 3: CRÍTICO - Habilitar "Skip nonce check"

Busca en la configuración del Google Provider una opción que diga:

- ☑️ **"Skip nonce verification"**
- ☑️ **"Skip nonce check"**
- ☑️ **"Allow ID token authentication"**

O similar. Esta opción le dice a Supabase que acepte ID Tokens de Google sin validar estrictamente la audiencia.

**Si NO encuentras esta opción:**

Supabase puede que no exponga esta configuración en el Dashboard. En ese caso, necesitamos usar una alternativa.

## 🔄 Alternativa: Usar OAuth Flow con PKCE

Si la opción "Skip nonce check" no está disponible, usa el flujo OAuth estándar con PKCE (ya implementado en el código).

### Configuración necesaria:

#### 1. En Google Cloud Console

https://console.cloud.google.com/apis/credentials

En tu **Web Client ID**, agrega estos redirect URIs:

```
https://pqypiajsgunsurxpomol.supabase.co/auth/v1/callback
io.supabase.posicion://login-callback
```

#### 2. Verificar configuración de Supabase

En https://supabase.com/dashboard/project/pqypiajsgunsurxpomol/auth/providers:

- Google Provider debe estar **Enabled** ✅
- Client ID y Secret configurados correctamente

## 🧪 Probar la Solución

Después de configurar "Skip nonce check" (o los redirect URIs para OAuth):

1. Limpia y reconstruye la app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. Toca "Iniciar sesión con Google"

3. Deberías ver en los logs:
   ```
   Supabase: Starting native Google Sign-In...
   Supabase: Google user selected: [email]
   Supabase: Got ID token, authenticating with Supabase...
   Supabase: Authentication response received
   Supabase: User authenticated: [user_id]
   ```

## 📝 Notas Importantes

- El método actual (`signInWithIdToken` con `nonce: ''`) debería funcionar SI "Skip nonce check" está habilitado en Supabase
- Si no funciona, el código ya está preparado para usar el flujo OAuth estándar
- El flujo OAuth abre un navegador externo, pero es más confiable cuando "Skip nonce check" no está disponible

## 🔍 Debug: Ver qué está fallando

Si sigue fallando, verifica en los logs exactamente qué está pasando:

```dart
print('ID Token audience: ${googleAuth.idToken}');
```

Decodifica el JWT en https://jwt.io para ver qué audiencia tiene el token.

## 📞 Contacto Supabase Support

Si "Skip nonce check" no está visible en el Dashboard, contacta a Supabase Support:

https://supabase.com/dashboard/support

Pregunta: "¿Cómo puedo habilitar 'Skip nonce verification' para Google Sign-In con ID Tokens en móvil?"
