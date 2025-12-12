# Configuración de Supabase - Solución al Error "requested path is invalid"

## 🔴 Problema

Al intentar hacer login con email y contraseña, aparece el error:
```
{"error":"requested path is invalid"}
```

Este error ocurre porque la tabla `users` en Supabase no tiene configuradas las **políticas de Row Level Security (RLS)** necesarias para permitir que los usuarios autenticados accedan a sus propios datos.

## ✅ Solución

Sigue estos pasos para configurar correctamente tu base de datos en Supabase:

### Paso 1: Acceder al SQL Editor

1. Abre tu navegador y ve a tu proyecto de Supabase:
   ```
   https://pqypiajsgunsurxpomol.supabase.co
   ```

2. En el menú lateral izquierdo, selecciona **"SQL Editor"**

### Paso 2: Ejecutar el Script de Configuración

1. En el SQL Editor, copia y pega **todo el contenido** del archivo `supabase_setup.sql` que se encuentra en la raíz de este proyecto

2. Haz clic en el botón **"Run"** (Ejecutar) en la esquina inferior derecha

3. Deberías ver un mensaje de éxito indicando que el script se ejecutó correctamente

### Paso 3: Verificar la Configuración

Para verificar que las políticas se crearon correctamente:

1. En el SQL Editor, ejecuta la siguiente consulta:
   ```sql
   SELECT tablename, policyname, permissive, roles, cmd 
   FROM pg_policies 
   WHERE tablename = 'users';
   ```

2. Deberías ver 3 políticas:
   - `Users can read their own data`
   - `Users can insert their own data`
   - `Users can update their own data`

### Paso 4: Probar el Login

1. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

2. Intenta hacer login con tus credenciales

3. El login ahora debería funcionar correctamente ✅

## 📝 ¿Qué hace el script?

El script `supabase_setup.sql` realiza las siguientes acciones:

1. **Crea la tabla `users`** si no existe, con las siguientes columnas:
   - `id` (UUID) - Vinculado a auth.users
   - `email` (TEXT)
   - `alias` (TEXT)
   - `display_name` (TEXT)
   - `profile_image_url` (TEXT)
   - `birth_date` (TIMESTAMP)
   - `created_at` (TIMESTAMP)
   - `updated_at` (TIMESTAMP)

2. **Habilita Row Level Security (RLS)** en la tabla

3. **Crea 3 políticas de seguridad**:
   - **SELECT**: Los usuarios pueden leer solo sus propios datos
   - **INSERT**: Los usuarios pueden crear solo su propio registro
   - **UPDATE**: Los usuarios pueden actualizar solo sus propios datos

4. **Crea índices** para mejorar el rendimiento

5. **Crea un trigger** para actualizar automáticamente el campo `updated_at`

## 🛡️ ¿Qué es Row Level Security (RLS)?

Row Level Security es una característica de PostgreSQL que permite controlar qué filas de una tabla puede ver o modificar cada usuario. En este caso:

- Cada usuario **solo puede ver y modificar su propia información** en la tabla `users`
- Nadie puede ver los datos de otros usuarios
- Esto protege la privacidad y seguridad de los datos

## ❓ Preguntas Frecuentes

### ¿Por qué necesito ejecutar este script?

Supabase requiere que configures explícitamente las políticas de RLS. Sin estas políticas, la base de datos bloquea todos los accesos por seguridad, causando el error "requested path is invalid".

### ¿Es seguro ejecutar este script?

Sí, el script solo crea las estructuras y políticas necesarias. No modifica ni elimina datos existentes.

### ¿Qué pasa si ya tengo datos en la tabla users?

El script usa `CREATE TABLE IF NOT EXISTS`, por lo que no afectará una tabla existente. Solo creará las políticas de seguridad.

### ¿Necesito ejecutar esto cada vez?

No, solo necesitas ejecutar el script **una vez** por proyecto de Supabase.

## 🆘 Soporte

Si después de seguir estos pasos sigues teniendo problemas, verifica:

1. Que estás usando la URL y API key correctas en `lib/config/supabase_config.dart`
2. Que tu usuario existe en el sistema de autenticación de Supabase (ve a Authentication > Users)
3. Los logs de la consola para más detalles del error

---

**Última actualización**: Diciembre 2025
